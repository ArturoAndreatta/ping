"""
Servidor local do painel do Ping (uma pagina so: conta, QR do app, status do LoL, resumo do dia e opcoes).

- So escuta em 127.0.0.1 e toda chamada exige um token (outro site aberto no navegador nao consegue mexer).
- Porta e token ficam em cache/ pra janela aberta sobreviver a reinicio.
"""
import hashlib
import hmac
import json
import os
import re
import secrets
import shutil
import subprocess
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import lcu

BASE = Path(__file__).resolve().parent
UI = BASE / "ui" / "index.html"
CACHE = lcu.CACHE
BOOT = secrets.token_hex(6)  # muda a cada inicio: o painel aberto usa pra saber que reiniciou
_ultimo_ping = 0.0
_srv = None
ao_reiniciar = None  # a bandeja registra
ao_sair = None


def _persistente(nome, gerar):
    """Token e porta ficam salvos pra o painel aberto continuar valendo depois de reiniciar."""
    arq = CACHE / nome
    try:
        v = arq.read_text(encoding="utf-8").strip()
        if v:
            return v
    except OSError:
        pass
    v = gerar()
    try:
        CACHE.mkdir(exist_ok=True)
        arq.write_text(v, encoding="utf-8")
    except OSError:
        pass
    return v


TOKEN = _persistente("token.txt", lambda: secrets.token_urlsafe(24))


def _token_ok(t):
    """Compara em tempo constante (bytes: str com acento faria o compare_digest dar erro)."""
    return hmac.compare_digest((t or "").encode("utf-8"), TOKEN.encode("utf-8"))


def atividade():
    global _ultimo_ping
    _ultimo_ping = time.time()
    fase = lcu.get("/lol-gameflow/v1/gameflow-phase")
    import ponte
    return {"conectado": fase is not None, "fase": fase, "boot": BOOT, "erro": ponte._vivo.get("erro")}


def painel_aberto():
    return time.time() - _ultimo_ping < 10


def opcoes():
    cfg = lcu.config()
    import atualizar
    return {"opcoes": {k: cfg.get(k, True) is not False for k in lcu.OPCOES}, "versao": atualizar.versao_local()}


def conta():
    import ponte
    return {"conta": ponte._conta_painel(), "qr": ponte.qr_app()}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    timeout = 60  # conexao parada fecha sozinha
    disable_nagle_algorithm = True  # cabecalho e corpo saem em escritas separadas: sem isso cada resposta espera 40ms

    def log_message(self, *a):  # nao polui o ping.log
        pass

    def _ok_origem(self):
        host = self.headers.get("Host", "")
        porta = self.server.server_address[1]
        return host in (f"127.0.0.1:{porta}", f"localhost:{porta}")

    def _token(self, q):
        return _token_ok(self.headers.get("X-Token")) or _token_ok(q.get("t", [""])[0])

    def _enviar(self, code, corpo, tipo="application/json; charset=utf-8", cache=False):
        if isinstance(corpo, (dict, list)):
            corpo = json.dumps(corpo, ensure_ascii=False).encode("utf-8")
        elif isinstance(corpo, str):
            corpo = corpo.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(corpo)))
        self.send_header("Cache-Control", "max-age=86400" if cache else "no-store")
        self.end_headers()
        self.wfile.write(corpo)

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        d = q.get("d", [""])[0]
        if u.path == "/api/ola" and self._ok_origem() and re.fullmatch(r"[0-9a-f]{32}", d):
            # outra copia abrindo pergunta se ja tem Ping rodando: prova que sabe o token sem mostrar ele
            prova = hmac.new(TOKEN.encode("utf-8"), d.encode("utf-8"), hashlib.sha256).hexdigest()
            return self._enviar(200, {"ping": True, "prova": prova})
        if not self._ok_origem() or not self._token(q):
            return self._enviar(403, {"erro": "proibido"})
        try:
            if u.path == "/":
                html = UI.read_text(encoding="utf-8").replace("__TOKEN__", TOKEN)
                return self._enviar(200, html, "text/html; charset=utf-8")
            if u.path == "/api/atividade":
                return self._enviar(200, atividade())
            if u.path == "/api/conta":
                return self._enviar(200, conta())
            if u.path == "/api/opcoes":
                return self._enviar(200, opcoes())
            if u.path == "/api/hoje":
                import hoje
                return self._enviar(200, hoje.painel())
            if u.path == "/logo.ico":
                return self._enviar(200, (BASE / "ping.ico").read_bytes(), "image/x-icon", cache=True)
            return self._enviar(404, {"erro": "nao encontrado"})
        except Exception as e:
            return self._enviar(500, {"erro": str(e)})

    def do_POST(self):
        u = urlparse(self.path)
        fechar = self.close_connection
        self.close_connection = True  # corpo ainda nao lido: se der erro antes, nao reaproveita a conexao
        if not self._ok_origem() or not _token_ok(self.headers.get("X-Token")):
            return self._enviar(403, {"erro": "proibido"})
        try:
            n = int(self.headers.get("Content-Length") or 0)
            if n < 0 or n > 100_000:
                return self._enviar(413, {"erro": "grande demais"})
            corpo = json.loads(self.rfile.read(n) or b"{}")
            self.close_connection = fechar
            if u.path in ("/api/conta", "/api/conta/sair"):
                import ponte
                try:
                    if u.path == "/api/conta":
                        ponte.entrar_conta(corpo.get("email"), corpo.get("senha"), corpo.get("criar") is True)
                    else:
                        ponte.sair_conta()
                    return self._enviar(200, conta())
                except ValueError as e:
                    return self._enviar(400, {"erro": str(e)})
                except PermissionError as e:
                    return self._enviar(401, {"erro": str(e)})
                except ponte.requests.RequestException:
                    return self._enviar(502, {"erro": "Sem conexão com a conta. Tente de novo."})
            if u.path == "/api/opcoes":
                mudou = {k: corpo[k] is True for k in lcu.OPCOES if k in corpo}
                lcu.salvar_config(mudou)
                return self._enviar(200, opcoes())
            if u.path == "/api/reiniciar":
                if not ao_reiniciar:
                    return self._enviar(501, {"erro": "so da pra reiniciar rodando pela bandeja"})
                self._enviar(200, {"ok": True})
                threading.Timer(0.3, ao_reiniciar).start()  # responde antes de derrubar o processo
                return
            return self._enviar(404, {"erro": "nao encontrado"})
        except ValueError as e:
            return self._enviar(400, {"erro": str(e)})
        except Exception as e:
            return self._enviar(500, {"erro": str(e)})


