"""
Atualizacao pelo GitHub Releases.

Cada release publica tres arquivos (workflow .github/workflows/release.yml):
- versao.json: versao, nome do zip, sha256 e hash das bibliotecas, assinado com Ed25519 (assinatura.py)
- ping-<versao>.zip: so os arquivos do programa (sem Python), pra atualizar quem ja instalou
- Ping-<versao>.exe: o instalador completo

sozinho() (thread da bandeja): confere ao abrir e a cada 10 min; com versao nova, baixa, confere a assinatura e
o sha256, extrai por cima e reinicia, so com o LoL fechado, no menu ou na sala (nunca na fila, selecao ou
partida). Se as bibliotecas mudaram (requirements), o zip nao basta: precisa do instalador novo.

Pasta de desenvolvimento (com .git) nunca se atualiza sozinha.
"""
import hashlib
import io
import os
import re
import stat
import time
import zipfile
from pathlib import Path

import servidor

BASE = Path(__file__).resolve().parent
URL_VERSAO = f"https://github.com/{servidor.REPO}/releases/latest/download/versao.json"
URL_ARQUIVO = f"https://github.com/{servidor.REPO}/releases/download/v{{versao}}/{{arquivo}}"
DEPS = ("requirements.txt",)
FASES_LIVRES = (None, "None", "Lobby")
INICIO = 8               # s depois de abrir (deixa o resto subir primeiro)
INTERVALO = 10 * 60      # s entre uma conferida e outra
SEM_REDE = 30            # s pra tentar de novo quando nao achou o servidor (Windows acabou de ligar)
OLHAR_FASE = 15          # s entre olhadas na fase enquanto espera o LoL ficar parado


def versao_local():
    try:
        return (BASE / "versao.txt").read_text(encoding="utf-8").strip() or None
    except OSError:
        return None


def desenvolvimento():
    return (BASE.parent / ".git").exists() or (BASE / ".git").exists()


def hash_deps():
    """Muda quando as bibliotecas mudam: ai o zip nao basta, precisa do instalador novo (traz o Python junto)."""
    h = hashlib.sha256()
    for f in DEPS:
        try:
            h.update((BASE / f).read_text(encoding="utf-8").replace("\r\n", "\n").encode("utf-8"))
        except OSError:
            pass
    return h.hexdigest()[:16]


def num(v):
    try:
        return tuple(int(x) for x in str(v).split("."))
    except ValueError:
        return None


def remoto():
    """versao.json do ultimo release, ou None sem internet ou sem assinatura valida."""
    try:
        import requests
        import assinatura
        r = requests.get(URL_VERSAO, timeout=20, headers={"Cache-Control": "no-cache"})
        r.raise_for_status()
        info = r.json()
        if not (isinstance(info, dict) and info.get("versao") and info.get("arquivo") and info.get("sha256")):
            return None
        return info if assinatura.info_valida(info) else None
    except Exception:
        return None


def atualizar(info, log=print):
    """Baixa o zip do release, confere e extrai por cima. So arquivos do programa (config, cache e log nao vem
    no pacote). versao.txt por ultimo: se algo falhar, a versao local nao muda e tenta de novo depois."""
    import assinatura
    import requests
    if not assinatura.info_valida(info):
        raise RuntimeError("versao sem assinatura valida")
    if not re.fullmatch(r"ping-[0-9.]+\.zip", str(info["arquivo"])):
        raise RuntimeError("pacote de atualizacao invalido")
    nova, atual = num(info["versao"]), num(versao_local())
    if not nova or (atual and nova <= atual):
        raise RuntimeError("nada pra atualizar")
    if info.get("deps") != hash_deps():
        raise RuntimeError("essa versao precisa do instalador novo")
    r = requests.get(URL_ARQUIVO.format(versao=info["versao"], arquivo=info["arquivo"]), timeout=180)
    r.raise_for_status()
    if hashlib.sha256(r.content).hexdigest() != info["sha256"]:
        raise RuntimeError("download veio corrompido")
    novos = {}
    with zipfile.ZipFile(io.BytesIO(r.content)) as z:
        for i in z.infolist():
            if i.is_dir():
                continue
            destino = (BASE / i.filename).resolve()
            if BASE not in destino.parents:
                raise RuntimeError("pacote de atualizacao invalido")
            novos[destino] = z.read(i)
    marca = BASE / "versao.txt"
    for destino in sorted(novos, key=lambda d: d == marca):
        conteudo = novos[destino]
        if destino.exists() and destino.read_bytes() == conteudo:
            continue
        destino.parent.mkdir(parents=True, exist_ok=True)
        tmp = destino.with_name(destino.name + ".novo")
        tmp.write_bytes(conteudo)
        if destino.exists():
            os.chmod(destino, stat.S_IWRITE)
        os.replace(tmp, destino)
    log(f"Atualizar: v{info['versao']} baixada")


def ja(log=print):
    """Reiniciar pedido por voce (bandeja ou janela): se tem versao nova, baixa antes, pra ela subir ja nesse
    reinicio (sem esperar a conferida dos 10 min). Respeita a opcao Atualizar sozinho. True se atualizou."""
    if desenvolvimento():
        return False
    try:
        import lcu
        if lcu.config().get("atualizar_sozinho", True) is False:
            return False
        info = remoto()
        if not (info and num(info["versao"]) and num(info["versao"]) > (num(versao_local()) or (0,))):
            return False
        atualizar(info, log=log)
        return True
    except Exception as erro:
        log(f"Atualizacao: pulada no reinicio ({erro})")
        return False


def _parado(fase, livre):
    """Fase livre em 3 leituras seguidas: uma falha solta da LCU (devolve None) nao vira 'client fechado'."""
    for i in range(3):
        if fase() not in FASES_LIVRES or not livre():
            return False
        if i < 2:
            time.sleep(2)
    return True


def sozinho(fase, reiniciar, ligado=lambda: True, livre=lambda: True, log=print):
    """Thread da bandeja. fase(): fase do client (None fechado); reiniciar(): sobe a versao nova;
    ligado(): opcao Atualizar sozinho; livre(): False segura (LoL abrindo)."""
    if desenvolvimento():
        return
    time.sleep(INICIO)
    falhou = {}  # versao que deu erro -> quando (nao tenta de novo a cada volta, nem enche o log)
    tentativas = 0
    while True:
        espera = INTERVALO
        try:
            info = remoto() if ligado() else None
            if ligado() and info is None and tentativas < 10:
                tentativas += 1
                espera = SEM_REDE
            elif info and num(info["versao"]) and num(info["versao"]) > (num(versao_local()) or (0,)):
                tentativas = 10
                if time.time() - falhou.get(info["versao"], 0) > 3600:
                    while not ligado() or not _parado(fase, livre):
                        time.sleep(OLHAR_FASE)
                    try:
                        atualizar(info, log=log)
                    except Exception as erro:
                        falhou[info["versao"]] = time.time()
                        log(f"Atualizacao: pulada ({erro})")
                    else:
                        # enquanto baixava alguem pode ter entrado na fila: so reinicia com a fase livre de novo
                        while not _parado(fase, livre):
                            time.sleep(OLHAR_FASE)
                        log(f"Atualizacao: v{info['versao']}, reiniciando")
                        time.sleep(1)
                        reiniciar()
                        return
            else:
                tentativas = 10
        except Exception as erro:  # nunca derruba a bandeja por causa da atualizacao
            log(f"Atualizacao: erro ({erro})")
        time.sleep(espera)
