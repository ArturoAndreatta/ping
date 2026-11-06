"""
Ponte entre o client do LoL e o celular: o PC espelha o que esta acontecendo no client no Firebase Realtime
Database e executa os comandos que o celular manda (o celular nao alcanca o PC atras do roteador, o RTDB faz de
caixa de correio). Nada acontece no client sem um toque seu no celular.

- Login anonimo do Firebase (sem conta): o refresh token fica em cache/celular.json. E o uid deste PC.
- So a sua conta mexe pelo celular: o painel entra na conta (pcs/<pc>/conta = uid da conta) e o celular que
  entrar com a mesma conta ve este PC.
- PC -> celular: ao_vivo/<pc> com o estado atual (fase, fila, partida encontrada, sala, selecao, partida). Grava
  so quando muda, mais um "visto" a cada 30s pro celular saber que o PC esta ligado.
- Celular -> PC: comandos/<pc>/<id>. Escuta por stream, executa na LCU, responde em ao_vivo/<pc>/resposta e
  apaga o comando. Comando com mais de VALIDADE_CMD segundos e ignorado.
"""
import collections
import ctypes
import email.utils
import json
import os
import random
import re
import threading
import time
from datetime import datetime
from urllib.parse import quote

import requests

import lcu
import qrcodegen
import servidor

DB = servidor.DB
API_KEY = servidor.API_KEY
SITE = servidor.SITE
CACHE = lcu.CACHE
ARQ = CACHE / "celular.json"
VALIDADE_CMD = 15     # comando mais velho que isso nao roda (celular que ficou sem rede e mandou depois)
# limite de comandos do celular (quantos, em quantos segundos): app com bug ou toque repetido nao enche o client
LIMITE_GERAL = (20, 10)
LIMITES = {"chat": (5, 10), "dm": (5, 10), "convidar": (3, 20), "criar_sala": (3, 20), "posicao": (6, 20),
           "buscar": (4, 20), "sair_fila": (4, 20), "runa_salvar": (4, 20), "abrir_lol": (3, 60),
           "fechar_lol": (3, 60)}
VISTO_CADA = 30       # de quanto em quanto tempo avisa que o PC continua ligado
COMANDOS = {
    "aceitar": ("POST", "/lol-matchmaking/v1/ready-check/accept", "Partida aceita"),
    "recusar": ("POST", "/lol-matchmaking/v1/ready-check/decline", "Partida recusada"),
    "sair_fila": ("DELETE", "/lol-lobby/v2/lobby/matchmaking/search", "Saiu da fila"),
    "buscar": ("POST", "/lol-lobby/v2/lobby/matchmaking/search", "Fila iniciada"),
    "sair_sala": ("DELETE", "/lol-lobby/v2/lobby", "Saiu da sala"),
}

_conta = {"uid": None, "refresh": None, "id_token": None, "expira": 0.0}
_vivo = {"erro": None, "offset": None, "abrindo": 0.0, "abertura": None, "abriu": 0.0, "fechando": 0.0,
         "celular_visto": 0.0, "celular_aberto": False, "escrita_sel": 0.0, "banco_t": 0.0}


# ---------------- voce esta perto do PC? (so pros avisos no celular) ----------------
# Le so o Windows (ultimo toque no mouse ou teclado, GetLastInputInfo): nada vai pro client.

PERTO_MINUTOS = 2  # mexeu no PC nesse tempo: voce esta perto e o aviso no celular nao precisa sair


class _LASTINPUTINFO(ctypes.Structure):
    _fields_ = [("cbSize", ctypes.c_uint), ("dwTime", ctypes.c_uint)]


def _ultimo_input():
    """Tick (ms desde que o Windows ligou, 32 bits) do ultimo mouse/teclado. None fora do Windows."""
    try:
        info = _LASTINPUTINFO(ctypes.sizeof(_LASTINPUTINFO))
        if ctypes.windll.user32.GetLastInputInfo(ctypes.byref(info)):
            return info.dwTime
    except (AttributeError, OSError):
        pass
    return None


def _ocioso():
    """Segundos sem mexer no mouse nem no teclado."""
    t = _ultimo_input()
    if t is None:
        return 0.0
    return ((ctypes.windll.kernel32.GetTickCount() - t) & 0xFFFFFFFF) / 1000


# App aberto na tela do celular (ele manda "olhando" a cada CELULAR_PULSO s enquanto esta visivel e "olhando"
# false ao fechar ou minimizar): voce ja esta vendo, entao o aviso nao precisa sair.
CELULAR_PULSO = 20
CELULAR_VALE = 50  # sem pulso por isso (app fechado a forca, sem rede, iPhone que congelou a aba): saiu


def celular_olhando(valor):
    """Comando olhando do app. So memoria, nada vai pro client."""
    agora = time.time()
    if valor is True:
        _vivo["celular_aberto"], _vivo["celular_visto"] = True, agora
    elif _celular_aberto():
        _vivo["celular_aberto"], _vivo["celular_visto"] = False, agora


def _celular_aberto():
    if _vivo["celular_aberto"] and time.time() - _vivo["celular_visto"] > CELULAR_VALE:
        _vivo["celular_aberto"] = False  # parou de pulsar: conta da ultima vez que viu
    return _vivo["celular_aberto"]


def _parado():
    """Segundos parado de verdade: sem mexer no PC e sem o app do celular na tela."""
    return min(_ocioso(), time.time() - _vivo["celular_visto"])


def perto_minutos():
    return PERTO_MINUTOS


_lock = threading.Lock()


def _log(msg):
    lcu.log(f"Celular: {msg}")


def _chave(texto):
    """Texto vira chave do Firebase (sem . # $ [ ] /), minuscula pra casar sempre."""
    return re.sub(r"[.#$\[\]/\s]+", "_", texto.strip().lower())


# ---------------- login anonimo ----------------

def _carregar():
    if _conta["refresh"]:
        return
    try:
        d = json.loads(ARQ.read_text(encoding="utf-8"))
        _conta.update(uid=d.get("uid"), refresh=d.get("refresh"))
    except (OSError, ValueError):
        pass


def _salvar():
    CACHE.mkdir(exist_ok=True)
    ARQ.write_text(json.dumps({"uid": _conta["uid"], "refresh": _conta["refresh"]}), encoding="utf-8")


def _criar_conta():
    r = requests.post(f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
                      json={"returnSecureToken": True}, timeout=15)
    j = r.json()
    if r.status_code != 200:
        msg = (j.get("error") or {}).get("message", str(r.status_code))
        if "ADMIN_ONLY" in msg or "OPERATION_NOT_ALLOWED" in msg:
            raise PermissionError("Ative o login anônimo no Firebase (Authentication > Sign-in method > Anônimo)")
        raise PermissionError(f"login anonimo falhou ({msg})")
    _conta.update(uid=j["localId"], refresh=j["refreshToken"], id_token=j["idToken"],
                  expira=time.time() + int(j.get("expiresIn", 3600)) - 60)
    _salvar()


TOKEN_MORTO = ("INVALID_REFRESH_TOKEN", "TOKEN_EXPIRED", "USER_NOT_FOUND", "USER_DISABLED")


def token():
    """idToken valido do PC (cria a conta anonima na primeira vez)."""
    with _lock:
        if _conta["id_token"] and time.time() < _conta["expira"]:
            return _conta["id_token"]
        _carregar()
        if not _conta["refresh"]:
            _criar_conta()
            return _conta["id_token"]
        r = requests.post(f"https://securetoken.googleapis.com/v1/token?key={API_KEY}",
                          data={"grant_type": "refresh_token", "refresh_token": _conta["refresh"]}, timeout=15)
        if r.status_code == 400 and any(m in r.text for m in TOKEN_MORTO):
            # conta apagada no console: comeca outra (o painel entra na conta de novo)
            _conta.update(uid=None, refresh=None)
            _criar_conta()
            return _conta["id_token"]
        r.raise_for_status()
        j = r.json()
        _conta.update(id_token=j["id_token"], expira=time.time() + int(j.get("expires_in", 3600)) - 60)
        return _conta["id_token"]


def uid():
    token()
    return _conta["uid"]


def agora_ms():
    """Hora do servidor do Firebase em ms. O relogio do PC pode estar errado (ja vimos 17s adiantado): o celular
    carimba os comandos com a hora do servidor e conta o tempo da fila por ela."""
    return time.time() * 1000 + (_vivo["offset"] or 0)


def _acertar_relogio(r):
    """Primeira estimativa pelo cabecalho Date (precisao de 1s); depois o 'visto' gravado acerta no ms."""
    if _vivo["offset"] is None and r.headers.get("Date"):
        try:
            _vivo["offset"] = email.utils.parsedate_to_datetime(r.headers["Date"]).timestamp() * 1000 + 500 - time.time() * 1000
        except (TypeError, ValueError):
            pass


_http = threading.local()  # requests.Session nao e thread-safe: uma por thread


def _sessao():
    if getattr(_http, "s", None) is None:
        _http.s = requests.Session()
    return _http.s


def _db(metodo, caminho, params=None, **kw):
    r = _sessao().request(metodo, f"{DB}/{caminho}.json", params={**(params or {}), "auth": token()},
                          timeout=10, **kw)
    _acertar_relogio(r)
    if r.status_code == 401:  # token recusado antes da hora: pega outro na proxima
        _conta["id_token"] = None
    if r.status_code in (401, 403):  # a mensagem do requests traz a URL com o token: nunca mostrar
        raise PermissionError("O Firebase recusou (confira as regras do banco)")
    if not r.ok:
        raise requests.RequestException(f"Firebase respondeu {r.status_code}")
    return r.json() if r.content else None


# ---------------- QR do app (painel) ----------------

def _svg(texto):
    """QR do app: pontos redondos, olhos quadrados (arredondar atrapalhou a leitura) e o logo do Ping no meio.

    Correcao HIGH (aguenta ate 30% do codigo coberto): o logo tapa uns 6%. Borda de 2 modulos: o quadrado
    branco do painel completa a margem. Cores pelas variaveis do tema (--qr-tinta, --gold, --teal).
    """
    qr = qrcodegen.QrCode.encode_text(texto, qrcodegen.QrCode.Ecc.HIGH)
    n, b = qr.get_size(), 2
    t = n + b * 2
    olhos = ((0, 0), (n - 7, 0), (0, n - 7))
    # meio livre pro logo: quadrado impar centrado, ~22% do lado
    lado = max(5, round(n * 0.22)) | 1
    ini = (n - lado) // 2

    def livre(x, y):
        if any(ox <= x < ox + 7 and oy <= y < oy + 7 for ox, oy in olhos):
            return False
        return not (ini - 1 <= x <= ini + lado and ini - 1 <= y <= ini + lado)  # 1 modulo de folga

    pontos = "".join(f'M{x + b + .5},{y + b + .08}a.42,.42 0 1 0 .001 0z'
                     for y in range(n) for x in range(n) if qr.get_module(x, y) and livre(x, y))
    eyes = ""
    for ox, oy in olhos:
        x, y = ox + b, oy + b
        eyes += (f'<rect x="{x + .5}" y="{y + .5}" width="6" height="6" fill="none" '
                 f'stroke="var(--qr-tinta, #111)" stroke-width="1"/>'
                 f'<rect x="{x + 2}" y="{y + 2}" width="3" height="3" fill="var(--qr-olho, #111)"/>')
    c, r = t / 2, lado / 2  # logo do Ping (o mesmo do topo do painel), no viewBox 64 escalado
    k = lado / 64
    logo = (f'<circle cx="{c}" cy="{c}" r="{r + .3}" fill="#fff"/>'
            f'<g transform="translate({c - 32 * k},{c - 32 * k}) scale({k})">'
            '<circle cx="32" cy="32" r="28.5" fill="none" stroke="var(--qr-marca, #8A6A2E)" stroke-width="5"/>'
            '<circle cx="32" cy="32" r="20" fill="none" stroke="var(--qr-marca2, #087F86)" stroke-width="5"/>'
            '<path d="M32 18.5 L45.5 32 L32 45.5 L18.5 32 Z" fill="var(--qr-marca, #8A6A2E)"/></g>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {t} {t}" role="img" aria-label="QR code do app">'
            f'<rect width="{t}" height="{t}" fill="#fff"/><path d="{pontos}" fill="var(--qr-tinta, #111)"/>'
            f'{eyes}{logo}</svg>')


# ---------------- conta (painel) ----------------
# O PC entra na conta pelo painel: grava pcs/<pc>/conta = uid da conta (com o token do PC) e se poe na lista
# da conta, contas/<uid>/pcs/<pc> (com o token da conta, que prova a senha). O celular que entrar com a mesma
# conta ve este PC; sem conta o celular nao ve nada. A senha nao fica guardada: so o e-mail e o uid, em
# cache/conta.json.

ARQ_CONTA = CACHE / "conta.json"
ERROS_CONTA = (("EMAIL_EXISTS", "Esse e-mail já tem conta. Use Entrar."),
               ("INVALID_EMAIL", "Esse e-mail não parece certo."),
               ("WEAK_PASSWORD", "A senha precisa de pelo menos 6 letras."),
               ("INVALID_LOGIN_CREDENTIALS", "E-mail ou senha errados."),
               ("EMAIL_NOT_FOUND", "E-mail ou senha errados."),
               ("INVALID_PASSWORD", "E-mail ou senha errados."),
               ("TOO_MANY_ATTEMPTS", "Muitas tentativas. Espere um pouco."),
               ("USER_DISABLED", "Essa conta foi desativada."))


def conta():
    """Conta deste PC ({email, uid}) ou None."""
    try:
        d = json.loads(ARQ_CONTA.read_text(encoding="utf-8"))
        return d if isinstance(d, dict) and d.get("uid") else None
    except (OSError, ValueError):
        return None


def entrar_conta(email, senha, criar=False):
    email = (email or "").strip() if isinstance(email, str) else ""
    if not email or not isinstance(senha, str) or not senha:
        raise ValueError("Preencha o e-mail e a senha.")
    rota = "signUp" if criar else "signInWithPassword"
    r = requests.post(f"https://identitytoolkit.googleapis.com/v1/accounts:{rota}?key={API_KEY}",
                      json={"email": email, "password": senha, "returnSecureToken": True}, timeout=15)
    j = r.json() if r.content else {}
    if r.status_code != 200:
        msg = (j.get("error") or {}).get("message", "")
        raise ValueError(next((t for k, t in ERROS_CONTA if k in msg), "Não deu certo. Tente de novo."))
    cuid, ctok = j["localId"], j["idToken"]
    eu = uid()
    _db("PUT", f"pcs/{eu}/conta", json=cuid)
    quem = _quem()
    corpo = {}
    if quem.get("pc_nome"):
        corpo["pc"] = quem["pc_nome"]
    if quem.get("conta_lol"):
        corpo["nome"] = quem["conta_lol"]
        corpo[f"lol/{_chave(quem['conta_lol'])}"] = quem["conta_lol"]
    base = f"{DB}/contas/{cuid}/pcs/{eu}.json"
    s = _sessao()
    try:
        ja = s.get(base, params={"auth": ctok}, timeout=10)
        if not (ja.ok and ja.json()):
            corpo["desde"] = {".sv": "timestamp"}
        ok = s.patch(base, params={"auth": ctok}, json=corpo, timeout=10).ok
    except requests.RequestException:
        ok = False
    if not ok:  # a URL leva o token: nunca mostrar o erro do requests
        _db("DELETE", f"pcs/{eu}/conta")
        raise ValueError("Não consegui pôr este PC na conta. Tente de novo.")
    CACHE.mkdir(exist_ok=True)
    ARQ_CONTA.write_text(json.dumps({"email": email, "uid": cuid}), encoding="utf-8")
    _log("conta conectada")
    return {"conta": _conta_painel()}


def sair_conta():
    _db("DELETE", f"pcs/{uid()}/conta")
    try:
        ARQ_CONTA.unlink()
    except OSError:
        pass
    _log("conta desconectada")


def _conta_painel():
    c = conta()
    if not c:
        return None
    return {"email": c.get("email") or ""}


def qr_app():
    """QR que abre o app no celular (so o endereco: entrar e com a conta, nada de vinculo no link)."""
    if not _vivo.get("qr_svg"):
        _vivo["qr_svg"] = _svg(SITE)
    return {"url": SITE, "svg": _vivo["qr_svg"]}


# ---------------- LCU ----------------

def _lcu(metodo, caminho, **kw):
    return lcu.req(metodo, caminho, **kw)


def _get(caminho):
    return lcu.get(caminho)


def _estavel(antigo, novo, folga=2000):
    """Inicio calculado a partir do 'ha quanto tempo' oscila 1s entre leituras: so troca se mudou de verdade."""
    return antigo if antigo is not None and novo is not None and abs(antigo - novo) <= folga else novo


POSICOES = {"TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY", "FILL"}
CHAT_MAX = 30         # mensagens da sala que vao pro celular
_nomes = {}           # puuid -> (nome, tag): a sala nao traz o Riot ID
_conversa = {"muc": None, "id": None}
_listas = {"sessao": None, "pick": [], "ban": [], "grade": [], "ordem": "nome"}  # grade da selecao atual