class _Servidor(ThreadingHTTPServer):
    # Linux precisa de reuse pra religar logo apos fechar; no Windows reuse deixaria dois programas na mesma porta
    allow_reuse_address = os.name != "nt"
    daemon_threads = True


def iniciar():
    global _srv
    if _srv is None:
        porta = 0
        try:
            porta = int(_persistente("porta.txt", lambda: "0"))
        except ValueError:
            pass
        # a porta e o endereco do painel: mudar faz o navegador esquecer o tema
        # ao reiniciar, a copia velha pode ainda estar soltando a porta: espera um pouco antes de desistir
        fim = time.time() + 6
        while porta:
            try:
                _srv = _Servidor(("127.0.0.1", porta), Handler)
                break
            except OSError:
                if time.time() > fim:
                    break
                time.sleep(0.3)
        if _srv is None:
            # porta ocupada (outro programa): usa uma qualquer so desta vez, sem gravar
            _srv = _Servidor(("127.0.0.1", 0), Handler)
            if not porta:
                try:
                    (CACHE / "porta.txt").write_text(str(_srv.server_address[1]), encoding="utf-8")
                except OSError:
                    pass
        try:
            # porta de verdade desta vez: quem abrir o Ping de novo acha o painel aqui
            CACHE.mkdir(exist_ok=True)
            (CACHE / "ativo.txt").write_text(str(_srv.server_address[1]), encoding="utf-8")
        except OSError:
            pass
        threading.Thread(target=_srv.serve_forever, daemon=True).start()
    return url()


def url():
    return f"http://127.0.0.1:{_srv.server_address[1]}/?t={TOKEN}"


def _edge():
    achado = shutil.which("msedge")
    if achado:
        return achado
    for base in (os.environ.get("ProgramFiles(x86)"), os.environ.get("ProgramFiles"),
                 os.environ.get("LOCALAPPDATA")):
        if base:
            p = Path(base) / "Microsoft" / "Edge" / "Application" / "msedge.exe"
            if p.exists():
                return str(p)
    return None


def abrir_url(u):
    edge = _edge()
    if edge:
        try:
            subprocess.Popen([edge, f"--app={u}", "--window-size=980,760"],
                             creationflags=getattr(subprocess, "DETACHED_PROCESS", 0))
            return
        except OSError:
            pass
    webbrowser.open(u)


def abrir():
    abrir_url(iniciar())


if __name__ == "__main__":
    # teste manual: python painel.py
    print(iniciar())
    threading.Event().wait()
