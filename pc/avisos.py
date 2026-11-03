"""Avisos no celular com o app fechado (notificacao push).

Quem manda e o disparador (pasta disparador/ do repositorio, rota POST /aviso). O PC so pede: tipo e dados, com
o ID token da conta anonima dele (a mesma da ponte.py). Nada de segredo aqui: o disparador confere o token e so
manda pros celulares da conta deste PC que escolheram ouvir ele. O texto e montado la.

Tudo aqui e leitura local (estado que a ponte.py ja monta, convites recebidos, ultimo mouse/teclado do
Windows): nenhuma escrita no client.

Longe do PC: o aviso espera PERTO_DEPOIS segundos e confere se voce mexeu no mouse ou no teclado nesse tempo ou
nos `ponte.perto_minutos()` minutos antes do evento. Mexeu = voce esta no PC, e o aviso vai marcado como `perto`
(so chega no celular que ligou "Avisar mesmo com voce no PC"). Partida encontrada nao espera nada (`espera=0`):
so vale o mouse/teclado ate aquele instante.

Com o app aberto na tela do celular (`ponte._celular_aberto()`, o app manda `olhando`) nenhum aviso sai: voce
ja esta vendo. Confere na hora do evento e de novo antes de mandar.
"""

import threading
import time

import requests

import ponte as celular
import servidor

URL = servidor.AVISOS
PERTO_DEPOIS = 3      # segundos que espera depois do evento pra ver se voce mexe
DM_ESPERA = 20        # mensagem de amigo so vira aviso se continuar sem ler depois disso
CONVITES_CADA = 2.0   # segundos entre leituras dos convites recebidos (local)
FASES_CONVITE = ("None", "Lobby")

_st = {"iniciou": False, "fila": False, "partida": None, "vez": "", "trocas": set(), "dms": {}, "dm_avisada": {},
       "sala_chat": None, "abrindo": False, "fim": None, "convites": None, "convites_em": 0.0}
_lock = threading.Lock()


def _log(msg):
    celular._log(f"aviso no celular: {msg}")


def _perto(tick_antes, ocioso_antes):
    """Voce esta no PC? (mexeu pouco antes do evento ou logo depois)"""
    if tick_antes is None:
        return False
    return ocioso_antes < celular.perto_minutos() * 60 or celular._ultimo_input() != tick_antes


def _mandar(tipo, dados, perto):
    try:
        r = requests.post(URL, json={"projeto": "ping", "tipo": tipo, "dados": dados, "perto": perto},
                          headers={"Authorization": f"Bearer {celular.token()}"}, timeout=15)
        j = r.json() if r.headers.get("Content-Type", "").startswith("application/json") else {}
        if r.status_code == 429:
            return  # o disparador segurou (muitos seguidos): normal, sem log
        if r.ok:
            if j.get("entregues"):
                _log(f"{tipo} ({j['entregues']})")
        else:
            _log(f"{tipo} recusado ({r.status_code}: {celular.ascii_log(str(j.get('erro') or ''))[:80]})")
    except Exception as e:  # sem rede, token, resposta estranha: o aviso se perde, o programa segue
        _log(f"{tipo} falhou ({e.__class__.__name__})")


def pedir(tipo, dados=None, conferir_perto=True, espera=PERTO_DEPOIS):
    """Pede o aviso numa thread propria (a espera do 'perto' nao segura quem chamou).

    `espera` 0: sai na hora, so com o que se sabe do mouse/teclado ate agora (partida encontrada: o tempo
    pra aceitar e curto, cada segundo conta)."""
    if not celular.conta():
        return  # sem conta no PC, nao tem pra quem avisar
    if celular._celular_aberto():
        return  # app na tela do celular: voce ja ve o aviso la dentro
    tick, ocioso = celular._ultimo_input(), celular._ocioso()

    def rodar():
        perto = False
        if conferir_perto:
            if espera:
                time.sleep(espera)
            perto = _perto(tick, ocioso)
        if celular._celular_aberto():
            return  # abriu o app nesse meio tempo
        _mandar(tipo, dados or {}, perto)

    threading.Thread(target=rodar, daemon=True).start()


# ---------------- o que vira aviso ----------------

def _fila(e):
    """Entrou na fila (voce, pelo celular, ou o lider da sala)."""
    na_fila = e["fase"] in ("Matchmaking", "ReadyCheck")
    if e["fase"] == "Matchmaking" and not _st["fila"]:
        pedir("fila", {"fila": e.get("fila_nome") or ""}, espera=0)
    _st["fila"] = na_fila


def _partida(e):
    p = e.get("partida") or {}
    chave = p.get("inicio") if e["fase"] == "ReadyCheck" and p.get("resposta") == "None" else None
    if chave and chave != _st["partida"]:
        pedir("partida", {"fila": e.get("fila_nome") or ""}, espera=0)
    _st["partida"] = chave or (_st["partida"] if e["fase"] == "ReadyCheck" else None)


def _selecao(e):
    sel = e.get("selecao") if e["fase"] == "ChampSelect" else None
    if not isinstance(sel, dict):
        _st["vez"], _st["trocas"] = "", set()
        return
    vez = sel.get("minha_vez") or ""
    if vez in ("pick", "ban") and vez != _st["vez"]:
        pedir("vez", {"acao": vez})
    _st["vez"] = vez
    agora = set()
    for m in sel.get("meu") or []:
        for g, (_, _, chave, _) in celular.GRUPOS_TROCA.items():
            if m.get(chave) == "RECEIVED":
                k = (g, m.get("cell"))
                agora.add(k)
                if k not in _st["trocas"]:
                    pedir("troca", {"tipo": g, "quem": m.get("nome") or ""})
    _st["trocas"] = agora