def _riot_id(puuid):
    if puuid not in _nomes:
        s = _get(f"/lol-summoner/v2/summoners/puuid/{puuid}") or {}
        if not s.get("gameName"):
            return "", ""  # tenta de novo na proxima
        _nomes[puuid] = (s["gameName"], s.get("tagLine") or "")
    return _nomes[puuid]


def _id_conversa(muc):
    """Conversa da sala (customGame) ou da selecao (championSelect): o id comeca pelo multiUserChatId."""
    if not muc:
        return None
    if _conversa["muc"] != muc or not _conversa["id"]:
        conv = next((c for c in _get("/lol-chat/v1/conversations") or []
                     if c.get("type") in ("customGame", "championSelect") and str(c.get("id", "")).startswith(muc)), None)
        _conversa.update(muc=muc, id=conv and conv["id"])
    return _conversa["id"]


def _ms(iso):
    try:
        return int(datetime.fromisoformat(str(iso).replace("Z", "+00:00")).timestamp() * 1000)
    except ValueError:
        return 0


def sala():
    """Quem esta na sala e o chat dela (None fora de sala)."""
    lobby = _get("/lol-lobby/v2/lobby")
    if not isinstance(lobby, dict) or not lobby.get("members"):
        return None
    eu = (lobby.get("localMember") or {}).get("puuid")
    membros = []
    for m in lobby["members"]:
        nome, tag = _riot_id(m.get("puuid")) if m.get("puuid") else ("", "")
        pos = [x for x in (m.get("firstPositionPreference"), m.get("secondPositionPreference")) if x in POSICOES]
        membros.append({"nome": nome or m.get("summonerName") or "Jogador", "tag": tag, "icone": m.get("summonerIconId") or 0,
                        "puuid": m.get("puuid") or "",
                        "lider": bool(m.get("isLeader")), "eu": m.get("puuid") == eu, "pos": pos})
    cid = _id_conversa(lobby.get("multiUserChatId"))
    local = lobby.get("localMember") or {}
    na_sala = {m.get("puuid") for m in lobby["members"]}
    convidados = []
    for c in lobby.get("invitations") or []:
        if c.get("state") == "Pending" and c.get("toPuuid") and c["toPuuid"] not in na_sala:
            nome, tag = _riot_id(c["toPuuid"])
            convidados.append({"nome": nome or c.get("toSummonerName") or "Amigo", "tag": tag, "puuid": c["toPuuid"]})
    gc = lobby.get("gameConfig") or {}
    segunda_ok, segunda_opcoes = _regras_posicao(lobby, local.get("firstPositionPreference"))
    return {"membros": membros, "posicoes": bool(gc.get("showPositionSelector")),
            "segunda_ok": segunda_ok, "segunda_opcoes": segunda_opcoes,
            "minhas_pos": [p if p in POSICOES else "" for p in (local.get("firstPositionPreference"),
                                                                 local.get("secondPositionPreference"))],
            "fila": gc.get("queueId") or 0, "custom": bool(gc.get("isCustom")),
            "max": gc.get("maxLobbySize") or 5, "convidados": convidados,
            "pode_convidar": local.get("allowedInviteOthers") is not False,
            "chat": _chat(cid, eu), "chat_ok": bool(cid)}


def _chat(cid, eu):
    """Ultimas mensagens de uma conversa, no formato do celular."""
    chat = []
    for x in (_get(f"/lol-chat/v1/conversations/{quote(cid)}/messages") or [])[-CHAT_MAX:] if cid else []:
        tipo, corpo, de = x.get("type"), str(x.get("body") or ""), x.get("fromPuuid") or ""
        if tipo == "system" and corpo in ("joined_room", "left_room"):
            nome = (_riot_id(de)[0] if de else "") or "Alguém"
            item = {"tipo": "aviso", "texto": f"{nome} {'entrou' if corpo == 'joined_room' else 'saiu'}"}
        elif tipo == "information":
            item = {"tipo": "aviso", "texto": corpo[:200]}
        elif tipo in ("groupchat", "chat"):
            item = {"tipo": "msg", "texto": corpo[:300], "de": _nomes.get(de, ("",))[0], "eu": de == eu}
        else:
            continue
        chat.append(dict(item, id=str(x.get("id") or ""), hora=_ms(x.get("timestamp"))))
    return chat


# ---------------- criar sala e convidar ----------------

# grupos da tela Jogar do client (gameSelectCategory / gameSelectModeGroup), na ordem em que aparecem
GRUPOS_MODO = {"kSummonersRift": "Summoner's Rift", "kARAM": "ARAM", "kJade": "Rift Clássico",
               "kAlternativeLeagueGameModes": "Outros modos", "kTeamfightTactics": "TFT"}
GRUPOS_CATEGORIA = {"kVersusAI": "Contra a IA", "CreateCustom": "Personalizada", "kTraining": "Treino"}
ORDEM_GRUPOS = ["Summoner's Rift", "ARAM", "Rift Clássico", "Outros modos", "Contra a IA", "Personalizada",
                "Treino", "TFT"]
# personalizada: o client pede o jeito de escolher (mutador). Fila fora daqui vai como escolha as cegas
MUTADOR = {3100: 1, 3200: 1, 3260: 1, 3270: 1, 3110: 2, 3210: 2, 3262: 2, 3120: 4, 3220: 4, 3130: 6, 3230: 6}
FASES_SALA = ("None", "Lobby")  # fora disso (fila, selecao, partida) nao da pra criar sala nem convidar
_amg = {"t": 0.0, "lista": []}


def _filas_brutas():
    q, _ = lcu.fixo("/lol-game-queues/v1/queues", validade=600)
    return q if isinstance(q, list) else []


def filas_sala():
    """Modos que da pra jogar agora, agrupados como na tela Jogar do client."""
    out, vistos = [], set()
    for x in _filas_brutas():
        if (x.get("queueAvailability") != "Available" or x.get("isVisible") is False or x.get("isEnabled") is False
                or x.get("id", -1) <= 0 or x["id"] in vistos):
            continue
        cat = x.get("gameSelectCategory") or ""
        grupo = GRUPOS_CATEGORIA.get(cat) or (GRUPOS_MODO.get(x.get("gameSelectModeGroup")) if cat == "kPvP" else None)
        nome = x.get("description") or x.get("shortName") or x.get("name")
        if not grupo or not nome:
            continue
        vistos.add(x["id"])
        out.append({"id": x["id"], "nome": nome, "grupo": grupo, "custom": bool(x.get("isCustom")),
                    "_p": -(x.get("gameSelectPriority") or 0)})
    out.sort(key=lambda f: (ORDEM_GRUPOS.index(f["grupo"]), f["_p"], f["nome"]))
    for f in out:
        del f["_p"]
    return out


def _status_amigo(f):
    """(texto, da pra convidar) do jeito que a lista de amigos do client mostra."""
    jogo, disp = (f.get("lol") or {}).get("gameStatus") or "", f.get("availability")
    if disp == "mobile":
        return "No celular", False
    if jogo == "inGame":
        return "Em partida", False
    if jogo == "championSelect":
        return "Na seleção", False
    if jogo == "inQueue":
        return "Na fila", True
    if jogo.startswith("hosting_"):
        return "Numa sala", True
    if jogo == "spectating":
        return "Assistindo", True
    if disp == "away":
        return "Ausente", True
    if disp == "dnd":
        return "Ocupado", False
    return "Disponível", True


def _amigos_client():
    if time.time() - _amg["t"] > 4:  # a lista inteira tem ~80 KB: nao precisa ler a cada volta
        lst = _get("/lol-chat/v1/friends")
        _amg.update(t=time.time(), lista=lst if isinstance(lst, list) else [])
    return _amg["lista"]


def amigos_online():
    """Amigos online no LoL: quem da pra convidar primeiro."""
    out = []
    for f in _amigos_client():
        if (f.get("availability") == "offline" or f.get("product") not in ("league_of_legends", "", None)
                or not f.get("gameName") or not f.get("puuid")):
            continue
        texto, pode = _status_amigo(f)
        out.append({"puuid": f["puuid"], "nome": f["gameName"], "tag": f.get("gameTag") or "",
                    "icone": f.get("icon") or 0, "status": texto, "pode": pode})
    out.sort(key=lambda a: (not a["pode"], a["nome"].lower()))
    return out[:60]


# ---------------- mensagens com amigos ----------------

DM_MAX = 8            # conversas com amigos que vao pro celular (as mais recentes)
_dms = {}             # id da conversa -> (id da ultima mensagem, mensagens): so le de novo quando chega outra
_eu = {"puuid": None, "t": 0.0}
_conv_de = {}         # puuid do amigo -> id da conversa no client (pra marcar como lida)


def _meu_puuid():
    if not _eu["puuid"] or time.time() - _eu["t"] > 60:
        _eu.update(puuid=(_get("/lol-chat/v1/me") or {}).get("puuid") or _eu["puuid"], t=time.time())
    return _eu["puuid"]


def _amigo_da_conversa(c, amigos):
    return amigos.get(c.get("id")) or amigos.get(c.get("pid"))


def conversas():
    """Conversas particulares com amigos (como a janela de chat do client), as mais recentes primeiro. Chave =
    puuid do amigo. A lista de conversas e lida a cada volta (local); as mensagens so quando chega uma nova."""
    convs = [c for c in _get("/lol-chat/v1/conversations") or []
             if isinstance(c, dict) and c.get("type") == "chat" and c.get("id")]
    if not convs:
        return {}
    amigos = {}
    for f in _amigos_client():
        for k in (f.get("id"), f.get("pid")):
            if k:
                amigos[k] = f
    eu = _meu_puuid()
    lista = []
    for c in convs:
        f = _amigo_da_conversa(c, amigos)
        ultima = c.get("lastMessage") or {}
        if not f or not f.get("puuid") or not ultima.get("id"):
            continue  # so amigos, e so conversa que ja teve mensagem
        cache = _dms.get(c["id"])
        if not cache or cache[0] != ultima["id"]:
            cache = _dms[c["id"]] = (ultima["id"], _chat(c["id"], eu))
        if not cache[1]:
            continue
        _conv_de[f["puuid"]] = c["id"]
        lista.append((cache[1][-1]["hora"], f, cache[1], c.get("unreadMessageCount") or 0))
    lista.sort(key=lambda x: -x[0])
    return {f["puuid"]: {"nome": f.get("gameName") or "", "tag": f.get("gameTag") or "", "icone": f.get("icon") or 0,
                         "nao_lidas": nao_lidas,
                         "msgs": [{k: m[k] for k in ("id", "texto", "hora", "eu")} for m in msgs if m["tipo"] == "msg"]}
            for _, f, msgs, nao_lidas in lista[:DM_MAX]}


def _dm_lida(puuid):
    """Conversa aberta no celular fica lida no PC tambem. A tela do client marca como lida ao abrir a conversa
    (PUT em conversations/active); aqui faz o mesmo e devolve a ativa de antes, pra janela de chat do PC nao
    mudar. So mexe se o client ainda conta mensagem nao lida."""
    cid = _conv_de.get(puuid) if isinstance(puuid, str) else None
    if not cid:
        return False, "Conversa não encontrada"
    caminho = f"/lol-chat/v1/conversations/{quote(cid)}"
    conv = _get(caminho)
    if not isinstance(conv, dict):
        return False, "LoL fechado"
    if not conv.get("unreadMessageCount"):
        return True, ""
    antes = (_get("/lol-chat/v1/conversations/active") or {}).get("id")
    try:
        r = _lcu("PUT", "/lol-chat/v1/conversations/active", json={"id": cid})
        time.sleep(random.uniform(0.3, 0.6))
        if antes and antes != cid:
            _lcu("PUT", "/lol-chat/v1/conversations/active", json={"id": antes})
        elif not antes:
            _lcu("DELETE", "/lol-chat/v1/conversations/active")
        conv = _get(caminho)
        if isinstance(conv, dict) and conv.get("unreadMessageCount"):
            # o client nao zerou pela ativa: zera direto na conversa
            r = _lcu("PUT", caminho, json={**conv, "unreadMessageCount": 0})
    except requests.RequestException:
        return False, "LoL fechado"
    if r is None or not r.ok:
        _log(f"conversa nao marcada como lida no client ({getattr(r, 'status_code', '-')})")
        return False, "O LoL recusou"
    return True, ""


def _mandar_dm(puuid, texto):
    """Manda mensagem particular pra um amigo, como na janela de chat do client."""
    texto = str(texto or "").strip()[:200]
    if not texto:
        return False, "Mensagem vazia"
    _amg["t"] = 0.0
    f = next((x for x in _amigos_client() if isinstance(puuid, str) and x.get("puuid") == puuid), None)
    if not f:
        return False, "Amigo não encontrado"
    cid = f.get("pid") or f.get("id")
    if not cid:
        return False, "Amigo não encontrado"
    caminho = f"/lol-chat/v1/conversations/{quote(cid)}/messages"
    try:
        r = _lcu("POST", caminho, json={"body": texto, "type": "chat"})
        if r is not None and r.status_code == 404:  # primeira conversa com ele: abre e manda
            _lcu("POST", "/lol-chat/v1/conversations", json={"id": cid, "type": "chat"})
            r = _lcu("POST", caminho, json={"body": texto, "type": "chat"})
    except requests.RequestException:
        r = None
    if r is None:
        return False, "LoL fechado"
    if not r.ok:
        _log(f"mensagem pra amigo recusada pelo client ({r.status_code})")
        return False, "O LoL recusou a mensagem"
    _dms.pop(cid, None)
    _log(f"mensagem mandada pra {ascii_log(f.get('gameName') or 'amigo')}")
    return True, ""


def _criar_sala(fila, quem):
    """Cria a sala no modo escolhido (ou troca o modo da sala atual, se voce for o lider) e convida."""
    if not isinstance(fila, int) or fila <= 0:
        return False, "Modo inválido"
    fase = _get("/lol-gameflow/v1/gameflow-phase")
    if fase is None:
        return False, "LoL fechado"
    if fase not in FASES_SALA:
        return False, "Agora não dá pra criar sala"
    q = next((x for x in _filas_brutas() if x.get("id") == fila), None)
    if not q or q.get("queueAvailability") != "Available":
        return False, "Esse modo não está aberto agora"
    if fase == "Lobby":
        lobby = _get("/lol-lobby/v2/lobby") or {}
        if len(lobby.get("members") or []) > 1 and not (lobby.get("localMember") or {}).get("isLeader"):
            return False, "Só o líder da sala troca o modo"
    tentativas = [{"queueId": fila}]
    if q.get("isCustom"):
        me = _get("/lol-summoner/v1/current-summoner") or {}
        config = {"gameMode": q.get("gameMode"), "mapId": q.get("mapId"), "mutators": {"id": MUTADOR.get(fila, 1)},
                  "spectatorPolicy": "AllAllowed", "teamSize": q.get("numPlayersPerTeam") or 5}
        custom = {"lobbyName": f"Partida de {me.get('gameName') or 'voce'}", "lobbyPassword": "",
                  "configuration": config}
        tentativas = [{"queueId": fila, "isCustom": True, "customGameLobby": custom},
                      {"isCustom": True, "customGameLobby": custom}, {"queueId": fila}]
    r = None
    for corpo in tentativas:
        try:
            r = _lcu("POST", "/lol-lobby/v2/lobby", json=corpo)
        except requests.RequestException:
            r = None
        if r is None or r.ok:
            break
        _log(f"criar sala {fila} recusado ({r.status_code}) com {'+'.join(sorted(corpo))}")
    if r is None:
        return False, "LoL fechado"
    if not r.ok:
        return False, "O LoL recusou esse modo"
    _log(f"sala criada: {ascii_log(q.get('description') or str(fila))} ({fila})")
    if not quem:
        return True, "Sala criada"
    time.sleep(0.6)  # a sala nova demora um pouco pra aceitar convite
    ok, msg = _convidar(quem)
    return True, f"Sala criada. {msg}"


def _convidar(quem):
    """Convida amigos (puuid) pra sala. So quem esta na lista de amigos do client."""
    if isinstance(quem, dict):  # lista gravada no Firebase pode voltar como mapa {0: ..}
        quem = list(quem.values())
    if not isinstance(quem, list) or not quem:
        return False, "Ninguém escolhido"
    _amg["t"] = 0.0
    amigos = {f.get("puuid"): f for f in _amigos_client() if f.get("puuid")}
    alvos = [amigos[p] for p in quem[:20] if isinstance(p, str) and p in amigos]
    if not alvos:
        return False, "Amigo não encontrado"
    if not isinstance(_get("/lol-lobby/v2/lobby"), dict):
        return False, "Você não está numa sala"
    corpo = [{"toSummonerId": f.get("summonerId"), "toPuuid": f["puuid"]} for f in alvos]
    try:
        r = _lcu("POST", "/lol-lobby/v2/lobby/invitations", json=corpo)
    except requests.RequestException:
        r = None
    if r is None:
        return False, "LoL fechado"
    if not r.ok:
        _log(f"convite recusado pelo client ({r.status_code})")
        return False, "O LoL recusou o convite"
    _log(f"convite mandado pra {len(alvos)} amigo(s)")
    return True, "Convite mandado" if len(alvos) == 1 else f"{len(alvos)} convites mandados"


