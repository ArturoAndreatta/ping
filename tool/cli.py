"""Base dos scripts de tool/: marca em caixa, etapas numeradas, comando com a saida engolida e resumo final.

Mesmo visual dos scripts dos outros projetos (skill scripts-terminal). Rode da raiz do repositorio.
"""
import os
import re
import subprocess
import sys
import threading
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]

WORDMARK = [
    "█████ █████ █   █ █████",
    "█   █   █   ██  █ █    ",
    "█████   █   █ █ █ █  ██",
    "█       █   █  ██ █   █",
    "█     █████ █   █ █████",
]
LARGURA_CAIXA = 41  # largura da marca + 6, minimo 41

COR = sys.stdout.isatty() and "--no-color" not in sys.argv and not os.environ.get("NO_COLOR")
DRY = "--dry-run" in sys.argv


def _c(cod, t):
    return f"\x1b[{cod}m{t}\x1b[0m" if COR else t


def marca(t): return _c("38;5;179", t)  # dourado #C8AA6E do Ping
def dim(t): return _c("2", t)
def negrito(t): return _c("1", t)
def verde(t): return _c("32", t)
def amarelo(t): return _c("33", t)
def vermelho(t): return _c("31", t)
def link(t): return _c("4;36", t)


def _texto(s):
    print(s, flush=True)


def iniciar_console():
    """UTF-8 no console: em cp850 todo bloco, seta e check vira '?'."""
    for f in (sys.stdout, sys.stderr):
        try:
            f.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError):
            pass
    if os.name == "nt" and COR:
        os.system("")  # liga as cores ANSI no console do Windows


def banner(subtitulo):
    def linha(conteudo, cor=lambda t: t):
        sobra = LARGURA_CAIXA - len(conteudo)
        esq = sobra // 2
        return f"  {marca('│')}{' ' * esq}{cor(conteudo)}{' ' * (sobra - esq)}{marca('│')}"
    print()
    _texto(f"  {marca('┌' + '─' * LARGURA_CAIXA + '┐')}")
    for w in WORDMARK:
        _texto(linha(w, lambda t: negrito(marca(t))))
    _texto(linha(""))
    _texto(linha(subtitulo, dim))
    _texto(f"  {marca('└' + '─' * LARGURA_CAIXA + '┘')}")


def falhar(msg, saida=""):
    if saida:
        print()
        for l in saida.rstrip().splitlines():
            _texto(f"      {l}")
    print()
    _texto(f"  {vermelho('✗')} {negrito('Interrompido')}")
    for l in msg.splitlines():
        _texto(f"    {l}")
    print()
    sys.exit(1)


def ok(t, desde=None):
    tempo = f" {_dur(time.time() - desde)}" if desde else ""
    _texto(f"    {verde('✓')} {dim(t + tempo)}")


def aviso(t):
    _texto(f"    {amarelo('!')} {t}")


def _dur(s):
    return f"{s:.0f}s" if s < 60 else f"{int(s // 60)}min {int(s % 60)}s"


class Etapas:
    """Etapas numeradas. O total e escrito a mao no script, com comentario listando cada uma."""

    def __init__(self, total):
        self.total, self.n, self._ultima = total, 0, 0.0

    def comecar(self, descricao, dica=""):
        self.n += 1
        if self.n > self.total:
            aviso(f"etapa {self.n} passou do total {self.total}: corrija o total no script")
        espera = 1 - (time.time() - self._ultima)  # etapa instantanea nao brota junto da anterior
        if espera > 0 and not DRY:
            time.sleep(espera)
        self._ultima = time.time()
        print()
        d = f" {dim('(' + dica + ')')}" if dica else ""
        _texto(f"  {marca('▸')} {dim(f'[{self.n}/{self.total}]')} {descricao}{d}")
        return time.time()


class Girinho:
    """Girinho na linha atual; so com terminal de verdade (redirecionado encheria o log de \\r)."""
    QUADROS = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

    def __init__(self, texto):
        self.texto, self._fim = texto, threading.Event()
        self._t = threading.Thread(target=self._girar, daemon=True)

    def _girar(self):
        i = 0
        while not self._fim.wait(0.12):
            sys.stdout.write(f"\r    {marca(self.QUADROS[i % 10])} {dim(self.texto)}\x1b[K")
            sys.stdout.flush()
            i += 1

    def __enter__(self):
        if sys.stdout.isatty() and not DRY:
            self._t.start()
        return self

    def __exit__(self, *a):
        self._fim.set()
        if self._t.is_alive():
            self._t.join()
            sys.stdout.write("\r\x1b[K")
            sys.stdout.flush()


def _mascarar(t):
    return re.sub(r"((?:KEY|TOKEN|SECRET|PASSWORD)=)\S+", r"\1***", t, flags=re.I)


def rodar(cmd, pasta=RAIZ, falha="O comando falhou."):
    """Roda engolindo a saida; em falha mostra ela inteira e para. flutter e afins sao .bat: shell=True."""
    rel = Path(pasta).resolve().relative_to(RAIZ).as_posix()
    _texto(f"    {dim('$ ' + _mascarar(' '.join(cmd)) + (f' ({rel})' if rel != '.' else ''))}")
    if DRY:
        return ""
    with Girinho(cmd[0] + " rodando"):
        r = subprocess.run(cmd, cwd=pasta, capture_output=True, shell=os.name == "nt")
    saida = (r.stdout + r.stderr).decode("utf-8", errors="replace")
    if r.returncode:
        falhar(falha, saida)
    return saida


def resumo(titulo, endereco, campos):
    print()
    _texto(f"  {verde('●')} {negrito(titulo)}  {link(endereco)}")
    _texto(f"  {dim('│')}")
    larg = max(len(k) for k, _ in campos)
    for i, (k, v) in enumerate(campos):
        _texto(f"  {dim(('└─ ' if i == len(campos) - 1 else '├─ ') + k.ljust(larg) + '   ' + str(v))}")
    print()
