"""
Ping na bandeja do Windows (sem janela de console).

Liga a ponte com o celular, o resumo do dia e o painel local (conta e QR do app), manda o log pra ping.log e
mostra um icone na bandeja com o status.
"""
import ctypes
import json
import os
import subprocess
import sys
import threading
import time
import traceback
from pathlib import Path

BASE = Path(__file__).resolve().parent
LOG = BASE / "ping.log"
TITULO = "Ping"  # titulo da janela do painel (o Edge em modo --app usa o <title> da pagina)


# ---------------- instancia unica ----------------

def _janelas_painel():
    """Janelas do painel abertas, minimizadas tambem."""
    u32 = ctypes.windll.user32
    achadas = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    def _olhar(hwnd, _):
        titulo = ctypes.create_unicode_buffer(64)
        classe = ctypes.create_unicode_buffer(64)
        u32.GetWindowTextW(hwnd, titulo, 64)
        u32.GetClassNameW(hwnd, classe, 64)
        if titulo.value == TITULO and classe.value == "Chrome_WidgetWin_1" and u32.IsWindowVisible(hwnd):
            achadas.append(hwnd)
        return True

    try:
        u32.EnumWindows(_olhar, 0)
    except Exception:
        pass
    return achadas


def _mostrar_painel_aberto():
    """Ja rodando (abriu de novo pela pesquisa do Windows ou pelo atalho): traz o painel pra frente; se ele
    estiver fechado, abre no endereco da copia que esta rodando. Devolve False se nao conseguiu."""
    u32 = ctypes.windll.user32
    try:
        achadas = _janelas_painel()
        if achadas:
            u32.ShowWindow(achadas[0], 9)  # SW_RESTORE: volta se estava minimizada
            u32.SetForegroundWindow(achadas[0])
            return True
        porta, token = _endereco()
        if not porta or not _servidor_responde():  # so abre a URL com o token se quem responde e o Ping
            return False
        import painel
        painel.abrir_url(f"http://127.0.0.1:{porta}/?t={token}")
        return True
    except Exception:
        return False


def _endereco():
    """Porta e token do painel da copia que esta rodando. ativo.txt tem a porta de verdade
    (porta.txt e a preferida, mas se estava ocupada a copia aberta usou outra)."""
    cache = BASE / "cache"
    try:
        token = (cache / "token.txt").read_text(encoding="utf-8").strip()
    except OSError:
        return None, None
    for nome in ("ativo.txt", "porta.txt"):
        try:
            porta = (cache / nome).read_text(encoding="utf-8").strip()
        except OSError:
            continue
        if porta.isdigit() and token:
            return porta, token
    return None, None


def _servidor_responde():
    """Segunda trava: o painel de uma copia aberta responde no endereco salvo. Prova que conhece o token sem a
    gente mandar ele (outro usuario do PC podia ocupar a porta antes e pegar o token)."""
    porta, token = _endereco()
    if not porta:
        return False
    import hashlib
    import hmac
    import secrets
    import urllib.request
    desafio = secrets.token_hex(16)
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{porta}/api/ola?d={desafio}", timeout=1.5) as r:
            prova = json.loads(r.read() or b"{}").get("prova")
    except Exception:
        return False
    certa = hmac.new(token.encode("utf-8"), desafio.encode("utf-8"), hashlib.sha256).hexdigest()
    return isinstance(prova, str) and hmac.compare_digest(prova.encode("utf-8"), certa.encode("utf-8"))


_k32 = ctypes.WinDLL("kernel32", use_last_error=True)
_k32.CreateMutexW.restype = ctypes.c_void_p
_k32.CloseHandle.argtypes = (ctypes.c_void_p,)
_mutexes = []


def _ja_rodando():
    # use_last_error: o GetLastError chamado solto pelo ctypes pode vir zerado (o Python chama outras
    # funcoes do Windows no meio), e ai a segunda copia abria achando que era a primeira
    h = _k32.CreateMutexW(None, False, "PingBandeja")
    erro = ctypes.get_last_error()
    if h:
        _mutexes.append(h)
    if erro == 183:  # ERROR_ALREADY_EXISTS
        return True
    if not h and erro == 5:  # ERROR_ACCESS_DENIED: a aberta roda como administrador
        return True
    # reinicio: a copia velha soltou a trava e esta saindo, o servidor dela ainda pode responder
    return "--reinicio" not in sys.argv and _servidor_responde()


if _ja_rodando():
    if not _mostrar_painel_aberto():
        ctypes.windll.user32.MessageBoxW(None, "O Ping já está rodando na bandeja.", "Ping", 0x40)
    sys.exit(0)