def _regras_posicao(lobby, primeira):
    """Mesmas regras do seletor de posicao da sala no client (rcp-fe-lol-parties): sem segunda posicao com o
    time cheio, com Qualquer na primeira ou com posicao escassa obrigatoria e a primeira escassa; com escassa
    obrigatoria e a primeira comum, a segunda so pode ser escassa. Devolve (segunda_ok, opcoes da segunda)."""
    gc = lobby.get("gameConfig") or {}
    escassas = [p for p in lobby.get("scarcePositions") or [] if p in POSICOES]
    forcar = bool(gc.get("shouldForceScarcePositionSelection"))
    escassa = primeira == "FILL" or primeira in escassas
    cheia = len(lobby.get("members") or []) >= (gc.get("maxTeamSize") or 5)
    if cheia or primeira == "FILL" or (forcar and escassa):
        return False, []
    if forcar and escassas:
        return True, escassas + ["FILL"]
    return True, sorted(POSICOES)


def _posicao_sala(papel, pos):
    """Escolhe a primeira (papel 0) ou a segunda (papel 1) posicao na sala, como o seletor do client: escolher
    a que ja esta no outro lado troca as duas. Mesma rota e corpo da tela (PUT .../position-preferences)."""
    if papel not in (0, 1) or pos not in POSICOES:
        return False, "Posição inválida"
    lobby = _get("/lol-lobby/v2/lobby")
    if not isinstance(lobby, dict) or not lobby.get("members"):
        return False, "Você não está numa sala"
    if not (lobby.get("gameConfig") or {}).get("showPositionSelector"):
        return False, "Esse modo não tem posição"
    eu = lobby.get("localMember") or {}
    p1 = eu.get("firstPositionPreference") or "UNSELECTED"
    p2 = eu.get("secondPositionPreference") or "UNSELECTED"
    if papel == 1:
        ok, opcoes = _regras_posicao(lobby, p1)
        if not ok or pos not in opcoes:
            return False, "Essa posição não dá na segunda"
    n1, n2 = (pos, p2) if papel == 0 else (p1, pos)
    if (n1, n2) == (p1, p2):
        return True, ""
    if pos in (p1, p2):  # ja estava no outro lado: troca as duas (o client faz igual)
        n1, n2 = p2, ("UNSELECTED" if p2 == "FILL" else p1)
    if not _regras_posicao(lobby, n1)[0]:
        n2 = "UNSELECTED"
    _espacar()
    try:
        r = _lcu("PUT", "/lol-lobby/v1/lobby/members/localMember/position-preferences",
                 json={"firstPreference": n1, "secondPreference": n2})
    except requests.RequestException:
        r = None
    _vivo["escrita_sel"] = time.time()
    if r is None:
        return False, "LoL fechado"
    if not r.ok:
        _log(f"posicao recusada pelo client ({r.status_code})")
        return False, "O LoL recusou essa posição"
    _log(f"posicao na sala pelo celular: {n1} / {n2}")
    return True, ""


def _nomes_campeoes():
    try:
        lst, _ = lcu.campeoes()
    except Exception:
        lst = []
    return {c["id"]: c["name"] for c in lst}


def _skins(cid):
    """Skins do seu campeao pro carrossel do celular (como o do client): as que voce tem e as que nao (com
    cadeado), cada uma com os chromas. Lidas uma vez por campeao; o carrossel pode vir vazio logo no lock."""
    if not cid:
        return None
    if _vivo.get("skins", {}).get("campeao") == cid:
        return _vivo["skins"]
    lista = []
    for x in _get("/lol-champ-select/v1/skin-carousel-skins") or []:
        if not isinstance(x, dict) or x.get("championId") != cid:
            continue
        lista.append({
            "id": x.get("id"), "nome": x.get("name") or "", "tem": bool(x.get("unlocked")) and not x.get("disabled"),
            # caminhos do client (/lol-game-data/assets/...): o celular busca no CommunityDragon
            "arte": x.get("splashPath") or "", "mini": x.get("tilePath") or "",
            "chromas": [{"id": c.get("id"), "tem": bool(c.get("unlocked")) and not c.get("disabled"),
                         "cor": (c.get("colors") or [""])[0]}
                        for c in x.get("childSkins") or [] if isinstance(c, dict)]})
    if not lista:
        return None
    _vivo["skins"] = {"campeao": cid, "lista": lista}
    return _vivo["skins"]


def _trocar_skin(sid):
    """Escolhe a skin (ou chroma) pelo celular, igual a clicar no carrossel do client."""
    sk = _vivo.get("skins") or {}
    tem = {x["id"] for x in sk.get("lista") or [] if x["tem"]} | \
        {c["id"] for x in sk.get("lista") or [] for c in x["chromas"] if c["tem"]}
    if not isinstance(sid, int) or sid not in tem:
        return False, "Skin indisponível"
    try:
        r = _lcu("PATCH", "/lol-champ-select/v1/session/my-selection", json={"selectedSkinId": sid})
    except requests.RequestException:
        r = None
    if r is None:
        return False, "LoL fechado"
    if not r.ok:
        _log(f"skin recusada pelo client ({r.status_code})")
        return False, "O LoL recusou essa skin"
    _log(f"skin: {sid}")
    return True, ""


def _arena(fila=None):
    """Arena (gameMode CHERRY): 18 jogadores (6 times de 3, celulas 0-2, 3-5...), ban e pick simultaneos, feitico
    fixo (so inverte D e F), sem runa, troca nem banco. Pelo numero da fila (as que ja vimos) ou pelo gameMode que o gameflow informa."""
    if fila is not None and lcu.fila_arena(fila):
        return True
    q = ((_get("/lol-gameflow/v1/session") or {}).get("gameData") or {}).get("queue") or {}
    return lcu.fila_arena(q.get("id"), q.get("gameMode"))


def _modo_jogo():
    """Modo da partida pros feiticos (o summoner-spells.json diz em que modos cada um existe). A ARAM: Desordem
    usa os do ARAM."""
    q = ((_get("/lol-gameflow/v1/session") or {}).get("gameData") or {}).get("queue") or {}
    if q.get("id") in lcu.FILAS_ARAM or q.get("gameMode") in ("ARAM", "KIWI"):
        return "ARAM"
    return q.get("gameMode") or "CLASSIC"


def _feiticos(modo, atuais=()):
    """Feiticos que da pra escolher no modo (como a grade de feitico do client), com os em uso sempre na lista."""
    try:
        todos = lcu.feiticos()
    except Exception:
        return []
    lst = [f for f in todos if not f.get("modos") or modo in f["modos"] or f["id"] in atuais]
    if not any(modo in (f.get("modos") or []) for f in todos):  # modo que nenhum feitico cita: os do Rift
        lst = [f for f in todos if not f.get("modos") or "CLASSIC" in f["modos"] or f["id"] in atuais]
    return [{"id": f["id"], "nome": f.get("nome") or "", "icone": f.get("icone") or ""}
            for f in sorted(lst, key=lambda f: (f.get("nome") or "").lower())]


ARENA_FEITICOS = (2201, 2202)  # Fuga e Flash: o par fixo da Arena, o client so deixa trocar de lado (D e F)


def _feiticos_arena():
    """Os feiticos da Arena pro celular: so o par fixo (a folha de feitico mostra os dois e troca de lado)."""
    try:
        por_id = {f["id"]: f for f in lcu.feiticos_arena()}
    except Exception:
        por_id = {}
    return [{"id": i, "nome": (por_id.get(i) or {}).get("nome") or "", "icone": (por_id.get(i) or {}).get("icone") or ""}
            for i in ARENA_FEITICOS]


GOLPEAR = 11  # so na selva: com posicao definida (ranqueada, escolha alternada) fora da jungle nao deixa escolher


def _trocar_feitico(slot, fid):
    """Troca o feitico D (slot 0) ou F (slot 1), como na grade de feitico do client: escolher o que ja esta no
    outro lado inverte os dois."""
    if slot not in (0, 1) or not isinstance(fid, int):
        return False, "Feitiço inválido"
    s = _get("/lol-champ-select/v1/session")
    if not isinstance(s, dict) or not s.get("myTeam"):
        return False, "Você não está na seleção"
    eu = next((m for m in s["myTeam"] if m.get("cellId") == s.get("localPlayerCellId")), {})
    par = [eu.get("spell1Id") or 0, eu.get("spell2Id") or 0]
    if _arena(s.get("queueId")):
        # Arena: o par e sempre Fuga + Flash, so da pra inverter D e F (escolher o do outro lado)
        if fid not in ARENA_FEITICOS or set(par) != set(ARENA_FEITICOS):
            return False, "Na Arena só dá pra trocar a ordem dos feitiços"
    elif fid not in {f["id"] for f in _feiticos(_modo_jogo(), par)}:
        return False, "Esse feitiço não vale nesse modo"
    pos = (eu.get("assignedPosition") or "").lower()
    if fid == GOLPEAR and fid not in par and pos and pos != "jungle":
        return False, "Golpear só na selva"
    if par[slot] == fid:
        return True, ""
    novo = list(par)
    if par[1 - slot] == fid:
        novo[1 - slot] = par[slot]
    novo[slot] = fid
    _espacar()
    try:
        r = _lcu("PATCH", "/lol-champ-select/v1/session/my-selection", json={"spell1Id": novo[0], "spell2Id": novo[1]})
    except requests.RequestException:
        r = None
    _vivo["escrita_sel"] = time.time()
    if r is None:
        return False, "LoL fechado"
    if not r.ok:
        _log(f"feitico recusado pelo client ({r.status_code})")
        return False, "O LoL recusou esse feitiço"
    _log(f"feiticos pelo celular: {novo[0]} + {novo[1]}")
    return True, ""


PAGINA_NOME_MAX = 25  # o client corta o nome da pagina de runas por volta disso


def _arvore():
    """Arvores de runas pro editor do celular (~20 KB). Lidas uma vez: so mudam com patch."""
    if _vivo.get("arvore"):
        return _vivo["arvore"]
    try:
        d = lcu.runas_dados()
    except Exception:
        return None
    if not d.get("estilos"):
        return None
    arv = {"estilos": d["estilos"], "perks": d["perks"]}
    if d.get("conectado"):  # do cache (client fechado) le de novo na proxima: pode ter patch novo
        _vivo["arvore"] = arv
    return arv


def _runas():
    """Suas paginas de runas pro celular (escolher e editar), na ordem do client."""
    pages = _get("/lol-perks/v1/pages")
    if not isinstance(pages, list):
        return None
    if _vivo.get("inv", (None,))[0] != len(pages):  # o espaco so muda quando cria ou apaga pagina
        _vivo["inv"] = (len(pages), _get("/lol-perks/v1/inventory") or {})
    lista = []
    for p in sorted((x for x in pages if isinstance(x, dict) and x.get("id")), key=lambda x: x.get("order") or 0):
        lista.append({"id": p["id"], "nome": p.get("name") or "", "prim": p.get("primaryStyleId") or 0,
                      "sec": p.get("subStyleId") or 0, "perks": [x for x in p.get("selectedPerkIds") or []
                                                                 if isinstance(x, int)],
                      "atual": bool(p.get("current")), "valida": p.get("isValid") is not False,
                      "editavel": p.get("isEditable", True) is not False and not p.get("isTemporary")})
    return {"paginas": lista, "pode_criar": bool(_vivo["inv"][1].get("canAddCustomPage"))}


def _runas_certas(prim, sec, perks):
    """Confere se a pagina e uma que da pra montar no client: pedra e 3 runas da principal (uma por linha),
    2 da secundaria em linhas diferentes e 3 fragmentos. Nada que a tela do client nao deixe fazer."""
    if not lcu.runas_validas({"primaria": prim, "secundaria": sec, "perks": perks}):
        return False
    estilos = {s["id"]: s for s in (_arvore() or {}).get("estilos") or []}
    p, s = estilos.get(prim), estilos.get(sec)
    if not p or not s or (p.get("subs") and sec not in p["subs"]):
        return False
    normais = lambda e: [sl["perks"] for sl in e["slots"] if sl["tipo"] != "kStatMod"]
    frags = [sl["perks"] for sl in p["slots"] if sl["tipo"] == "kStatMod"]
    if len(normais(p)) < 4 or len(frags) != 3:
        return False
    if any(perks[i] not in normais(p)[i] for i in range(4)):
        return False
    linhas = [next((n for n, sl in enumerate(normais(s)[1:]) if x in sl), None) for x in perks[4:6]]
    if None in linhas or linhas[0] == linhas[1]:
        return False
    return all(perks[6 + i] in frags[i] for i in range(3))


def _usar_pagina(pid):
    """Troca a pagina em uso, igual escolher na lista de paginas da selecao do client."""
    pages = _get("/lol-perks/v1/pages")
    if not isinstance(pages, list):
        return False, "LoL fechado"
    p = next((x for x in pages if isinstance(x, dict) and x.get("id") == pid), None)
    if not p:
        return False, "Página não encontrada"
    if p.get("current"):
        return True, ""
    try:
        r = _lcu("PUT", "/lol-perks/v1/currentpage", json=pid)
    except requests.RequestException:
        r = None
    if r is None:
        return False, "LoL fechado"
    if not r.ok:
        _log(f"pagina de runa recusada pelo client ({r.status_code})")
        return False, "O LoL recusou essa página"
    _log(f"runas: pagina '{ascii_log(p.get('name') or '')}'")
    return True, ""


def _salvar_pagina(pid, nome, prim, sec, perks):
    """Salva a pagina editada no celular (pid 0 = pagina nova) e deixa ela em uso. Como no client: salvar e uma
    gravacao; se ela nao ficou em uso, escolhe ela um instante depois (nunca as duas juntas)."""
    if not isinstance(perks, list) or not _runas_certas(prim, sec, perks):
        return False, "Página incompleta"
    nome = (nome if isinstance(nome, str) else "").strip()[:PAGINA_NOME_MAX]
    pages = _get("/lol-perks/v1/pages")
    if not isinstance(pages, list):
        return False, "LoL fechado"
    corpo = {"name": nome or "Página nova", "primaryStyleId": prim, "subStyleId": sec,
             "selectedPerkIds": perks, "current": True}
    try:
        if pid:
            p = next((x for x in pages if isinstance(x, dict) and x.get("id") == pid), None)
            if not p:
                return False, "Página não encontrada"
            if p.get("isEditable", True) is False or p.get("isTemporary"):
                return False, "Essa página não dá pra editar"
            r = _lcu("PUT", f"/lol-perks/v1/pages/{pid}", json={**p, **corpo})
        else:
            if not (_get("/lol-perks/v1/inventory") or {}).get("canAddCustomPage"):
                return False, "Sem espaço pra página nova"
            r = _lcu("POST", "/lol-perks/v1/pages", json=corpo)
        if r is None:
            return False, "LoL fechado"
        if not r.ok:
            _log(f"pagina de runa recusada pelo client ({r.status_code})")
            return False, "O LoL recusou a página"
        if not pid:
            pid = ((r.json() if r.content else {}) or {}).get("id")
        if pid and (_get("/lol-perks/v1/currentpage") or {}).get("id") != pid:
            time.sleep(random.uniform(0.4, 0.9))
            _lcu("PUT", "/lol-perks/v1/currentpage", json=pid)
    except (requests.RequestException, ValueError):
        return False, "LoL fechado"
    _log(f"runas: pagina '{ascii_log(corpo['name'])}' salva pelo celular")
    return True, "Página salva"


def _grade(sid):
    """A grade do client (/all-grid-champions): maestria, posicoes favoritas, se tem o campeao. Lida uma vez por
    selecao; a lista de pick/ban volta a ser lida enquanto vier vazia (no comeco da selecao pode vir [] ou [-1],
    que e "sem restricao")."""
    if _listas["sessao"] != sid:
        _listas.update(sessao=sid, pick=[], ban=[], grade=[])
        pref = (_get("/lol-settings/v2/account/LCUPreferences/lol-champ-select") or {}).get("data") or {}
        chave = str(pref.get("championFilterPreferenceKey") or "").lower()
        _listas["ordem"] = "maestria" if "mast" in chave else "favorito" if "fav" in chave else "nome"
    # so campeoes de verdade: o client lista alguns duas vezes (a base e uma variante de modo com ID 60000+ e
    # arte antiga). A lista do lcu.campeoes (menor ID por nome) e a referencia: o resto fica de fora
    validos = set(_nomes_campeoes())
    if not _listas["grade"]:
        g = _get("/lol-champ-select/v1/all-grid-champions") or []
        _listas["grade"] = [
            {"id": c["id"], "m": int(c.get("masteryPoints") or 0),
             "f": [str(x).lower() for x in c.get("positionsFavorited") or []],
             "p": bool(c.get("owned") or c.get("freeToPlay") or c.get("freeToPlayForQueue") or c.get("rented"))
             and not c.get("disabled")}
            for c in g if isinstance(c, dict) and c.get("id") in validos]
    for chave, caminho in (("pick", "pickable-champion-ids"), ("ban", "bannable-champion-ids")):
        if not _listas[chave]:
            _listas[chave] = [c for c in _get(f"/lol-champ-select/v1/{caminho}") or [] if c in validos]
    # sem restricao do client: pick = os que voce tem (grade), ban = todos
    if not _listas["pick"] and _listas["grade"]:
        _listas["pick"] = [c["id"] for c in _listas["grade"] if c["p"]]
    if not _listas["ban"] and _listas["grade"]:
        _listas["ban"] = [c["id"] for c in _listas["grade"]]