def _mensagens(e):
    """Mensagem de amigo que continua sem ler depois de DM_ESPERA segundos (lida no PC nao avisa)."""
    agora = time.time()
    for puuid, c in (e.get("conversas") or {}).items():
        msgs = [m for m in c.get("msgs") or [] if not m.get("eu")]
        ultima = msgs[-1] if msgs else None
        if not ultima or not c.get("nao_lidas"):
            _st["dms"].pop(puuid, None)
            continue
        mid = ultima.get("id")
        if _st["dm_avisada"].get(puuid) == mid:
            continue
        visto = _st["dms"].setdefault(puuid, (mid, agora))
        if visto[0] != mid:
            _st["dms"][puuid] = (mid, visto[1])  # chegou outra: conta desde a primeira sem ler
        if agora - visto[1] >= DM_ESPERA:
            _st["dm_avisada"][puuid] = mid
            pedir("mensagem", {"puuid": puuid, "quem": c.get("nome") or "", "texto": ultima.get("texto") or ""})


def _sala_chat(e):
    """Mensagem de alguem no chat da sala (so conta pra celular quando voce esta longe do PC)."""
    sl = e.get("sala")
    chat = (sl or {}).get("chat") or []
    ids = {m.get("id") for m in chat}
    if _st["sala_chat"] is None or not sl:
        _st["sala_chat"] = ids if sl else None  # o que ja estava na sala quando o programa viu nao conta
        return
    for m in chat:
        if m.get("id") in _st["sala_chat"]:
            continue
        if m.get("tipo") == "msg" and not m.get("eu"):
            pedir("mensagem", {"sala": True, "quem": m.get("de") or "", "texto": m.get("texto") or ""})
    _st["sala_chat"] |= ids


def _lol_pronto(e):
    # so a abertura pedida pelo celular manda `abertura` (a barra de carregamento do app); a fase aparece
    # quando a LCU responde, e ai o `abertura` some
    if _st["abrindo"] and e["fase"] != "Fechado":
        pedir("lol_pronto")
    _st["abrindo"] = bool(e.get("abertura"))


def _fim(e):
    f = e.get("fim")
    if not isinstance(f, dict):
        return
    chave = (f.get("resultado"), f.get("duracao"), f.get("campeao"))
    if chave == _st["fim"]:
        return
    _st["fim"] = chave
    kda = "/".join(str(f[k]) for k in ("k", "d", "a") if k in f)
    pedir("fim", {"resultado": f.get("resultado"), "campeao": f.get("nome_campeao") or "", "kda": kda})


def _convites(fase):
    """Convite pra sala recebido (leitura local dos convites, como a tela do client)."""
    agora = time.time()
    if fase not in FASES_CONVITE:
        return
    if agora - _st["convites_em"] < CONVITES_CADA:
        return
    _st["convites_em"] = agora
    lista = celular._get("/lol-lobby/v2/received-invitations")
    pend = [c for c in lista if isinstance(c, dict) and c.get("state") == "Pending"] if isinstance(lista, list) else []
    ids = {c.get("invitationId") for c in pend}
    if _st["convites"] is None:
        _st["convites"] = ids
        return
    for c in pend:
        if c.get("invitationId") in _st["convites"]:
            continue
        s = celular._get(f"/lol-summoner/v1/summoners/{c.get('fromSummonerId')}") if c.get("fromSummonerId") else None
        quem = (s or {}).get("gameName") or (s or {}).get("displayName") or ""
        pedir("convite", {"quem": quem})
    _st["convites"] = ids


def observar(e):
    """Chamado pela ponte.py a cada estado novo (so com conta no PC)."""
    with _lock:
        primeira = not _st["iniciou"]
        if primeira:
            # o que ja estava na tela quando o programa abriu nao vira aviso
            _st["iniciou"] = True
            _st["fila"] = e["fase"] in ("Matchmaking", "ReadyCheck")
            p = e.get("partida") or {}
            _st["partida"] = p.get("inicio")
            sel = e.get("selecao") or {}
            _st["vez"] = sel.get("minha_vez") or ""
            _st["trocas"] = {(g, m.get("cell")) for m in sel.get("meu") or []
                             for g, (_, _, k, _) in celular.GRUPOS_TROCA.items() if m.get(k) == "RECEIVED"}
            _st["dm_avisada"] = {pid: ((c.get("msgs") or [{}])[-1]).get("id")
                                 for pid, c in (e.get("conversas") or {}).items()}
            f = e.get("fim") or {}
            _st["fim"] = (f.get("resultado"), f.get("duracao"), f.get("campeao")) if f else None
            _st["abrindo"] = bool(e.get("abertura"))
            sl = e.get("sala")
            _st["sala_chat"] = {m.get("id") for m in (sl.get("chat") or [])} if sl else None
            return
        for f in (_fila, _partida, _selecao, _mensagens, _sala_chat, _lol_pronto, _fim):
            try:
                f(e)
            except Exception as x:
                _log(f"erro em {f.__name__} ({x.__class__.__name__})")
        try:
            _convites(e["fase"])
        except Exception as x:
            _log(f"erro ({x.__class__.__name__})")


def resumo_do_dia(texto):
    """O client fechou: o resumo do dia (o hoje.py chama)."""
    if texto:
        pedir("resumo", {"texto": texto}, conferir_perto=False)
