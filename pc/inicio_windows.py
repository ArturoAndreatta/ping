"""
Abrir com o Windows (opcao abrir_com_windows do config.json, ligada por padrao).

Usa uma tarefa agendada "ao fazer logon" em vez do atalho da pasta Inicializacao: o Windows roda a pasta
Inicializacao so depois de todos os programas do registro, um de cada vez (Discord, Voicemod...), e o programa
chegava a abrir 4 minutos depois do login. A tarefa sai na hora do logon. Nao precisa de administrador
(tarefa do proprio usuario, sem elevar).

Com a tarefa criada, o atalho da Inicializacao sai (senao abriria duas vezes; a trava de instancia unica
seguraria, mas atrasaria). Desligada, sai a tarefa e o atalho. Se a tarefa falhar, o atalho fica.
"""
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from xml.sax.saxutils import escape

BASE = Path(__file__).resolve().parent
TAREFA = "Ping"
SEM_JANELA = getattr(subprocess, "CREATE_NO_WINDOW", 0)


def ligado(cfg):
    return cfg.get("abrir_com_windows") is not False


def _pythonw():
    exe = Path(sys.executable)
    w = exe.with_name("pythonw.exe")
    return w if w.exists() else exe


def _usuario():
    dom, nome = os.environ.get("USERDOMAIN"), os.environ.get("USERNAME")
    return f"{dom}\\{nome}" if dom else nome


def _xml():
    u = escape(_usuario() or "")
    # Priority 5: normal (o padrao 7 da tarefa deixaria o programa com prioridade baixa)
    # ExecutionTimeLimit PT0S: sem limite (o padrao de 72h derrubaria o programa)
    return f"""<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>Abre o Ping quando voce entra no Windows.</Description></RegistrationInfo>
  <Triggers><LogonTrigger><Enabled>true</Enabled><UserId>{u}</UserId></LogonTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>{u}</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings><StopOnIdleEnd>false</StopOnIdleEnd><RestartOnIdle>false</RestartOnIdle></IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>5</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>{escape(str(_pythonw()))}</Command>
      <Arguments>"{escape(str(BASE / "ping.pyw"))}"</Arguments>
      <WorkingDirectory>{escape(str(BASE))}</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"""


def _schtasks(*args):
    r = subprocess.run(["schtasks", *args], capture_output=True, text=True, encoding="utf-8",
                       errors="replace", creationflags=SEM_JANELA, timeout=20)
    return r.returncode == 0


def _atalho_inicializacao():
    import ctypes
    buf = ctypes.create_unicode_buffer(260)
    if ctypes.windll.shell32.SHGetFolderPathW(None, 0x07, None, 0, buf) != 0:  # CSIDL_STARTUP
        return None
    return Path(buf.value) / "Ping.lnk"


def _tirar_atalho():
    lnk = _atalho_inicializacao()
    if lnk and lnk.exists():
        try:
            lnk.unlink()
        except OSError:
            pass


def _criar_tarefa():
    tmp = Path(tempfile.gettempdir()) / "ping-tarefa.xml"
    tmp.write_text(_xml(), encoding="utf-16")
    try:
        return _schtasks("/Create", "/TN", TAREFA, "/XML", str(tmp), "/F")
    finally:
        try:
            tmp.unlink()
        except OSError:
            pass


def aplicar(ligar, log=print):
    """Cria ou tira a tarefa. Devolve se deu certo."""
    if ligar:
        if not _criar_tarefa():
            log("Abrir com o Windows: nao consegui criar a tarefa, fica o atalho da Inicializacao")
            return False
        _tirar_atalho()
        return True
    _schtasks("/Delete", "/TN", TAREFA, "/F")  # sem tarefa ja da erro: tanto faz
    _tirar_atalho()
    return True


def vigiar(cfg, log=print):
    """Thread da bandeja: aplica ao abrir (o caminho do Python pode ter mudado) e quando a opcao muda no painel."""
    if os.name != "nt":
        return
    feito = None
    while True:
        try:
            agora = ligado(cfg())
            if agora != feito:
                if aplicar(agora, log) and feito is not None:
                    log("Abrir com o Windows: " + ("ligado" if agora else "desligado"))
                feito = agora
        except Exception as e:
            log(f"Abrir com o Windows: erro {type(e).__name__}")
            feito = None
            time.sleep(60)
        time.sleep(3)