def selecao():
    """Retrato da selecao de campeoes: times, bans, vez de quem, prazo e chat (None fora da selecao)."""
    s = _get("/lol-champ-select/v1/session")
    if not isinstance(s, dict) or not s.get("myTeam"):
        return None
    eu = s.get("localPlayerCellId")
    acoes = [a for grupo in s.get("actions") or [] for a in grupo]
    # em personalizada o ban ja aparece em andamento no planejamento: ali ninguem bane, so declara intencao
    planejamento = (s.get("timer") or {}).get("phase") == "PLANNING"
    # ARAM Desordem: o pick "em andamento" do comeco e o sorteio do client, ninguem escolhe. Sem isso o app
    # mostrava a grade, vibrava e fazia o tique de sua vez a toa
    desordem = s.get("queueId") in lcu.FILAS_ARAM
    arena = (not desordem) and _arena(s.get("queueId"))
    vez = {} if planejamento or desordem else {a.get("actorCellId"): a for a in acoes
                                   if a.get("isInProgress") and not a.get("completed")}
    travou = {a.get("actorCellId") for a in acoes if a.get("type") == "pick" and a.get("completed")}
    usados = set()
    # troca com aliado (campeao, posicao e ordem de pick): uma de cada por aliado, o id muda a cada mudanca no
    # time e so uma anda por vez. Ordem so vale como na tela do client: planejamento ou picks, ninguem travado
    # Arena: as listas de troca vem sempre INVALID (a fila nao tem troca): nada pro celular mostrar
    trocas = {g: ([] if arena else _lista_trocas(s, g)) for g in GRUPOS_TROCA}
    if not _ordem_ok(s, travou):
        trocas["ordem"] = [t for t in trocas["ordem"] if t["estado"] in TROCA_PENDENTE]
    pendente = any(t["estado"] in TROCA_PENDENTE for ts in trocas.values() for t in ts)
    ordem = {}  # cell -> em que lugar o aliado escolhe (1 = primeiro), pra mostrar o que muda na troca de ordem
    for a in ([] if arena else acoes):  # Arena: todos escolhem juntos, nao tem ordem
        if a.get("type") == "pick" and a.get("isAllyAction") and a.get("actorCellId") not in ordem:
            ordem[a.get("actorCellId")] = len(ordem) + 1

    # Arena: o ban de cada um (todas as acoes de ban sao do "meu time", uma por jogador)
    bans_cell = {a.get("actorCellId"): a for a in acoes if arena and a.get("type") == "ban"}
    picks_cell = {a.get("actorCellId"): a for a in acoes if arena and a.get("type") == "pick"}

    def slot(m, aliado):
        cell = m.get("cellId")
        acao = vez.get(cell)
        cid = m.get("championId") or 0
        pc = picks_cell.get(cell) or {}
        # Arena: o client manda -3 no pick travado de quem ainda nao revelou o campeao (a finalizacao)
        oculto = cid < 0 or (bool(pc.get("completed")) and (pc.get("championId") or 0) < 0)
        cid = max(cid, 0)
        if not cid and acao and acao.get("type") == "pick":
            cid = max(acao.get("championId") or 0, 0)  # hover durante a vez
        intencao = 0 if cid else max(m.get("championPickIntent") or 0, 0)
        usados.update(x for x in (cid, intencao) if x)
        d = {"cell": cell, "campeao": cid, "intencao": intencao, "travado": cell in travou,
             "pos": m.get("assignedPosition") or "", "vez": (acao or {}).get("type") or "", "eu": cell == eu}
        if oculto:
            d["oculto"] = True
        if arena:
            b = bans_cell.get(cell)
            if b:
                d["ban"] = max(b.get("championId") or 0, 0)  # 0 = ainda nao baniu (ou pulou)
                d["ban_travado"] = bool(b.get("completed"))
        if aliado:
            d.update(nome=m.get("gameName") or "", tag=m.get("tagLine") or "")
            if cell in ordem:
                d["ordem"] = ordem[cell]
            for g, (_, _, chave, _) in GRUPOS_TROCA.items():
                estado = next((t["estado"] for t in trocas[g] if t["cell"] == cell), None)
                if cell != eu and estado:
                    d[chave] = estado  # AVAILABLE = da pra pedir; SENT, RECEIVED, BUSY, INVALID
        return d

    meu = [slot(m, True) for m in s.get("myTeam") or []]
    deles = [slot(m, False) for m in s.get("theirTeam") or []]
    bans = {"meu": [c for c in (s.get("bans") or {}).get("myTeamBans") or [] if c > 0],  # -1 = nao baniu
            "deles": [c for c in (s.get("bans") or {}).get("theirTeamBans") or [] if c > 0]}
    for a in acoes:
        if a.get("type") == "ban" and a.get("completed") and (a.get("championId") or 0) > 0:  # -1 = pulou o ban
            lado = "meu" if a.get("isAllyAction") else "deles"
            if a["championId"] not in bans[lado]:
                bans[lado].append(a["championId"])
    usados.update(bans["meu"] + bans["deles"])
    banco = [b.get("championId") for b in s.get("benchChampions") or [] if b.get("championId")]
    usados.update(banco)
    t = s.get("timer") or {}
    prazo = None
    if isinstance(t.get("internalNowInEpochMs"), (int, float)) and isinstance(t.get("adjustedTimeLeftInPhase"), (int, float)):
        # internalNowInEpochMs e a hora (no relogio do PC) em que o client mediu o tempo: + offset = hora do
        # servidor (a do celular). Calculado uma vez por leitura do client: o offset muda a cada gravacao e
        # mexia no prazo em alguns ms, o que regravava a selecao e fazia a barra do celular recomecar
        chave = (t["internalNowInEpochMs"], t["adjustedTimeLeftInPhase"])
        if _vivo.get("prazo", (None,))[0] != chave:
            _vivo["prazo"] = (chave, int(chave[0] + chave[1] + (_vivo["offset"] or 0)))
        prazo = _vivo["prazo"][1]
    minha = vez.get(eu)
    _grade(s.get("gameId") or s.get("id"))
    usados.update(_listas["pick"], _listas["ban"])
    # o client segue listando como pickable o campeao que alguem baniu (Arena): o app nao oferece
    banidos_ja = lcu.banidos_da_sessao(s)
    meu_pick = next((a for a in acoes if a.get("actorCellId") == eu and a.get("type") == "pick"
                     and not a.get("completed")), None)
    # ARAM Desordem: as 2 ou 3 cartas que o client mostra no comeco (a 3a e a carta da sorte), enquanto voce
    # nao escolheu. Leitura local, so nessa hora
    cartas = []
    if desordem and meu_pick and t.get("phase") == "BAN_PICK":
        sub = _get("/lol-lobby-team-builder/champ-select/v1/subset-champion-list")
        cartas = [c for c in sub if isinstance(c, int) and c > 0] if isinstance(sub, list) else []
    usados.update(cartas)
    nomes = _nomes_campeoes()
    puuid = next((m.get("puuid") for m in s.get("myTeam") or [] if m.get("cellId") == eu), None)
    if arena and isinstance(eu, int):
        # Arena: seu time de 3 sao as 3 celulas seguidas com a sua. A tela de carregamento nao diz quem e (o
        # teamParticipantId so junta quem entrou na fila junto), entao guarda aqui
        _vivo["arena_time"] = (s.get("gameId"), {m.get("puuid") for m in s.get("myTeam") or []
                                                 if m.get("puuid") and (m.get("cellId") or 0) // 3 == eu // 3})
    eu_m = next((m for m in s.get("myTeam") or [] if m.get("cellId") == eu), {})
    tem_pick = any(a.get("actorCellId") == eu and a.get("type") == "pick" for a in acoes)
    meu_campeao = (eu_m.get("championId") or 0) if (eu in travou or not tem_pick) else 0
    skin_atual = eu_m.get("selectedSkinId") or 0
    cid_chat = _id_conversa((s.get("chatDetails") or {}).get("multiUserChatId"))
    return {"fase": t.get("phase") or "", "prazo": prazo, "duracao": t.get("totalTimeInPhase") or 0,
            "fila": s.get("queueId") or 0, "arena": arena, "pode_sair": bool(s.get("showQuitButton")),
            "infinito": bool(t.get("isInfinite")),
            "minha_vez": (minha or {}).get("type") or "", "pick_pendente": bool(meu_pick) and not desordem,
            # campeao definido (travado, ou ARAM sem pick): o celular mostra as skins dele
            "skins_de": meu_campeao, "skin": skin_atual,
            "pickaveis": [c for c in _listas["pick"] if c not in banidos_ja], "baniveis": _listas["ban"], "minha_pos": next((m["pos"] for m in meu if m["eu"]), ""), "meu": meu, "deles": deles, "bans": bans, "banco": banco,
            "cartas": cartas,
            "trocas": trocas["troca"], "trocas_pos": trocas["pos"], "trocas_ordem": trocas["ordem"],
            "feiticos": [eu_m.get("spell1Id") or 0, eu_m.get("spell2Id") or 0],
            # pegar do banco agora (como clicar nele no client): sem troca com aliado no meio
            "banco_ok": bool(banco) and not pendente and t.get("phase") in FASES_BANCO,
            "nomes": {str(c): nomes.get(c, "") for c in usados},
            "chat": _chat(cid_chat, puuid), "chat_ok": bool(cid_chat)}


HOJE_MAX = 20  # partidas de hoje que vao pro celular (o resumo conta todas)
_hoje_visto = {"marca": None, "valor": None}


def hoje():
    """Resumo do dia pro celular (aba Hoje): o mesmo cache que o hoje.py grava depois de cada partida.
    So relido quando o arquivo muda ou o dia vira (5h); sem partida hoje, None."""
    import hoje as dia
    try:
        mt = dia.HOJE_CACHE.stat().st_mtime_ns
    except OSError:
        mt = None
    marca = (mt, str(dia.hoje()))
    if marca == _hoje_visto["marca"]:
        return _hoje_visto["valor"]
    jogos = dia.jogos_de_hoje_cache()
    valor = None
    if jogos:
        nomes = {}
        try:
            nomes = {c["id"]: (c["name"],) for c in lcu.campeoes()[0]}
        except Exception:
            pass
        valor = {
            "resumo": dia.resumo(jogos, nomes),
            "jogos": [{"campeao": j.get("campeao") or 0, "vitoria": bool(j.get("vitoria")),
                       "remake": bool(j.get("remake")), "k": j.get("k", 0), "d": j.get("d", 0), "a": j.get("a", 0),
                       "cs": j.get("cs", 0), "duracao": j.get("duracao", 0), "quando": j.get("quando") or 0,
                       "fila": j.get("fila") or 0, "modo": j.get("modo") or ""}
                      for j in jogos[:HOJE_MAX]],
            "nomes": {str(j.get("campeao")): nomes.get(j.get("campeao"), ("",))[0]
                      for j in jogos[:HOJE_MAX] if j.get("campeao")},
        }
    _hoje_visto.update(marca=marca, valor=valor)
    return valor


ARQ_RIOT = CACHE / "riot_id.txt"  # ultimo Riot ID visto: o celular mostra a conta mesmo com o LoL fechado
_rid = {"valor": None, "lido": 0.0}


def _riot_id_logado():
    if _rid["valor"] is None:
        try:
            _rid["valor"] = ARQ_RIOT.read_text(encoding="utf-8").strip() or ""
        except OSError:
            _rid["valor"] = ""
    return _rid["valor"] or None


def _lembrar_riot_id():
    """Le o Riot ID logado no client (no maximo a cada 60s) e guarda o ultimo visto."""
    if time.time() - _rid["lido"] < 60:
        return
    _rid["lido"] = time.time()
    eu = _get("/lol-summoner/v1/current-summoner") or {}
    if not eu.get("gameName"):
        return
    rid = f"{eu['gameName']}#{eu.get('tagLine') or ''}"
    if rid != _riot_id_logado():
        _rid["valor"] = rid
        try:
            CACHE.mkdir(exist_ok=True)
            ARQ_RIOT.write_text(rid, encoding="utf-8")
        except OSError:
            pass


def _quem():
    """Nome do PC e o Riot ID logado (ou o ultimo visto): o celular lista os PCs e as contas do LoL de cada um
    por isso."""
    e = {}
    nome = (os.environ.get("COMPUTERNAME") or "").strip()
    if nome:
        e["pc_nome"] = nome[:40]
    rid = _riot_id_logado()
    if rid:
        e["conta_lol"] = rid[:40]
    return e


def estado(antes=None):
    """Retrato do client pro celular. Funcao sem efeito no client (so le)."""
    antes = antes or {}
    if _vivo["fechando"]:  # nem pergunta pro client: ele esta morrendo e cada leitura segura ate 3s
        e = {"fase": "Fechado", "fechando": True, **_quem()}
        h = hoje()
        if h:
            e["hoje"] = h
        return e
    fase = _get("/lol-gameflow/v1/gameflow-phase")
    e = {"fase": fase or "Fechado", **_quem()}
    h = hoje()
    if h:
        e["hoje"] = h  # aba Hoje do app: com o LoL fechado tambem
    if not fase:
        if time.time() - _vivo["abrindo"] < ABRINDO_POR:
            e["abrindo"] = True  # pedido pelo celular: o app mostra "Abrindo o LoL" ate o client subir
            ab = _abertura_estado()
            if ab:
                e["abertura"] = ab  # etapas e tempo esperado de cada uma: o app desenha a barra com isso
        elif time.time() - _vivo["abriu"] < 30 and _lol_rodando():
            e["abrindo"] = True  # client acabou de subir e a LCU piscou: nao mostra "LoL fechado" no meio
        elif _riot_rodando():
            e["riot"] = True  # so o Riot Client aberto: o celular oferece fechar ele
        if _vivo.get("fim_jogo") and time.time() - _vivo.get("fim_em", 0) < FIM_SEGURA:
            # o client cai por uns segundos quando a partida acaba: o celular segue na vitoria/derrota
            f = fim("InProgress", {})
            if f:
                e["fim"] = f
        return e
    if _vivo["abrindo"]:
        _vivo["abriu"] = time.time()
    _vivo["abrindo"] = 0.0
    agora = agora_ms()
    gf = _get("/lol-gameflow/v1/session") or {}
    fila = (gf.get("gameData") or {}).get("queue") or {}
    if fila.get("id"):
        e["fila_nome"] = fila.get("description") or fila.get("name") or ""
    if fase in FASES_SALA:
        e["filas"] = filas_sala()
    # amigos online em qualquer fase: o celular manda mensagem pra eles mesmo na fila ou em partida
    e["amigos"] = amigos_online()
    dm = conversas()
    if dm:
        e["conversas"] = dm
    if fase in ("Lobby", "Matchmaking"):
        sl = sala()
        if sl:
            e["sala"] = sl
    if fase == "ChampSelect":
        sel = selecao()
        if sel:
            e["selecao"] = sel
            # a grade (~11 KB) fica fora da selecao: nao muda durante ela e so vai uma vez
            e["grade"] = {"campeoes": _listas["grade"], "ordem": _listas["ordem"]}
            # feiticos que valem no modo (~1 KB, uma vez por selecao como a grade)
            # Arena: o par e fixo (Fuga + Flash), so da pra inverter D e F: a lista tem so os dois
            if sel.get("arena"):
                if _vivo.get("feiticos_sel") != ("arena", sel.get("fila")):
                    _vivo["feiticos_lista"] = _feiticos_arena()
                    _vivo["feiticos_sel"] = ("arena", sel.get("fila"))
            elif _vivo.get("feiticos_sel") != sel.get("fila"):
                _vivo["feiticos_lista"] = _feiticos(_modo_jogo(), sel["feiticos"])
                _vivo["feiticos_sel"] = sel.get("fila") if _vivo["feiticos_lista"] else None
            if _vivo.get("feiticos_lista"):
                e["feiticos"] = _vivo["feiticos_lista"]
            sk = _skins(sel.get("skins_de") or 0)
            if sk:
                e["skins"] = sk
            # ARAM Desordem nao tem runa: sem runas o app esconde o botao
            # (a Arena tambem nao: aumentos no lugar das runas)
            rn, arv = (None, None) if sel.get("fila") in lcu.FILAS_ARAM or sel.get("arena") else (_runas(), _arvore())
            if rn and arv:
                e["runas"] = rn
                # as arvores (~20 KB) nao mudam: como a grade, so vao uma vez por selecao
                e["runas_arvore"] = arv
    if fase in ("Matchmaking", "ReadyCheck"):
        s = _get("/lol-matchmaking/v1/search") or {}
        tiq = s.get("timeInQueue")
        if isinstance(tiq, (int, float)):
            inicio = int(agora - tiq * 1000)
            e["fila_inicio"] = _estavel(antes.get("fila_inicio"), inicio)
        if isinstance(s.get("estimatedQueueTime"), (int, float)):
            e["fila_estimado"] = int(s["estimatedQueueTime"])
        rc = s.get("readyCheck") or {}
        if fase == "ReadyCheck" or rc.get("state") == "InProgress":
            timer = rc.get("timer")
            achou = int(agora - timer * 1000) if isinstance(timer, (int, float)) else (antes.get("partida") or {}).get("inicio")
            e["partida"] = {"resposta": rc.get("playerResponse") or "None", "estado": rc.get("state") or "",
                            "inicio": _estavel((antes.get("partida") or {}).get("inicio"), achou)}
    if fase in FASES_JOGO:
        e["jogo"] = jogo(antes.get("jogo"))
        if e["jogo"].get("carregando"):
            cr = carregamento(gf)
            if cr:
                e["carregamento"] = cr
        if e["jogo"].get("resultado"):
            _vivo["fim_jogo"] = e["jogo"]
            _vivo["fim_em"] = time.time()
    elif fase not in FASES_FIM:
        _vivo["fim_jogo"] = None
        _vivo["eog"] = None
    if fase in FASES_JOGO + FASES_FIM:
        f = fim(fase, gf)
        if f:
            e["fim"] = f
    return e


# ---------------- partida (Live Client Data) ----------------
# API oficial que o proprio jogo abre no PC pra apps como Blitz e Porofessor: so leitura, so local
# (127.0.0.1:2999), nada vai pro servidor da Riot. Nunca escrever nada aqui.

FASES_JOGO = ("GameStart", "InProgress", "Reconnect")
FASES_FIM = ("WaitingForStats", "PreEndOfGame", "EndOfGame")
FIM_SEGURA = 60  # client caido logo depois do fim da partida ainda mostra o resultado por ate 60s
REMAKE_S = 300  # como no historico do painel: menos de 5 min conta como remake
JOGO_URL = "https://127.0.0.1:2999/liveclientdata/allgamedata"
EVENTOS_MAX = 6
# evento do jogo -> tipo que o celular mostra
OBJETIVOS = {"FirstBlood": "primeiro_abate", "DragonKill": "dragao", "HeraldKill": "arauto", "BaronKill": "barao",
             "HordeKill": "vastilarvas", "AtakhanKill": "atakhan", "TurretKilled": "torre", "InhibKilled": "inibidor",
             "Ace": "ace"}


# ---------------- tela de carregamento ----------------
# A API do jogo so responde depois do carregamento: os 10 jogadores vem do client (gameflow/session), que ja
# sabe campeao, skin e feiticos de cada um. O elo e GET no client (o mesmo de abrir o perfil de alguem).

FILA_ELO = {420: "RANKED_SOLO_5x5", 440: "RANKED_FLEX_SR"}  # o resto mostra o Solo/Duo
ORDEM_POS = {"TOP": 0, "JUNGLE": 1, "MIDDLE": 2, "BOTTOM": 3, "UTILITY": 4}  # ordem da tela de carregamento
_carga = {"jogo": None, "times": None, "elos": {}, "buscando": False, "arena": False}
_jogo_capt = {"jogo": None, "etapas": set()}


def _skin_do_campeao(cid, indice):
    """Arte de carregamento e splash da skin (chroma usa a da skin dona dele), pelo json do campeao."""
    info, _ = lcu.fixo(f"/lol-game-data/assets/v1/champions/{cid}.json")
    skins = (info or {}).get("skins") or [] if isinstance(info, dict) else []
    sid = cid * 1000 + (indice or 0)
    for s in skins:
        if s.get("id") == sid or any(c.get("id") == sid for c in s.get("chromas") or []):
            return s
    return next((s for s in skins if s.get("isBase")), None) or {}


def _buscar_elos(puuids, fila):
    """Elo de cada jogador, um por vez e espacado (cada GET vira pedido do client pro servidor)."""
    chave = FILA_ELO.get(fila, "RANKED_SOLO_5x5")
    try:
        for p in puuids:
            if p in _carga["elos"]:
                continue
            r = _get(f"/lol-ranked/v1/ranked-stats/{p}") or {}
            q = (r.get("queueMap") or {}).get(chave) or {}
            tier = q.get("tier") or ""
            _carga["elos"][p] = {"tier": tier, "div": q.get("division") or ""} \
                if tier and tier not in ("NONE", "UNRANKED") else None
            time.sleep(random.uniform(0.3, 0.7))
    finally:
        _carga["buscando"] = False


def _jogador(x, sel, feit, nomes, eu):
    cid = x.get("championId") or sel.get("championId") or 0
    if not cid:
        return None
    pid = x.get("puuid") or ""
    nome, tag = x.get("gameName") or "", x.get("tagLine") or ""
    if not nome and pid:
        nome, tag = _riot_id(pid)
    if not nome:
        nome = x.get("summonerName") or ""  # bot ou client sem Riot ID: o nome que vier
    sk = _skin_do_campeao(cid, sel.get("selectedSkinIndex", x.get("lastSelectedSkinIndex")))
    j = {"campeao": cid, "nome_campeao": nomes.get(cid, ""), "nome": nome, "tag": tag,
         "tela": sk.get("loadScreenPath") or "", "arte": sk.get("splashPath") or "",
         "feiticos": [feit.get(sel.get(k)) or "" for k in ("spell1Id", "spell2Id")]}
    if sk and not sk.get("isBase") and sk.get("name"):
        j["skin"] = sk["name"]
    if pid and pid == eu:
        j["eu"] = True
    if pid:
        j["puuid"] = pid
    return j


def _times_arena(um, eu, gid):
    """Arena: puuid -> numero do time (0 = o seu) pros que a tela de carregamento deixa saber. O seu time vem da
    selecao (3 celulas seguidas) ou, sem ela, de quem entrou na fila com voce. Os outros so quando um grupo de 3
    divide o teamParticipantId (premade de 3: so pode ser um time); o resto fica sem time."""
    tp = {x.get("puuid"): x.get("teamParticipantId") for x in um if x.get("puuid")}
    guardado = _vivo.get("arena_time") or (None, set())
    meu = {p for p in guardado[1] if p in tp} if guardado[0] == gid else set()
    if eu in tp and (not meu or eu not in meu):
        meu = {p for p, v in tp.items() if v == tp[eu] and v is not None} | {eu}
    saida = {p: 0 for p in meu}
    resto = {}
    for p, v in tp.items():
        if p not in saida and v is not None:
            resto.setdefault(v, []).append(p)
    n = 1
    for v, ps in resto.items():
        if len(ps) == 3:
            saida.update({p: n for p in ps})
            n += 1
    return saida


def _fora_dos_times(sels, jogadores):
    """Selecoes (com o indice) de quem nao esta em nenhum time do gameflow."""
    pids = {x.get("puuid") for x in jogadores if x.get("puuid")}
    internos = {x.get("summonerInternalName") for x in jogadores if x.get("summonerInternalName")}
    return [(i, s) for i, s in enumerate(sels)
            if s.get("championId") and not (s.get("puuid") and s["puuid"] in pids)
            and not (s.get("summonerInternalName") and s["summonerInternalName"] in internos)
            and (s.get("puuid") or s.get("summonerInternalName"))]


def carregamento(gf):
    """Os dois times como na tela de carregamento do jogo: seu time primeiro. So le."""
    gd = (gf or {}).get("gameData") or {}
    gid = gd.get("gameId")
    if not gid:
        return None
    q = gd.get("queue") or {}
    arena = lcu.fila_arena(q.get("id"), q.get("gameMode"))
    if _carga["jogo"] != gid or not _carga["times"]:
        eu = _meu_puuid()
        um = [x for x in gd.get("teamOne") or [] if isinstance(x, dict)]
        dois = [x for x in gd.get("teamTwo") or [] if isinstance(x, dict)]
        if not um and not dois:
            return None
        sels = [s for s in gd.get("playerChampionSelections") or [] if isinstance(s, dict)]
        if arena:
            # Arena: os 18 jogadores estao no teamOne e nas playerChampionSelections. O teamTwo vem com 4 ou 5
            # nomes que nao estao nas selecoes (visto em partidas reais): fica de fora. O teamParticipantId nao agrupa
            # em times de 3 de forma que se confie: sem grupos, so a lista (suposicao a conferir)
            pids = {x.get("puuid") for x in sels if x.get("puuid")}
            um = [x for x in um if x.get("puuid") in pids]
            dois = []

        def sel_de(x):
            return next((s for s in sels if (x.get("puuid") and s.get("puuid") == x.get("puuid"))
                         or (x.get("summonerInternalName") and
                             s.get("summonerInternalName") == x.get("summonerInternalName"))), {})

        # O client as vezes deixa alguem fora do teamOne/teamTwo (Ranqueada Flex: inimigo com 4), mas ele
        # continua nas playerChampionSelections, que vem com o teamOne inteiro primeiro e o teamTwo depois
        faltando = _fora_dos_times(sels, um + dois)
        if arena:  # so ha uma lista: quem faltou no teamOne entra nela
            um += [{"puuid": s.get("puuid") or "", "championId": s.get("championId"),
                    "summonerInternalName": s.get("summonerInternalName") or ""} for _, s in faltando]
            faltando = []
        for i, s in faltando:
            meio = len(sels) // 2
            time_ = um if i < meio else dois
            if len(time_) >= meio:  # a metade nao bate: vai pro time menor
                time_ = um if len(um) <= len(dois) else dois
            usadas = {(x.get("selectedPosition") or "").upper() for x in time_}
            livre = next((p for p in ORDEM_POS if p not in usadas), "") if usadas & set(ORDEM_POS) else ""
            time_.append({"puuid": s.get("puuid") or "", "championId": s.get("championId"),
                          "summonerInternalName": s.get("summonerInternalName") or "",
                          "selectedPosition": livre})  # a posicao que sobrou no time dele

        try:
            feit = {f["id"]: f.get("icone") or "" for f in lcu.feiticos()}
        except Exception:
            feit = {}
        nomes = _nomes_campeoes()
        for t in (um, dois):  # top, jungle, mid, adc, sup; sem posicao (blind, ARAM) fica na ordem do client
            t.sort(key=lambda x: ORDEM_POS.get((x.get("selectedPosition") or "").upper(), len(ORDEM_POS)))
        times = [[j for x in t if (j := _jogador(x, sel_de(x), feit, nomes, eu))] for t in (um, dois)]
        if arena:
            grupos = _times_arena(um, eu, gid)
            for x in times[0]:
                if x.get("puuid") in grupos:
                    x["time"] = grupos[x["puuid"]]
            # seu time primeiro (voce na frente), depois os outros times fechados, depois quem nao da pra agrupar
            times = [sorted(times[0], key=lambda x: (x.get("time", 99), not x.get("eu")))]
        elif any(x.get("puuid") == eu for x in dois):
            times.reverse()
        if not any(times):
            return None
        # Riot ID que nao veio (lookup falhou) ou jogador faltando faz montar de novo na proxima leitura
        completo = all(x["nome"] for t in times for x in t) and (
            (arena or not faltando) and sum(len(t) for t in times) >= len(sels))
        _carga.update(jogo=gid, times=times if completo else None, arena=bool(arena),
                      elos={} if _carga["jogo"] != gid else _carga["elos"])
    else:
        times = _carga["times"]
    # Arena nao tem elo: 18 leituras seguidas a toa
    falta = [] if arena else [x["puuid"] for t in times for x in t if x.get("puuid") and x["puuid"] not in _carga["elos"]]
    if falta and not _carga["buscando"]:
        _carga["buscando"] = True
        threading.Thread(target=_buscar_elos, args=(falta, (gd.get("queue") or {}).get("id")), daemon=True).start()
    saida = []
    for t in times:
        lista = []
        for x in t:
            y = {k: v for k, v in x.items() if k != "puuid"}
            elo = _carga["elos"].get(x.get("puuid"))
            if elo:
                y["elo"] = elo
            lista.append(y)
        saida.append(lista)
    if arena:  # uma lista so com os 18 (voce primeiro); o app desenha a grade da Arena
        return {"arena": True, "jogadores": saida[0] if saida else [], "times": [],
                "fila": q.get("description") or ""}
    return {"times": saida, "fila": (gd.get("queue") or {}).get("description") or ""}


def _jogo_dados():
    """allgamedata do jogo, ou None (tela de carregamento: a API ainda nao responde)."""
    if getattr(_http, "jogo", None) is None:
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        _http.jogo = requests.Session()
        _http.jogo.trust_env = False  # proxy do Windows nao entra no meio do 127.0.0.1
    try:
        r = _http.jogo.get(JOGO_URL, verify=False, timeout=1.5)  # certificado do proprio jogo, autoassinado
        return r.json() if r.status_code == 200 else None
    except (requests.RequestException, ValueError):
        return None


def jogo(antes=None, dados=None):
    """Retrato da partida em andamento: tempo, tropas, placar, seu KDA e os objetivos. So le."""
    antes = antes or {}
    d = _jogo_dados() if dados is None else dados
    gd = (d or {}).get("gameData") if isinstance(d, dict) else None
    t = (gd or {}).get("gameTime")
    evs = [x for x in ((d or {}).get("events") or {}).get("Events") or [] if isinstance(x, dict)] if gd else []
    comecou = isinstance(t, (int, float)) and any(x.get("EventName") == "GameStart" for x in evs)
    if not comecou:
        if antes.get("resultado") or antes.get("inicio"):
            # o jogo fechou (nexus caiu, as vezes antes de dar pra ler o GameEnd): segura o ultimo retrato ate o
            # client mudar de fase, senao o celular voltava pra tela de carregamento antes da vitoria/derrota
            return antes
        return {"carregando": True}
    jogadores = [p for p in d.get("allPlayers") or [] if isinstance(p, dict)]
    ativo = d.get("activePlayer") or {}
    eu_id = ativo.get("riotId") or ativo.get("summonerName")
    meu = next((p for p in jogadores if eu_id and eu_id in (p.get("riotId"), p.get("summonerName"))), None)
    lado_meu = (meu or {}).get("team")
    times = {}  # nome no evento -> time (o evento usa o nome do jogo, sem a tag)
    for p in jogadores:
        for n in (p.get("riotId"), p.get("riotIdGameName"), p.get("summonerName")):
            if n:
                times[n] = p.get("team")

    def lado(time_):
        if not time_ or not lado_meu:
            return None
        return "nos" if time_ == lado_meu else "eles"

    def lado_contra(nome):  # torre/inibidor "Turret_T1_...": T1 e do ORDER, quem derrubou e o outro time
        de = "ORDER" if "_T1_" in (nome or "") else "CHAOS" if "_T2_" in (nome or "") else None
        return lado({"ORDER": "CHAOS", "CHAOS": "ORDER"}.get(de))

    agora = agora_ms()
    j = {"inicio": _estavel(antes.get("inicio"), int(agora - t * 1000)), "modo": gd.get("gameMode") or "",
         "mapa": gd.get("mapNumber") or 0}
    tropas = next((x.get("EventTime") for x in evs if x.get("EventName") == "MinionsSpawning"), None)
    if isinstance(tropas, (int, float)):
        j["tropas"] = int(tropas)
    abates = {"nos": 0, "eles": 0}
    for p in jogadores:
        ld = lado(p.get("team"))
        if ld:
            abates[ld] += int((p.get("scores") or {}).get("kills") or 0)
    if lado_meu:
        j["placar"] = [abates["nos"], abates["eles"]]
    if meu:
        sc = meu.get("scores") or {}
        nome = meu.get("championName") or ""
        eu = {"campeao": nome, "k": int(sc.get("kills") or 0), "d": int(sc.get("deaths") or 0),
              "a": int(sc.get("assists") or 0), "cs": int(sc.get("creepScore") or 0)}
        cid = next((i for i, n in _nomes_campeoes().items() if n == nome), None)
        if cid:
            eu["id"] = cid
        if meu.get("isDead") and isinstance(meu.get("respawnTimer"), (int, float)):
            # hora em que volta (fixa): o tempo que falta muda a cada leitura e regravaria toda hora
            eu["volta"] = _estavel((antes.get("eu") or {}).get("volta"), int(agora + meu["respawnTimer"] * 1000))
        j["eu"] = eu
    lista = []
    for x in evs:
        tipo = OBJETIVOS.get(x.get("EventName"))
        if not tipo:
            continue
        ev = {"t": int(x.get("EventTime") or 0), "tipo": tipo}
        if tipo in ("torre", "inibidor"):
            ld = lado_contra(x.get("TurretKilled") or x.get("InhibKilled"))
        elif tipo == "ace":
            ld = lado(x.get("AcingTeam"))
        elif tipo == "primeiro_abate":
            ld = lado(times.get(x.get("Recipient")))
        else:
            ld = lado(times.get(x.get("KillerName")))
        if ld:
            ev["lado"] = ld
        if tipo == "dragao" and x.get("DragonType"):
            ev["dragao"] = str(x["DragonType"]).lower()
        if str(x.get("Stolen")).lower() == "true":
            ev["roubado"] = True
        lista.append(ev)
    if lista:
        j["eventos"] = lista[-EVENTOS_MAX:]
    fim = next((x for x in evs if x.get("EventName") == "GameEnd"), None)
    if fim and str(fim.get("Result") or "").lower() in ("win", "lose"):
        j["resultado"] = "vitoria" if str(fim["Result"]).lower() == "win" else "derrota"
        j["duracao"] = int(fim.get("EventTime") or t)
    return j


def _eog():
    """Numeros do fim de partida que o client guarda (so le). Vem vazio ate o servidor mandar os dados."""
    if _vivo.get("eog"):
        return _vivo["eog"]
    d = _get("/lol-end-of-game/v1/eog-stats-block")
    if not isinstance(d, dict) or not d.get("teams"):
        return None
    _vivo["eog"] = d
    return d


def _colocacao_arena(eog):
    """Colocacao do seu time na Arena (1 a 6 em 3x6), se o fim de partida trouxer. Formato NAO confirmado: procura o numero onde o client costuma por (subteamPlacement no jogador, ou um stat
    com PLACEMENT no nome) e so aceita de 1 a 8."""
    lp = eog.get("localPlayer") or {}
    for v in (lp.get("subteamPlacement"), lp.get("placement")):
        if isinstance(v, int) and not isinstance(v, bool) and 1 <= v <= 8:
            return v
    for k, v in (lp.get("stats") or {}).items():
        if "PLACEMENT" in str(k).upper() and isinstance(v, (int, float)) and not isinstance(v, bool) and 1 <= v <= 8:
            return int(v)
    return None


def fim(fase, gf):
    """Resultado da partida que acabou, pro celular mostrar vitoria ou derrota. So le.
    Sai primeiro do evento GameEnd da API do jogo (na hora em que o nexus cai) e, depois que o jogo fecha,
    dos numeros do fim de partida do client."""
    vivo = _vivo.get("fim_jogo") or {}
    arena = _arena(((gf or {}).get("gameData") or {}).get("queue", {}).get("id"))
    colocacao = None
    eog = _eog() if fase in FASES_FIM else None
    res = vivo.get("resultado")
    duracao = vivo.get("duracao")
    eu = dict(vivo.get("eu") or {})
    placar = vivo.get("placar")
    if eog:
        meu = next((t for t in eog.get("teams") or [] if isinstance(t, dict) and t.get("isPlayerTeam")), None)
        if arena:  # Arena: varios times, nao ha "dois lados": sem placar de abates e com a colocacao se vier
            colocacao = _colocacao_arena(eog)
        if meu and "isWinningTeam" in meu:
            res = "vitoria" if meu.get("isWinningTeam") else "derrota"
        if isinstance(eog.get("gameLength"), (int, float)) and eog["gameLength"] > 0:
            duracao = int(eog["gameLength"])
        lp = eog.get("localPlayer") or {}
        st = lp.get("stats") or {}
        if not eu and st:
            eu = {"k": int(st.get("CHAMPIONS_KILLED") or 0), "d": int(st.get("NUM_DEATHS") or 0),
                  "a": int(st.get("ASSISTS") or 0),
                  "cs": int(st.get("MINIONS_KILLED") or 0) + int(st.get("NEUTRAL_MINIONS_KILLED") or 0)}
        if not eu.get("id") and lp.get("championId"):
            eu["id"] = lp["championId"]
        if not placar and not arena:
            soma = {}
            for t in eog.get("teams") or []:
                if isinstance(t, dict):
                    soma[bool(t.get("isPlayerTeam"))] = sum(
                        int((p.get("stats") or {}).get("CHAMPIONS_KILLED") or 0)
                        for p in t.get("players") or [] if isinstance(p, dict))
            if len(soma) == 2:
                placar = [soma[True], soma[False]]
    if res not in ("vitoria", "derrota"):
        return None
    f = {"resultado": "remake" if isinstance(duracao, int) and duracao < REMAKE_S else res}
    if isinstance(duracao, int):
        f["duracao"] = duracao
    if placar and not arena:
        f["placar"] = placar
    if arena:
        f["arena"] = True
        if colocacao:
            f["colocacao"] = colocacao
    for k in ("k", "d", "a", "cs"):
        if k in eu:
            f[k] = eu[k]
    cid = eu.get("id")
    if cid:
        f["campeao"] = cid
        f["nome_campeao"] = eu.get("campeao") or _nomes_campeoes().get(cid, "")
        meu = next((x for t in _carga.get("times") or [] for x in t if x.get("eu")), None)
        f["arte"] = (meu or {}).get("arte") if (meu or {}).get("campeao") == cid else ""
        if not f["arte"]:
            f["arte"] = _skin_do_campeao(cid, 0).get("splashPath") or ""
    fila = ((gf or {}).get("gameData") or {}).get("queue") or {}
    if fila.get("description"):
        f["fila"] = fila["description"]
    return f


# ---------------- loops ----------------

def _responder(cid, ok, msg):
    try:
        _db("PATCH", f"ao_vivo/{uid()}", json={"resposta": {"id": cid, "ok": ok, "msg": msg,
                                                             "em": {".sv": "timestamp"}}})
    except requests.RequestException:
        pass


def executar(cid, cmd):
    """Roda um comando do celular. Devolve (ok, mensagem pro celular)."""
    if not isinstance(cmd, dict):
        return False, "comando invalido"
    # as regras do banco ja so deixam a conta deste PC gravar comando; conferir de novo aqui cobre o comando que
    # ficou na fila de uma conta que saiu (trocou de conta no painel) e regra mexida por engano
    dono = (conta() or {}).get("uid")
    if not dono or cmd.get("de") != dono:
        return False, "Comando de outra conta"
    em = cmd.get("em")
    if not isinstance(em, (int, float)) or abs(agora_ms() - em) > VALIDADE_CMD * 1000:
        return False, "Comando chegou atrasado"
    tipo = cmd.get("tipo")
    if tipo == "chat":
        return _mandar_chat(cmd.get("texto"))
    if tipo == "dm":
        return _mandar_dm(cmd.get("puuid"), cmd.get("texto"))
    if tipo == "dm_lida":
        return _dm_lida(cmd.get("puuid"))
    if tipo == "campeao":
        return _escolher(cmd.get("campeao"), cmd.get("acao"), cmd.get("travar") is True)
    if tipo == "criar_sala":
        return _criar_sala(cmd.get("fila"), cmd.get("quem"))
    if tipo == "convidar":
        return _convidar(cmd.get("quem"))
    if tipo == "posicao":
        return _posicao_sala(cmd.get("papel"), cmd.get("pos"))
    if tipo == "skin":
        return _trocar_skin(cmd.get("skin"))
    if tipo == "sair_selecao":
        return _sair_selecao()
    if tipo in TROCAS:
        return _troca(tipo, cmd.get("id"), cmd.get("cell"))
    if tipo == "banco":
        return _pegar_banco(cmd.get("campeao"))
    if tipo == "carta":
        return _escolher_carta(cmd.get("campeao"))
    if tipo == "feitico":
        return _trocar_feitico(cmd.get("slot"), cmd.get("feitico"))
    if tipo == "runa_pagina":
        return _usar_pagina(cmd.get("pagina"))
    if tipo == "runa_salvar":
        return _salvar_pagina(cmd.get("pagina"), cmd.get("nome"), cmd.get("primaria"), cmd.get("secundaria"),
                              cmd.get("perks"))
    if tipo == "abrir_lol":
        return _abrir_lol(em)
    if tipo == "fechar_lol":
        return _fechar_lol()
    if tipo not in COMANDOS:
        return False, "Comando desconhecido"
    metodo, caminho, texto = COMANDOS[tipo]
    try:
        r = _lcu(metodo, caminho)
    except requests.RequestException:
        r = None
    if r is None:
        return False, "LoL fechado"
    if not r.ok:
        _log(f"{tipo} recusado pelo client ({r.status_code})")
        return False, "O LoL recusou"
    _log(texto.lower())
    return True, texto


PROCESSOS_LOL = {"LeagueClient.exe", "LeagueClientUx.exe", "League of Legends.exe"}
ABRINDO_POR = 180     # segundos que o celular mostra "Abrindo o LoL" enquanto o client nao sobe


def _riot_client():
    """RiotClientServices.exe: o mesmo que o atalho do LoL abre. O caminho vem do RiotClientInstalls.json (onde o
    Riot Client se registra); sem ele, a pasta padrao. Sem Riot Client, o LeagueClient.exe ao lado do lockfile."""
    import os
    from pathlib import Path
    dados = Path(os.environ.get("ProgramData", r"C:\ProgramData")) / "Riot Games" / "RiotClientInstalls.json"
    candidatos = []
    try:
        j = json.loads(dados.read_text(encoding="utf-8"))
        candidatos += [j.get("rc_default"), j.get("rc_live"), *(j.get("associated_client") or {}).values()]
    except (OSError, ValueError, AttributeError):
        pass
    candidatos.append(r"C:\Riot Games\Riot Client\RiotClientServices.exe")
    for c in candidatos:
        # o json fica em ProgramData (outro usuario do PC consegue mudar): so roda o executavel assinado pela Riot
        if (isinstance(c, str) and c and Path(c).name.lower() == "riotclientservices.exe" and Path(c).is_file()
                and _assinado_riot(c)):
            return [str(Path(c)), "--launch-product=league_of_legends", "--launch-patchline=live"]
    lf = Path(lcu.lockfile())
    lol = lf.parent / "LeagueClient.exe"
    return [str(lol)] if lol.is_file() and _assinado_riot(lol) else None


_assinaturas = {}  # (caminho, data de alteracao) -> assinado pela Riot


def _assinado_riot(caminho):
    """Assinatura digital (Authenticode) valida e da Riot Games. Guarda a resposta enquanto o arquivo nao muda."""
    import os
    import subprocess
    try:
        chave = (str(caminho), os.path.getmtime(caminho))
    except OSError:
        return False
    if chave not in _assinaturas:
        cmd = ("$s = Get-AuthenticodeSignature -LiteralPath $env:PING_EXE; "
               "Write-Output (\"\" + $s.Status + \"|\" + $s.SignerCertificate.Subject)")
        try:
            r = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", cmd],
                               env={**os.environ, "PING_EXE": str(caminho)}, capture_output=True,
                               encoding="utf-8", errors="replace", timeout=20,
                               creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            status, _, quem = r.stdout.strip().partition("|")
            _assinaturas[chave] = status == "Valid" and re.search(r'(^|, )O="?Riot Games, Inc\.', quem) is not None
        except (OSError, subprocess.SubprocessError):
            return False  # nao deu pra conferir: nao roda (tenta de novo no proximo toque)
        if not _assinaturas[chave]:
            _log(f"{os.path.basename(str(caminho))} sem assinatura da Riot, nao abri")
    return _assinaturas[chave]


def _ux_rodando():
    import psutil
    try:
        return any(p.info.get("name") == "LeagueClientUx.exe" for p in psutil.process_iter(["name"]))
    except Exception:
        return True  # na duvida pergunta pro client


def _lol_rodando():
    import psutil
    try:
        return any(p.info.get("name") in PROCESSOS_LOL for p in psutil.process_iter(["name"]))
    except Exception:
        return False


# Barra de "Abrindo o LoL" no celular: o PC ve as etapas reais da abertura (processos e a LCU respondendo) e
# guarda quanto cada uma levou neste PC. O app usa o tempo esperado de cada etapa e corrige a barra quando ela acontece.
ARQ_ABERTURA = CACHE / "abertura.json"     # historico: quanto cada etapa levou nas ultimas aberturas
ARQ_ABRINDO = CACHE / "abrindo.json"       # abertura em andamento: sobrevive a reinicio do programa
ETAPAS_ABERTURA = {"frio": ["riot", "league", "ux", "pronto"], "quente": ["league", "ux", "pronto"]}
PROCESSO_ETAPA = {"riot": {"RiotClientServices.exe", "Riot Client.exe"}, "league": {"LeagueClient.exe"},
                  "ux": {"LeagueClientUx.exe"}}
# sem historico: chute de cada etapa em ms (contado do fim da anterior)
ESPERA_PADRAO = {"frio": {"riot": 3000, "league": 18000, "ux": 2000, "pronto": 7000},
                 "quente": {"league": 15000, "ux": 2000, "pronto": 7000}}  # medidas num PC real
GUARDA_ABERTURAS = 10
VERSAO_ABERTURA = 3  # 3: medida desde o PC receber (a 2 contava a demora do comando e saia inflada)
_trava_abertura = threading.Lock()


def _ler_json(arq):
    try:
        j = json.loads(arq.read_text(encoding="utf-8"))
        return j if isinstance(j, dict) else {}
    except (OSError, ValueError):
        return {}


def _gravar_json(arq, dados):
    try:
        CACHE.mkdir(exist_ok=True)
        tmp = arq.with_suffix(".tmp")
        tmp.write_text(json.dumps(dados), encoding="utf-8")
        tmp.replace(arq)
    except OSError as e:
        _log(f"nao gravei {arq.name}: {e}")


def _ler_aberturas():
    j = _ler_json(ARQ_ABERTURA)
    return j if j.get("v") == VERSAO_ABERTURA else {}


def _percentil(valores, p):
    v = sorted(valores)
    if not v:
        return None
    k = (len(v) - 1) * p
    i = int(k)
    return v[i] + (v[min(i + 1, len(v) - 1)] - v[i]) * (k - i)


def esperas_abertura(modo, historico=None):
    """Quanto cada etapa costuma levar neste PC (ms, contado do fim da anterior). Percentil 75 das ultimas aberturas,
    sem as fora da curva (login no Riot Client, update do LoL): chegar antes e melhor que travar no fim da barra."""
    hist = (historico if historico is not None else _ler_aberturas()).get(modo) or []
    saida = {}
    for nome in ETAPAS_ABERTURA[modo]:
        gaps = [h[nome] for h in hist if isinstance(h, dict) and isinstance(h.get(nome), (int, float))
                and h[nome] >= 0]
        mediana = _percentil(gaps, 0.5)
        if mediana is not None:
            gaps = [g for g in gaps if g <= max(mediana * 2.5, mediana + 4000)]
        saida[nome] = int(max(400, _percentil(gaps, 0.75))) if len(gaps) >= 2 else ESPERA_PADRAO[modo][nome]
    return saida, sum(1 for h in hist if isinstance(h, dict) and "pronto" in h)


def _guardar_abertura(modo, gaps):
    j = _ler_aberturas()
    j["v"] = VERSAO_ABERTURA
    j[modo] = ((j.get(modo) or []) + [gaps])[-GUARDA_ABERTURAS:]
    _gravar_json(ARQ_ABERTURA, j)


def _etapas_agora(etapas):
    """Indice da etapa mais adiante que ja aconteceu (as de antes contam como feitas junto), ou -1. So leitura local."""
    import psutil
    try:
        nomes = {p.info.get("name") for p in psutil.process_iter(["name"])}
    except Exception:
        nomes = set()
    # a API so existe com o LeagueClientUx: sem ele nem pergunta (client subindo segura a leitura ate 3s)
    pronto = "pronto" in etapas and "LeagueClientUx.exe" in nomes and bool(_get("/lol-gameflow/v1/gameflow-phase"))
    chegou = -1
    for i, n in enumerate(etapas):
        if (n == "pronto" and pronto) or nomes & PROCESSO_ETAPA.get(n, set()):
            chegou = i
    return chegou


def _medir_abertura(ab):
    """Le (so local: nome dos processos e a LCU) ate o client responder e marca a hora de cada etapa. ab vem
    de _comecar_abertura ou do arquivo (o programa reiniciou no meio da abertura)."""
    etapas = [n for n, _ in ab["etapas"]]
    respondeu = False
    while time.time() - ab["inicio_pc"] < ABRINDO_POR and _vivo.get("abertura") is ab:
        chegou = _etapas_agora(etapas)
        if chegou >= 0 and etapas[chegou] == "pronto":
            # a LCU responde e cai algumas vezes enquanto o client sobe: pronto e responder 2 leituras seguidas
            respondeu, chegou = True, (chegou if respondeu else chegou - 1)
        else:
            respondeu = False
        novas = {n: int(agora_ms()) for n in etapas[:chegou + 1] if n not in ab["feitas"]}
        if novas:
            ms = int((time.time() - ab["inicio_pc"]) * 1000)
            ab["tempos"].update({n: ms for n in novas})
            ab["feitas"] = {**ab["feitas"], **novas}  # dict novo: o estado e comparado com o anterior
            if etapas[-1] not in novas:
                _gravar_json(ARQ_ABRINDO, ab)
        if etapas[-1] in ab["feitas"]:
            with _trava_abertura:
                if _vivo.get("abertura") is ab:
                    _vivo["abertura"] = None
            _apagar_abrindo()
            t = ab["tempos"]
            # quanto cada etapa levou desde a anterior; etapas que chegaram juntas (leitura de 0,5s) dividem
            gaps, antes = {}, 0
            for n in etapas:
                gaps[n] = max(0, t[n] - antes)
                antes = t[n]
            if not ab.get("retomada"):  # reinicio no meio perde tempo de leitura: nao entra na media
                _guardar_abertura(ab["modo"], gaps)
            _log("LoL abriu em " + ", ".join(f"{n} {t[n] / 1000:.1f}s" for n in etapas))
            return
        time.sleep(0.5)
    with _trava_abertura:
        if _vivo.get("abertura") is ab:
            _vivo["abertura"] = None
    _apagar_abrindo()


def _apagar_abrindo():
    try:
        ARQ_ABRINDO.unlink()
    except OSError:
        pass


def _comecar_abertura(modo, tocou_ms=None):
    """Comeca a medir. tocou_ms: hora (do servidor) em que o celular mandou o comando, pra barra contar do toque.
    Etapa que ja tinha acontecido (Riot Client aberto em segundo plano) sai da barra e da media."""
    chegou = _etapas_agora(ETAPAS_ABERTURA[modo])
    if modo == "frio" and chegou >= 0:
        modo = "quente"  # Riot Client ja estava rodando (em segundo plano): e a abertura com ele aberto
        chegou = _etapas_agora(ETAPAS_ABERTURA[modo])
    etapas = ETAPAS_ABERTURA[modo][chegou + 1:] or ETAPAS_ABERTURA[modo][-1:]
    esperas, medidas = esperas_abertura(modo)
    agora = agora_ms()
    inicio = int(tocou_ms) if isinstance(tocou_ms, (int, float)) and 0 <= agora - tocou_ms < 15000 else int(agora)
    # a barra conta do toque (inicio); a media mede daqui (inicio_pc), sem a demora do comando chegar
    ab = {"modo": modo, "inicio": inicio, "inicio_pc": time.time(),
          "etapas": [[n, esperas[n]] for n in etapas], "feitas": {}, "tempos": {}, "estimado": medidas < 2}
    with _trava_abertura:
        _vivo["abertura"] = ab
    _gravar_json(ARQ_ABRINDO, ab)
    threading.Thread(target=_medir_abertura, args=(ab,), daemon=True).start()


def retomar_abertura():
    """O programa reiniciou com o LoL abrindo (atualizacao, Reiniciar): continua a mesma barra de onde estava."""
    ab = _ler_json(ARQ_ABRINDO)
    if not ab.get("etapas") or not isinstance(ab.get("inicio_pc"), (int, float)):
        _apagar_abrindo()
        return
    if time.time() - ab["inicio_pc"] >= ABRINDO_POR or _get("/lol-gameflow/v1/gameflow-phase"):
        _apagar_abrindo()
        return
    ab.setdefault("feitas", {})
    ab.setdefault("tempos", {})
    ab["retomada"] = True
    with _trava_abertura:
        _vivo["abertura"] = ab
        _vivo["abrindo"] = ab["inicio_pc"]
    threading.Thread(target=_medir_abertura, args=(ab,), daemon=True).start()
    _log("abertura do LoL retomada depois do reinicio")


def abrindo_lol():
    """LoL abrindo agora (pelo celular ou na mao): a atualizacao sozinha espera, senao reinicia no meio."""
    if time.time() - _vivo["abrindo"] < ABRINDO_POR:
        return True
    return not _get("/lol-gameflow/v1/gameflow-phase") and _lol_rodando()


def _abertura_estado():
    ab = _vivo.get("abertura")
    if not ab:
        return None
    return {"inicio": ab["inicio"], "etapas": ab["etapas"], "feitas": dict(ab["feitas"]), "estimado": ab["estimado"]}


def _riot_api(metodo, caminho):
    """Chamada na API local do Riot Client (lockfile em %LOCALAPPDATA%). None = Riot Client fechado."""
    import os
    from pathlib import Path
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    lf = Path(os.environ.get("LOCALAPPDATA", "")) / "Riot Games" / "Riot Client" / "Config" / "lockfile"
    try:
        _, _, porta, senha, proto = lf.read_text(encoding="utf-8").strip().split(":")
        return requests.request(metodo, f"{proto}://127.0.0.1:{porta}{caminho}", auth=("riot", senha),
                                verify=False, timeout=5)
    except (OSError, ValueError, requests.RequestException):
        return None


def _jogar_riot_client():
    """O Jogar do Riot Client pela API local dele. Com o Riot Client ja aberto em segundo plano, o
    --launch-product so mostra a pagina do LoL e nao abre o jogo. None = Riot Client fechado."""
    _riot_visto["em"] = 0.0
    if not _riot_rodando():  # lockfile que sobrou do Riot Client fechado: a porta morta segura ate o timeout
        return None
    r = _riot_api("POST", "/product-launcher/v1/products/league_of_legends/patchlines/live")
    if r is None:
        return None
    if not r.ok:
        _log(f"Riot Client recusou o Jogar ({r.status_code})")
    return r.ok


def _vigiar_abertura():
    """Riot Client aberto do zero pelo atalho: se o LoL nao subir sozinho (ficou so no Riot Client), pede o
    Jogar. Espera a pessoa logar se precisar, ate o fim do ABRINDO_POR."""
    inicio = time.time()
    time.sleep(10)
    while time.time() - inicio < ABRINDO_POR:
        if _vivo["fechando"] or not _vivo["abrindo"]:  # fechou pelo celular no meio: nao reabre
            return
        if _lol_rodando():
            return
        if _jogar_riot_client():
            _log("LoL aberto pelo Riot Client")
            return
        time.sleep(random.uniform(4, 6))


def _abrir_lol(tocou_ms=None):
    """Abre o LoL no PC, como clicar no atalho e no Jogar do Riot Client. O login continua sendo da pessoa.
    Tem que responder rapido: o celular desiste em 8s ("O PC nao respondeu")."""
    comeco = time.time()
    try:
        return _abrir_lol_ja(tocou_ms)
    finally:
        if time.time() - comeco > 3:
            _log(f"abrir o LoL demorou {time.time() - comeco:.1f}s pra responder")


def _abrir_lol_ja(tocou_ms):
    import subprocess
    if _vivo["fechando"]:
        return False, "Espere o LoL terminar de fechar"
    # so pergunta pro client com ele rodando: client morrendo ou subindo segura cada leitura ate 3s
    if _ux_rodando() and _get("/lol-gameflow/v1/gameflow-phase"):
        return False, "O LoL já está aberto"
    if _vivo.get("abertura"):  # toque de novo no meio: a barra continua de onde estava, nao recomeca
        return True, "O LoL já está abrindo"
    if _lol_rodando():
        _vivo["abrindo"] = time.time()
        return True, "O LoL já está abrindo"
    if _jogar_riot_client():
        _vivo["abrindo"] = time.time()
        _comecar_abertura("quente", tocou_ms)
        _log("abrindo o LoL pelo celular (Riot Client ja aberto)")
        return True, "Abrindo o LoL"
    cmd = _riot_client()
    if not cmd:
        return False, "Não achei o LoL neste PC"
    try:
        subprocess.Popen(cmd, close_fds=True,
                         creationflags=getattr(subprocess, "DETACHED_PROCESS", 0)
                         | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0))
    except OSError as e:
        _log(f"falha ao abrir o LoL: {e}")
        return False, "Não consegui abrir o LoL"
    _vivo["abrindo"] = time.time()
    _comecar_abertura("frio" if len(cmd) > 1 else "quente", tocou_ms)
    _log("abrindo o LoL pelo celular")
    if len(cmd) > 1:  # Riot Client: confere se ele deu o Jogar sozinho
        threading.Thread(target=_vigiar_abertura, daemon=True).start()
    return True, "Abrindo o LoL"


PROCESSOS_RIOT = {"RiotClientServices.exe", "Riot Client.exe", "RiotClientUx.exe", "RiotClientUxRender.exe"}
# fechar no meio disso tira voce da partida (dodge na selecao, abandono em jogo): o celular nem mostra o botao
FASES_SEM_FECHAR = {"ReadyCheck", "ChampSelect", "GameStart", "InProgress", "Reconnect"}
_riot_visto = {"em": 0.0, "aberto": False}


def _riot_rodando():
    """Riot Client aberto (com o LoL fechado: o celular oferece fechar ele). Le no maximo a cada 3s."""
    if time.time() - _riot_visto["em"] > 3:
        import psutil
        try:
            _riot_visto["aberto"] = any(p.info.get("name") in PROCESSOS_RIOT for p in psutil.process_iter(["name"]))
        except Exception:
            _riot_visto["aberto"] = False
        _riot_visto["em"] = time.time()
    return _riot_visto["aberto"]


def _esperar_sumir(nomes, ate):
    import psutil
    fim = time.time() + ate
    while time.time() < fim:
        if not any(p.info.get("name") in nomes for p in psutil.process_iter(["name"])):
            return True
        time.sleep(0.5)
    return False


def _encerrar(nomes):
    """Ultimo recurso: o que nao fechou pelo pedido vai como no Gerenciador de Tarefas."""
    import psutil
    for p in psutil.process_iter(["name"]):
        if p.info.get("name") in nomes:
            try:
                p.terminate()
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass


def _fechar_tudo():
    """LoL primeiro (o client se despede do servidor como no X), depois o Riot Client. Enquanto fecha, o celular
    mostra "Fechando o LoL" (sem o Abrir: abrir no meio achava os processos morrendo e nao abria nada)."""
    try:
        try:
            _lcu("POST", "/process-control/v1/process/quit")
        except requests.RequestException:
            pass  # o client pode cair antes de responder
        if not _esperar_sumir(PROCESSOS_LOL, 15):
            _encerrar(PROCESSOS_LOL)
            _esperar_sumir(PROCESSOS_LOL, 5)
        _riot_api("POST", "/process-control/v1/process/quit")
        if not _esperar_sumir(PROCESSOS_RIOT, 10):
            _encerrar(PROCESSOS_RIOT)
            _esperar_sumir(PROCESSOS_RIOT, 5)
        _riot_visto["em"] = 0.0
        _log("LoL e Riot Client fechados pelo celular")
    finally:
        _vivo["fechando"] = 0.0


def _fechar_lol():
    """Fecha o LoL e o Riot Client, como fechar pelo X e sair do Riot Client na bandeja. Nunca no meio de partida."""
    fase = _get("/lol-gameflow/v1/gameflow-phase") if not _vivo["fechando"] else None
    if fase in FASES_SEM_FECHAR:
        return False, "Agora não: você sairia da partida"
    if _vivo["fechando"]:  # toque de novo enquanto fecha: nao e erro
        return True, "O LoL já está fechando"
    if not fase and not _lol_rodando() and not _riot_rodando():
        return False, "O LoL já está fechado"
    _vivo["abrindo"] = 0.0
    _vivo["abertura"] = None
    _vivo["fechando"] = time.time()
    threading.Thread(target=_fechar_tudo, daemon=True).start()
    return True, "Fechando o LoL"


def _sair_selecao():
    """O SAIR da selecao do client (so quando ele mostra o botao, ex.: personalizada). E o quit da selecao
    (team builder): o cancel-champ-select da sala personalizada so voltava o client pra tela inicial e o
    servidor seguia com voce na partida, que comecava sozinha logo depois."""
    s = _get("/lol-champ-select/v1/session")
    if not isinstance(s, dict) or not s.get("showQuitButton"):
        return False, "Aqui não dá pra sair"
    try:
        r = _lcu("POST", "/lol-lobby-team-builder/champ-select/v1/session/quit")
    except requests.RequestException:
        r = None
    if r is None:
        return False, "LoL fechado"
    if not r.ok:
        _log(f"sair da selecao recusado pelo client ({r.status_code})")
        return False, "O LoL recusou"
    _log("saiu da selecao")
    return True, "Saiu da seleção"


# troca com aliado, como na tela do client: grupo -> (lista na sessao, rota da tela, chave no aliado, nome)
GRUPOS_TROCA = {
    "troca": ("trades", "champion-swaps", "troca", "Troca"),
    "pos": ("positionSwaps", "position-swaps", "troca_pos", "Troca de posição"),
    "ordem": ("pickOrderSwaps", "pick-order-swaps", "troca_ordem", "Troca de ordem"),
}
# acao -> (acao na LCU, estado que a troca tem que ter, fim do que aparece no celular)
ACOES_TROCA = {"pedir": ("request", "AVAILABLE", "pedida"), "aceitar": ("accept", "RECEIVED", "aceita"),
               "recusar": ("decline", "RECEIVED", "recusada"), "cancelar": ("cancel", "SENT", "cancelada")}
TROCAS = {f"{g}_{a}": (g, a) for g in GRUPOS_TROCA for a in ACOES_TROCA}
TROCA_PENDENTE = ("SENT", "RECEIVED")   # voce pediu ou pediram pra voce
FASES_BANCO = ("BAN_PICK", "FINALIZATION")
BANCO_ESPERA = (3.2, 4.5)  # a tela do client trava o banco 3s depois de cada troca
TROCA_ESTADOS = {"BUSY": "Esse aliado está em outra troca", "INVALID": "Agora não dá pra trocar com ele",
                 "SENT": "Você já pediu essa troca", "RECEIVED": "Ele já pediu troca com você"}
TROCA_FIM_S = 5   # a tela do client some com os botoes de troca nos 5s finais dos picks e da finalizacao


def _lista_trocas(s, grupo):
    """Trocas de um tipo na sessao, como o celular recebe (cell, id, estado)."""
    return [{"cell": t.get("cellId"), "id": t.get("id"), "estado": t.get("state") or ""}
            for t in s.get(GRUPOS_TROCA[grupo][0]) or [] if isinstance(t, dict) and isinstance(t.get("id"), int)]


def _ordem_ok(s, travou, cell=None):
    """Troca de ordem so no planejamento e nos picks, com voce e o aliado ainda sem travar (como a tela)."""
    if (s.get("timer") or {}).get("phase") not in ("PLANNING", "BAN_PICK"):
        return False
    return s.get("localPlayerCellId") not in travou and (cell is None or cell not in travou)


def _fim_da_selecao(s):
    """Ultimos segundos dos picks ou da finalizacao: a tela do client esconde a troca."""
    t = s.get("timer") or {}
    if t.get("phase") not in FASES_BANCO or t.get("isInfinite"):
        return False
    ini, falta = t.get("internalNowInEpochMs"), t.get("adjustedTimeLeftInPhase")
    if not isinstance(ini, (int, float)) or not isinstance(falta, (int, float)):
        return False
    return (ini + falta) / 1000 - time.time() <= TROCA_FIM_S


def _espacar():
    """Duas acoes seguidas na selecao pelo celular (troca, banco): nunca no mesmo instante, com um intervalo
    entre elas para nao sobrecarregar o client."""
    falta = _vivo["escrita_sel"] + random.uniform(0.8, 1.4) - time.time()
    if falta > 0:
        time.sleep(falta)


def _post_selecao(caminhos):
    """POST no primeiro caminho que o client conhece (404 = rota que nao existe nessa versao do client)."""
    r = None
    for c in caminhos:
        try:
            r = _lcu("POST", c)
        except requests.RequestException:
            return None
        if r is None or r.status_code != 404:
            break
    _vivo["escrita_sel"] = time.time()
    return r


def _troca(tipo, tid, cell):
    """Pede, aceita, recusa ou cancela troca com um aliado (campeao, posicao ou ordem de pick), como nos botoes
    do client. Confere de novo na sessao (o id muda a cada mudanca no time): pedir vai pelo aliado (cell), o
    resto pelo id e cai pro aliado."""
    grupo, nome_acao = TROCAS[tipo]
    acao, precisa, fim = ACOES_TROCA[nome_acao]
    lista, rota, _, nome = GRUPOS_TROCA[grupo]
    s = _get("/lol-champ-select/v1/session")
    if not isinstance(s, dict) or not s.get("myTeam"):
        return False, "Você não está na seleção"
    trocas = [t for t in s.get(lista) or [] if isinstance(t, dict)]
    t = None
    if nome_acao != "pedir" and isinstance(tid, int):
        t = next((x for x in trocas if x.get("id") == tid), None)
    if t is None and isinstance(cell, int):
        t = next((x for x in trocas if x.get("cellId") == cell), None)
    if t is None:
        return False, "Essa troca não existe mais"
    # uma troca por vez, de qualquer tipo (o client tambem: as outras viram INVALID)
    todas = [x for g in GRUPOS_TROCA.values() for x in s.get(g[0]) or [] if isinstance(x, dict)]
    if nome_acao == "pedir" and any(x.get("state") in TROCA_PENDENTE for x in todas):
        return False, "Termine a outra troca antes"
    if t.get("state") != precisa:
        return False, TROCA_ESTADOS.get(t.get("state"), "Essa troca não está mais valendo")
    if nome_acao in ("pedir", "aceitar"):
        if _fim_da_selecao(s):
            return False, "Tarde demais pra trocar"
        if grupo == "ordem":
            acoes = [x for g in s.get("actions") or [] for x in g]
            travou = {x.get("actorCellId") for x in acoes if x.get("type") == "pick" and x.get("completed")}
            if not _ordem_ok(s, travou, t.get("cellId")):
                return False, "Agora não dá pra trocar a ordem"
    _espacar()
    # so a rota que a tela do client usa (a antiga /session/trades saiu: rota que o client nao usa destoa)
    r = _post_selecao([f"/lol-champ-select/v1/session/{rota}/{t['id']}/{acao}"])
    if r is None:
        return False, "LoL fechado"
    if not r.ok:
        _log(f"{tipo} recusado pelo client ({r.status_code})")
        return False, "O LoL recusou a troca"
    m = next((x for x in s.get("myTeam") or [] if x.get("cellId") == t.get("cellId")), {})
    nomes = _nomes_campeoes()
    feito = "Pedido cancelado" if nome_acao == "cancelar" else f"{nome} {fim}"
    _log(f"{ascii_log(feito.lower())} com {ascii_log(m.get('gameName') or 'aliado')} "
         f"({ascii_log(nomes.get(m.get('championId') or 0, '?'))}, {m.get('assignedPosition') or '-'})")
    return True, feito


def _escolher_carta(cid):
    """ARAM Desordem: escolhe uma das cartas do comeco, como clicar nela no client (a tela faz o PATCH com
    completed true direto, sem marcar antes). Confere de novo na sessao e na lista de cartas antes."""
    if not isinstance(cid, int) or cid <= 0:
        return False, "Campeão inválido"
    s = _get("/lol-champ-select/v1/session")
    if not isinstance(s, dict) or not s.get("myTeam"):
        return False, "Você não está na seleção"
    if s.get("queueId") not in lcu.FILAS_ARAM or (s.get("timer") or {}).get("phase") != "BAN_PICK":
        return False, "As cartas já fecharam"
    eu = s.get("localPlayerCellId")
    acao = next((a for g in s.get("actions") or [] for a in g if a.get("actorCellId") == eu
                 and a.get("type") == "pick" and not a.get("completed")), None)
    if not acao:
        return False, "Você já escolheu"
    sub = _get("/lol-lobby-team-builder/champ-select/v1/subset-champion-list")
    if not isinstance(sub, list) or cid not in sub:
        return False, "Essa carta não está mais valendo"
    _espacar()
    try:
        # mesma rota e corpo da tela do client (champSelectService.selectChampion(acao, campeao, true))
        r = _lcu("PATCH", f"/lol-champ-select/v1/session/actions/{acao['id']}",
                 json={"completed": True, "championId": cid})
    except requests.RequestException:
        r = None
    _vivo["escrita_sel"] = time.time()
    if r is None:
        return False, "LoL fechado"
    nome = _nomes_campeoes().get(cid, "")
    if not r.ok:
        _log(f"carta recusada pelo client ({r.status_code})")
        return False, f"O LoL não deixou escolher {nome or 'essa carta'}"
    _log(f"escolheu a carta {ascii_log(nome or str(cid))} pelo celular")
    return True, f"Escolheu {nome}" if nome else "Carta escolhida"


def _pegar_banco(cid):
    """Pega um campeao do banco (ARAM), como clicar nele no client. So se ele ainda esta la e nao tem troca com
    aliado no meio (pegar do banco desfaria a troca)."""
    if not isinstance(cid, int) or cid <= 0:
        return False, "Campeão inválido"
    s = _get("/lol-champ-select/v1/session")
    if not isinstance(s, dict) or not s.get("myTeam"):
        return False, "Você não está na seleção"
    if cid not in [b.get("championId") for b in s.get("benchChampions") or [] if isinstance(b, dict)]:
        return False, "Esse campeão saiu do banco"
    if any(t.get("state") in TROCA_PENDENTE for g in GRUPOS_TROCA.values() for t in s.get(g[0]) or []
           if isinstance(t, dict)):
        return False, "Termine a troca com o aliado antes"
    if (s.get("timer") or {}).get("phase") not in FASES_BANCO:
        return False, "Ainda não dá pra pegar do banco"
    _espacar()
    # o client trava o banco por 3s depois de cada troca: espera passar, como quem toca de novo
    falta = _vivo["banco_t"] + random.uniform(*BANCO_ESPERA) - time.time()
    if falta > 0:
        time.sleep(falta)
        s = _get("/lol-champ-select/v1/session")  # nessa espera alguem pode ter pego
        if not isinstance(s, dict) or cid not in [b.get("championId") for b in s.get("benchChampions") or []
                                                  if isinstance(b, dict)]:
            return False, "Esse campeão saiu do banco"
    r = _post_selecao([f"/lol-champ-select/v1/session/bench/swap/{cid}"])
    _vivo["banco_t"] = time.time()
    if r is None:
        return False, "LoL fechado"
    nome = _nomes_campeoes().get(cid, "")
    if not r.ok:
        _log(f"banco recusado pelo client ({r.status_code})")
        return False, f"O LoL não deixou pegar {nome or 'esse campeão'}"
    _log(f"pegou {ascii_log(nome or str(cid))} do banco pelo celular")
    return True, f"Pegou {nome}" if nome else "Pegou do banco"


def _escolher(cid, acao, travar):
    """Marca (hover) ou trava/bane um campeao na SUA acao da selecao, conforme o toque no celular. No
    planejamento, marcar e declarar intencao."""
    if not isinstance(cid, int) or cid <= 0 or acao not in ("pick", "ban"):
        return False, "Campeão inválido"
    s = _get("/lol-champ-select/v1/session")
    if not isinstance(s, dict):
        return False, "Você não está na seleção"
    if s.get("queueId") in lcu.FILAS_ARAM:
        return False, "Na ARAM: Desordem o campeão é sorteado"
    arena = _arena(s.get("queueId"))
    if arena and (s.get("timer") or {}).get("phase") != "BAN_PICK":
        # na Arena o ban aparece em andamento ja no planejamento, mas ali ninguem bane nem escolhe
        return False, "Ainda não abriu a escolha"
    eu = s.get("localPlayerCellId")
    minhas = [a for g in s.get("actions") or [] for a in g
              if a.get("actorCellId") == eu and a.get("type") == acao and not a.get("completed")]
    a = next((x for x in minhas if x.get("isInProgress")), None)
    if not a and acao == "pick" and minhas and not travar and not arena:
        a = minhas[0]  # antes da sua vez (planejamento ou bans): so declara intencao (a Arena nao tem)
    if not a:
        return False, "Não é sua vez"
    if acao == "pick" and cid in lcu.banidos_da_sessao(s):
        return False, "Esse campeão foi banido"
    corpo = {"championId": cid}
    if travar:
        corpo["completed"] = True
        if a.get("championId") != cid:
            # o campeao ainda nao estava marcado: marca primeiro e trava depois, como a tela do client faz
            try:
                r = _lcu("PATCH", f"/lol-champ-select/v1/session/actions/{a['id']}", json={"championId": cid})
            except requests.RequestException:
                r = None
            if r is None or not r.ok:
                return False, "O LoL recusou esse campeão"
            # intervalo curto entre marcar e travar, sem passar do turno (antes travar rapido que perder a vez)
            t = s.get("timer") or {}
            fim = (t.get("internalNowInEpochMs") or 0) + (t.get("adjustedTimeLeftInPhase") or 0)
            restante = (fim - time.time() * 1000) / 1000 if t.get("internalNowInEpochMs") else 10.0
            time.sleep(max(0.3, min(random.uniform(0.45, 1.0), restante - 0.6)))
    try:
        r = _lcu("PATCH", f"/lol-champ-select/v1/session/actions/{a['id']}", json=corpo)
    except requests.RequestException:
        r = None
    if r is None:
        return False, "LoL fechado"
    if not r.ok:
        _log(f"{acao} recusado pelo client ({r.status_code})")
        return False, "O LoL recusou esse campeão"
    nomes = _nomes_campeoes()
    feito = ("Banido" if acao == "ban" else "Travado") if travar else (
        "Marcado" if a.get("isInProgress") else "Intencao")
    _log(f"{feito.lower()}: {ascii_log(nomes.get(cid, str(cid)))}")
    return True, "" if not travar else f"{feito}: {nomes.get(cid, '')}"


def ascii_log(t):
    return lcu.ascii_log(t)


def _mandar_chat(texto):
    texto = str(texto or "").strip()[:200]
    if not texto:
        return False, "Mensagem vazia"
    sessao = _get("/lol-champ-select/v1/session") if _get("/lol-gameflow/v1/gameflow-phase") == "ChampSelect" else None
    if isinstance(sessao, dict):  # na selecao o chat e o dela
        cid = _id_conversa((sessao.get("chatDetails") or {}).get("multiUserChatId"))
    else:
        cid = _id_conversa((_get("/lol-lobby/v2/lobby") or {}).get("multiUserChatId"))
    if not cid:
        return False, "Sem chat agora"
    try:
        r = _lcu("POST", f"/lol-chat/v1/conversations/{quote(cid)}/messages", json={"body": texto, "type": "groupchat"})
        if r is not None and not r.ok:  # formato recusado: tenta so com o texto
            _log(f"chat recusado com type groupchat ({r.status_code}), tentando sem")
            r = _lcu("POST", f"/lol-chat/v1/conversations/{quote(cid)}/messages", json={"body": texto})
    except requests.RequestException:
        r = None
    if r is None:
        return False, "LoL fechado"
    if not r.ok:
        _log(f"chat recusado pelo client ({r.status_code})")
        return False, "O LoL recusou a mensagem"
    _log("mensagem mandada no chat da sala")
    return True, ""


# o app manda sozinho, sem botao esperando: responder tomaria o lugar de outra resposta
SEM_RESPOSTA = {"dm_lida"}
_feitos = collections.deque(maxlen=200)  # ids ja executados: o stream reabre e entrega de novo


_ritmo = {"ultimo": 0.0, "hist": collections.deque(maxlen=200)}  # (tipo, hora) dos comandos aceitos


def _no_ritmo(tipo):
    """Comando do celular dentro do limite? Aceito, espera um respiro sorteado depois do anterior (dois toques
    seguidos nunca saem no mesmo instante)."""
    agora = time.time()
    hist = _ritmo["hist"]

    def quantos(t, janela):
        return sum(1 for tt, h in hist if agora - h < janela and (t is None or tt == t))

    n, janela = LIMITE_GERAL
    if quantos(None, janela) >= n:
        return False
    if tipo in LIMITES:
        n, janela = LIMITES[tipo]
        if quantos(tipo, janela) >= n:
            return False
    hist.append((tipo, agora))
    falta = _ritmo["ultimo"] + random.uniform(0.5, 0.9) - agora
    if falta > 0:
        time.sleep(falta)
    _ritmo["ultimo"] = time.time()
    return True


def _tratar(dados, prefixo=""):
    """Evento do stream: um comando ({"tipo":..}) ou varios ({id: comando})."""
    if not isinstance(dados, dict):
        return
    if prefixo:
        itens = [(prefixo, dados)]
    else:
        itens = [(k, v) for k, v in dados.items() if isinstance(v, dict)]
    for cid, cmd in itens:
        if cid in _feitos:
            continue
        _feitos.append(cid)
        if cmd.get("tipo") == "olhando":
            # pulso do app aberto: so memoria, sem resposta e fora do limite (nao gasta os comandos de verdade)
            em = cmd.get("em")
            dono = (conta() or {}).get("uid")
            if dono and cmd.get("de") == dono and isinstance(em, (int, float)) and abs(agora_ms() - em) <= VALIDADE_CMD * 1000:
                celular_olhando(cmd.get("valor"))
            try:
                _db("DELETE", f"comandos/{uid()}/{cid}")
            except Exception:
                pass
            continue
        try:
            if _no_ritmo(cmd.get("tipo")):
                ok, msg = executar(cid, cmd)
            else:
                _log(f"comando {cmd.get('tipo')} ignorado (muitos seguidos)")
                ok, msg = False, "Muitos comandos seguidos: espere um pouco"
        except Exception as e:
            _log(f"comando {cmd.get('tipo')} falhou ({e.__class__.__name__})")
            ok, msg = False, "Deu erro no PC"
        try:
            if cmd.get("tipo") not in SEM_RESPOSTA:
                _responder(cid, ok, msg)
        except Exception:
            pass
        try:
            _db("DELETE", f"comandos/{uid()}/{cid}")
        except Exception:
            pass


def _ouvir():
    """Stream de comandos/<pc>. Reabre a cada hora (o token vence) ou quando cai."""
    while True:
        try:
            tk, eu = token(), uid()
            vence = _conta["expira"]
            with requests.get(f"{DB}/comandos/{eu}.json", params={"auth": tk},
                              headers={"Accept": "text/event-stream"}, stream=True, timeout=(10, 70)) as r:
                r.raise_for_status()
                _vivo["erro"] = None
                evento = None
                for linha in r.iter_lines(chunk_size=1, decode_unicode=True):
                    if linha.startswith("event:"):
                        evento = linha[6:].strip()
                    elif linha.startswith("data:") and evento in ("put", "patch"):
                        d = json.loads(linha[5:])
                        caminho = (d.get("path") or "/").strip("/")
                        if d.get("data") is not None:
                            _tratar(d["data"], caminho)
                    elif linha.startswith("data:") and evento in ("cancel", "auth_revoked"):
                        break
                    if time.time() > vence:
                        break
        except PermissionError as e:
            _vivo["erro"] = str(e)
            time.sleep(60)
            continue
        except Exception as e:
            _vivo["erro"] = e.__class__.__name__ if not isinstance(e, requests.HTTPError) else f"HTTP {e.response.status_code}"
            if isinstance(e, requests.HTTPError) and e.response.status_code == 401:
                _conta["id_token"] = None  # senao fica em 401 ate o token vencer
        time.sleep(3)


# no ao_vivo/<pc> e do PC mas nao vem do estado(): nao apagar na primeira gravacao
CHAVES_FIXAS = {"visto", "resposta"}
CHAVES_ESTADO = ("fila_nome", "fila_inicio", "fila_estimado", "partida", "sala", "selecao", "grade", "runas",
                 "runas_arvore", "filas", "amigos", "conversas", "abrindo", "abertura", "riot", "fechando", "jogo",
                 "carregamento", "fim", "hoje", "pc_nome", "conta_lol")
# mapas gravados chave a chave: uma mensagem nova regrava so a conversa dela, nao todas
SUBCHAVES = ("conversas",)


def _chaves_gravadas():
    """O que esta no ao_vivo/<pc> agora (so os nomes: shallow). Programa que reiniciou (atualizacao no meio da
    abertura do LoL, por ex.) nao sabe o que a execucao anterior deixou la: sem limpar, o celular via um
    "Abrindo o LoL" velho pra sempre. Sem resposta do banco, a lista conhecida."""
    try:
        j = _db("GET", f"ao_vivo/{uid()}", params={"shallow": "true"})
        if isinstance(j, dict):
            return [k for k in j if k not in CHAVES_FIXAS]
    except (requests.RequestException, PermissionError, ValueError):
        pass
    return list(CHAVES_ESTADO)


def _espelhar():
    """Grava o estado em ao_vivo/<pc> quando muda (e o visto a cada 30s). Sem conta, nao grava nada."""
    retomar_abertura()
    antes, gravado, visto, limpo = {}, None, 0.0, False
    while True:
        try:
            if conta():
                _lembrar_riot_id()
                e = estado(antes)
                antes = e
                import avisos  # aqui: o avisos importa este modulo
                avisos.observar(e)  # notificacao push (so leitura local)
                if e != gravado or time.time() - visto > VISTO_CADA:
                    antes_ms = time.time() * 1000
                    # so o que mudou (a grade da selecao pesa ~11 KB) + o que sumiu vira null
                    mudou = {}
                    for k, v in e.items():
                        g = (gravado or {}).get(k)
                        if g == v:
                            continue
                        if k in SUBCHAVES and isinstance(v, dict) and isinstance(g, dict):
                            mudou.update({f"{k}/{s}": x for s, x in v.items() if g.get(s) != x})
                            mudou.update({f"{k}/{s}": None for s in g if s not in v})
                        else:
                            mudou[k] = v
                    mudou.update({k: None for k in (gravado or {}) if k not in e})
                    if gravado is None:  # primeira gravacao: limpa o que sobrou da execucao anterior
                        mudou.update({k: None for k in _chaves_gravadas() if k not in e})
                    gravou = _db("PATCH", f"ao_vivo/{uid()}", json=dict(mudou, visto={".sv": "timestamp"}))
                    if isinstance(gravou, dict) and isinstance(gravou.get("visto"), (int, float)):
                        # hora em que o servidor gravou ~ meio da ida e volta
                        _vivo["offset"] = gravou["visto"] - (antes_ms + time.time() * 1000) / 2
                    gravado, visto = e, time.time()
                # abrindo o LoL: cada etapa chega rapido no celular (a barra se corrige por ela)
                time.sleep(0.6 if e["fase"] in ("Lobby", "Matchmaking", "ReadyCheck", "ChampSelect") or e.get("abrindo") or e.get("fechando")
                           else 1.5)
                continue
            if gravado is not None or not limpo:
                # sem conta: chat, DMs e amigos nao ficam esperando no banco
                _db("DELETE", f"ao_vivo/{uid()}")
                antes, gravado, limpo = {}, None, True
        except PermissionError as e:
            _vivo["erro"] = str(e)
            time.sleep(60)
            continue
        except Exception:
            pass
        time.sleep(5)


def iniciar():
    threading.Thread(target=_ouvir, daemon=True).start()
    threading.Thread(target=_espelhar, daemon=True).start()