# ---------------- log em arquivo ----------------
LOG_MAX = 1_000_000
try:  # no reinicio a copia velha ainda pode segurar o arquivo: sem girar, mas abre
    if LOG.exists() and LOG.stat().st_size > LOG_MAX:
        LOG.replace(LOG.with_suffix(".log.old"))
except OSError:
    pass


# ---------------- nome nas notificacoes ----------------
APP_ID = "Ping.Bandeja"


def _registrar_app_id():
    """Sem isso o aviso do Windows sai com "Python" no cabecalho (o nome do pythonw.exe)."""
    if sys.platform != "win32":
        return
    try:
        import winreg
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, rf"Software\Classes\AppUserModelId\{APP_ID}") as k:
            winreg.SetValueEx(k, "DisplayName", 0, winreg.REG_SZ, "Ping")
            ico = BASE / "ping.ico"
            if ico.exists():
                winreg.SetValueEx(k, "IconUri", 0, winreg.REG_SZ, str(ico))
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(APP_ID)
    except Exception:
        pass


_registrar_app_id()

from PIL import Image, ImageDraw  # noqa: E402
import pystray  # noqa: E402

CORES = {
    "esperando": (120, 120, 130),   # cinza: client fechado
    "conectado": (200, 170, 110),   # dourado: pronto
    "erro": (200, 60, 60),          # vermelho: deu ruim
}


def desenhar(cor, n):
    """Sinal de ping: losango no centro de dois aneis. Desenha 8x maior e reduz (o ImageDraw nao suaviza borda)."""
    N = n * 8
    k = N / 64

    def P(pts):
        return [(x * k, y * k) for x, y in pts]

    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse(P([(1.5, 1.5), (62.5, 62.5)]), fill=cor)
    d.ellipse(P([(6.5, 6.5), (57.5, 57.5)]), fill=(12, 20, 32))
    d.ellipse(P([(14, 14), (50, 50)]), outline=cor, width=round(3 * k))
    d.polygon(P([(32, 20), (44, 32), (32, 44), (20, 32)]), fill=cor)
    return img.resize((n, n), Image.LANCZOS)


TAMANHOS = (16, 20, 24, 32, 40, 48)


def icone(cor):
    """Imagem de 32px com os desenhos de cada tamanho pendurados (vao todos pro .ico)."""
    img = desenhar(cor, 32)
    img.tamanhos = [desenhar(cor, n) for n in TAMANHOS]
    return img


class Icone(pystray.Icon):
    """O pystray carrega o .ico em 32px e o Windows encolhe pra 16 (fica borrado). Aqui o .ico leva um desenho
    pra cada tamanho e carrega direto no tamanho da bandeja."""

    def _assert_icon_handle(self):
        if self._icon_handle:
            return
        imgs = getattr(self.icon, "tamanhos", None)
        if not imgs:
            return super()._assert_icon_handle()
        try:
            from pystray._util import serialized_image, win32
            lado = ctypes.windll.user32.GetSystemMetrics(49)  # SM_CXSMICON
            with serialized_image(imgs[-1], "ICO") as caminho:
                imgs[-1].save(caminho, format="ICO", sizes=[i.size for i in imgs], append_images=imgs[:-1])
                self._icon_handle = win32.LoadImage(None, caminho, win32.IMAGE_ICON, lado, lado,
                                                    win32.LR_LOADFROMFILE)
        except Exception:
            super()._assert_icon_handle()


ICONES = {k: icone(v) for k, v in CORES.items()}
icon = (Icone if sys.platform == "win32" else pystray.Icon)("Ping", ICONES["esperando"], "Ping: iniciando")
_status_lock = threading.Lock()


def status(estado, texto):
    # varias threads escrevem no log ao mesmo tempo: trocar o icone junto da "identificador invalido"
    with _status_lock:
        try:
            if icon.icon is not ICONES[estado]:
                icon.icon = ICONES[estado]
            icon.title = ("Ping: " + texto)[:120]
        except OSError:
            pass


class LogBandeja:
    """Recebe os print() do programa: grava no arquivo."""

    def __init__(self):
        self.f = open(LOG, "a", encoding="utf-8", buffering=1)
        self.trava = threading.RLock()  # varias threads logam: sem isso as linhas se misturam

    def write(self, s):
        with self.trava:
            self.f.write(s)
            if s.endswith("\n"):
                self._girar()
        return len(s)

    def _girar(self):
        """PC ligado dias seguidos: gira o log no meio da execucao, nao so ao abrir."""
        try:
            if self.f.tell() < LOG_MAX:
                return
            self.f.close()
            LOG.replace(LOG.with_suffix(".log.old"))
        except OSError:
            pass
        finally:
            if self.f.closed:
                self.f = open(LOG, "a", encoding="utf-8", buffering=1)

    def flush(self):
        self.f.flush()


