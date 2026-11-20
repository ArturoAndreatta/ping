"""
Idioma do Ping no PC: janela, menu da bandeja e mensagens do Python.

- Automatico: o idioma de exibicao do Windows (pt-* = pt, es-* = es, o resto = en).
- Manual: escolhido nas opcoes da janela e guardado no config.json (chave "idioma": "pt", "en" ou "es";
  ausente ou "auto" = automatico).
- O log (ping.log) e os scripts .ps1 ficam em portugues, sempre: nada daqui vai pra eles.
- O texto da janela (index.html) tem o proprio dicionario em JS; aqui ficam so os textos do Python.
"""
import ctypes
import sys

CODIGOS = ("pt", "en", "es")
# Data Dragon quando nao ha client aberto nem locale guardado
LOCALE_DD = {"pt": "pt_BR", "en": "en_US", "es": "es_ES"}

_LANG_PT, _LANG_ES = 0x16, 0x0A  # idioma primario do LANGID do Windows (o resto, ingles incluso, cai em en)


def de_langid(langid):
    """pt, en ou es a partir do LANGID do Windows (GetUserDefaultUILanguage)."""
    primario = (langid or 0) & 0x3FF
    return "pt" if primario == _LANG_PT else "es" if primario == _LANG_ES else "en"


def windows():
    """Idioma de exibicao do Windows: pt, en ou es (en fora do Windows ou se a chamada falhar)."""
    if sys.platform != "win32":
        return "en"
    try:
        return de_langid(ctypes.windll.kernel32.GetUserDefaultUILanguage())
    except (AttributeError, OSError):
        return "en"


def escolha():
    """O que esta guardado: "pt", "en", "es" ou "auto"."""
    import lcu
    v = lcu.config().get("idioma")
    return v if v in CODIGOS else "auto"


def atual():
    """O idioma em uso agora: o escolhido ou, no automatico, o do Windows."""
    e = escolha()
    return windows() if e == "auto" else e


def definir(valor):
    """Guarda a escolha (pt, en, es ou auto). Devolve o idioma em uso."""
    import lcu
    if valor not in CODIGOS and valor != "auto":
        raise ValueError("idioma invalido")
    lcu.salvar_config({"idioma": valor})
    return atual()


def locale_dd():
    """Locale do Data Dragon pro idioma em uso (pt_BR, en_US, es_ES)."""
    return LOCALE_DD[atual()]


TEXTOS = {
    "pt": {
        "menu.abrir": "Abrir o Ping", "menu.log": "Ver log", "menu.reiniciar": "Reiniciar", "menu.sair": "Sair",
        "bandeja.iniciando": "Ping: iniciando",
        "bandeja.esperando": "Ping: esperando o LoL abrir",
        "bandeja.conectado": "Ping: conectado ao LoL",
        "bandeja.erro_painel": "Ping: erro ao abrir o painel, veja o log",
        "ja_rodando": "O Ping já está rodando na bandeja.",
        "firebase.anonimo": "Ative o login anônimo no Firebase (Authentication > Sign-in method > Anônimo)",
        "conta.preencha": "Preencha o e-mail e a senha.",
        "conta.email_existe": "Esse e-mail já tem conta. Use Entrar.",
        "conta.email_invalido": "Esse e-mail não parece certo.",
        "conta.senha_fraca": "A senha precisa de pelo menos 6 letras.",
        "conta.login_errado": "E-mail ou senha errados.",
        "conta.muitas_tentativas": "Muitas tentativas. Espere um pouco.",
        "conta.desativada": "Essa conta foi desativada.",
        "conta.generico": "Não deu certo. Tente de novo.",
        "conta.nao_pus": "Não consegui pôr este PC na conta. Tente de novo.",
        "conta.sem_conexao": "Sem conexão com a conta. Tente de novo.",
        "painel.so_instalado": "Só dá pra desinstalar o Ping instalado.",
    },
    "en": {
        "menu.abrir": "Open Ping", "menu.log": "View log", "menu.reiniciar": "Restart", "menu.sair": "Quit",
        "bandeja.iniciando": "Ping: starting",
        "bandeja.esperando": "Ping: waiting for LoL to open",
        "bandeja.conectado": "Ping: connected to LoL",
        "bandeja.erro_painel": "Ping: error opening the window, see the log",
        "ja_rodando": "Ping is already running in the tray.",
        "firebase.anonimo": "Turn on anonymous sign-in in Firebase (Authentication > Sign-in method > Anonymous)",
        "conta.preencha": "Enter your email and password.",
        "conta.email_existe": "That email already has an account. Use Sign in.",
        "conta.email_invalido": "That email doesn't look right.",
        "conta.senha_fraca": "The password needs at least 6 characters.",
        "conta.login_errado": "Wrong email or password.",
        "conta.muitas_tentativas": "Too many attempts. Wait a little.",
        "conta.desativada": "That account has been disabled.",
        "conta.generico": "That didn't work. Try again.",
        "conta.nao_pus": "Couldn't add this PC to the account. Try again.",
        "conta.sem_conexao": "No connection to the account. Try again.",
        "painel.so_instalado": "Only the installed Ping can be uninstalled.",
    },
    "es": {
        "menu.abrir": "Abrir Ping", "menu.log": "Ver registro", "menu.reiniciar": "Reiniciar", "menu.sair": "Salir",
        "bandeja.iniciando": "Ping: iniciando",
        "bandeja.esperando": "Ping: esperando a que se abra LoL",
        "bandeja.conectado": "Ping: conectado a LoL",
        "bandeja.erro_painel": "Ping: error al abrir la ventana, mira el registro",
        "ja_rodando": "Ping ya se está ejecutando en la bandeja.",
        "firebase.anonimo": "Activa el inicio de sesión anónimo en Firebase (Authentication > Sign-in method > Anónimo)",
        "conta.preencha": "Escribe el correo y la contraseña.",
        "conta.email_existe": "Ese correo ya tiene cuenta. Usa Entrar.",
        "conta.email_invalido": "Ese correo no parece correcto.",
        "conta.senha_fraca": "La contraseña necesita al menos 6 caracteres.",
        "conta.login_errado": "Correo o contraseña incorrectos.",
        "conta.muitas_tentativas": "Demasiados intentos. Espera un poco.",
        "conta.desativada": "Esa cuenta fue desactivada.",
        "conta.generico": "No funcionó. Inténtalo de nuevo.",
        "conta.nao_pus": "No pude poner este PC en la cuenta. Inténtalo de nuevo.",
        "conta.sem_conexao": "Sin conexión con la cuenta. Inténtalo de nuevo.",
        "painel.so_instalado": "Solo se puede desinstalar el Ping instalado.",
    },
}


def t(chave):
    """Texto do Python no idioma em uso (cai em portugues se faltar a chave)."""
    return TEXTOS.get(atual(), TEXTOS["pt"]).get(chave) or TEXTOS["pt"].get(chave) or chave