sys.stdout = sys.stderr = LogBandeja()


def _erro(onde):
    print(time.strftime("%H:%M:%S"), f"ERRO {onde}:\n" + traceback.format_exc(), flush=True)


def vigiar_client():
    """So o icone da bandeja: dourado com o client aberto, cinza fechado."""
    import lcu
    while True:
        try:
            fase = lcu.get("/lol-gameflow/v1/gameflow-phase")
            if fase is None:
                status("esperando", "esperando o LoL abrir")
            else:
                status("conectado", "conectado ao LoL")
        except Exception:
            pass
        time.sleep(3)


def abrir_painel(_icon=None, _item=None):
    try:
        import painel
        painel.abrir()
    except Exception:
        _erro("ao abrir o painel")
        status("erro", "erro ao abrir o painel, veja o log")


def ver_log(_icon, _item):
    os.startfile(str(LOG))


def _fechar():
    """Tira o icone da bandeja antes de sair: com os._exit direto ele ficava la (parecia ter dois abertos)."""
    try:
        icon.visible = False
    except Exception:
        pass
    try:
        icon.stop()
    except Exception:
        pass
    os._exit(0)


def reiniciar(_icon, _item, *, sozinho=False):  # so por nome: o pystray recusa acao com mais de 2 argumentos
    """sozinho (atualizacao): a versao nova nao abre janela nenhuma; o painel aberto se recarrega sozinho."""
    print(time.strftime("%H:%M:%S"), "Reiniciando", flush=True)
    for m in _mutexes:  # solta a trava de instancia unica antes de subir a nova
        _k32.CloseHandle(m)
    args = [sys.executable, str(BASE / "ping.pyw"), "--reinicio"]
    try:
        import painel
        if not sozinho and painel.painel_aberto():
            args.append("--painel")  # a versao nova garante o painel aberto
    except Exception:
        pass
    try:
        subprocess.Popen(args, cwd=str(BASE))
    finally:
        _fechar()  # sem trava, esta copia nunca pode continuar rodando junto da nova


def sair(_icon, _item):
    print(time.strftime("%H:%M:%S"), "Desligado pela bandeja", flush=True)
    _fechar()


icon.menu = pystray.Menu(
    pystray.MenuItem("Abrir o Ping", abrir_painel, default=True),
    pystray.MenuItem("Ver log", ver_log),
    pystray.Menu.SEPARATOR,
    pystray.MenuItem("Reiniciar", reiniciar),
    pystray.MenuItem("Sair", sair),
)


def _thread(alvo, onde):
    def rodar():
        try:
            alvo()
        except Exception:
            _erro(onde)
    threading.Thread(target=rodar, daemon=True).start()


def _iniciar_painel():
    import painel
    painel.ao_reiniciar = lambda: reiniciar(None, None)
    painel.ao_sair = _fechar
    painel.iniciar()
    primeira = not (BASE / "cache" / "conta.json").exists()
    if "--painel" in sys.argv:
        # o painel que estava aberto se recarrega sozinho; se nao voltar em 8s e nao tiver janela dele, abre
        time.sleep(8)
        if not painel.painel_aberto() and not _janelas_painel():
            painel.abrir()
    elif primeira and "--reinicio" not in sys.argv:
        painel.abrir()  # primeira vez: abre pra entrar na conta


def _iniciar_ponte():
    import ponte
    ponte.iniciar()


def _iniciar_hoje():
    import hoje
    import lcu
    hoje.rodar(notificar=lambda titulo, texto: icon.notify(texto, titulo)
               if lcu.config().get("resumo_dia", True) else None)


def _iniciar_com_windows():
    import inicio_windows
    import lcu
    inicio_windows.vigiar(lcu.config, log=lcu.log)


def _iniciar_atualizacao():
    """Atualiza sozinho: ao abrir e a cada 10 min, so com o LoL parado (atualizar.sozinho)."""
    import atualizar
    import lcu
    import ponte
    atualizar.sozinho(
        fase=lambda: lcu.get("/lol-gameflow/v1/gameflow-phase"),
        reiniciar=lambda: reiniciar(None, None, sozinho=True),
        ligado=lambda: lcu.config().get("atualizar_sozinho", True),
        livre=lambda: not ponte.abrindo_lol(),
        log=lcu.log)


_thread(vigiar_client, "no icone")
_thread(_iniciar_painel, "no painel")
_thread(_iniciar_ponte, "na ponte com o celular")
_thread(_iniciar_hoje, "no resumo do dia")
_thread(_iniciar_com_windows, "no abrir com o Windows")
_thread(_iniciar_atualizacao, "na atualizacao")
print(time.strftime("%H:%M:%S"), "Ping ligado", flush=True)
icon.run()
