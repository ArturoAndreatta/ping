"""
Conversa com o client do LoL pela API local dele (LCU): acha a porta e a senha, faz as chamadas e guarda os
dados do jogo que so mudam com patch (campeoes, feiticos, runas, filas).

Tudo aqui so le do client. Quem escreve (aceitar, marcar campeao...) e a ponte, e so quando o celular pede.
"""
import json
import re
import threading
import time
import unicodedata
import urllib.request
from pathlib import Path

import psutil
import requests
import urllib3

urllib3.disable_warnings()

BASE = Path(__file__).resolve().parent
CACHE = BASE / "cache"
CONFIG = BASE / "config.json"
LOCKFILE_PADRAO = r"C:\Riot Games\League of Legends\lockfile"
DDRAGON = "https://ddragon.leagueoflegends.com"

# 2400 = ARAM: Desordem (codinome KIWI). Nao tem runa (aumentos no lugar) nem rolar de novo
FILAS_ARAM = {2400}
# Arena (gameMode CHERRY): 18 jogadores, ban e pick ao mesmo tempo, par de feitico fixo
FILAS_ARENA = {1700, 1710, 1740, 1750}
MODO_ARENA = "CHERRY"


def log(msg):
    print(f"{time.strftime('%H:%M:%S')} {msg}", flush=True)  # uma escrita so: threads nao misturam


def norm(s):
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]", "", s.lower())


def ascii_log(t):
    # sem quebra de linha nem outro caractere de controle: texto de fora nao inventa linha falsa no log
    t = unicodedata.normalize("NFKD", t or "").encode("ascii", "ignore").decode()
    return re.sub(r"[\x00-\x1f\x7f]", " ", t) or "?"


def fila_arena(fila, modo=None):
    """Fila da Arena: pelo numero (as que ja vimos) ou pelo gameMode CHERRY que o client informa."""
    return fila in FILAS_ARENA or modo == MODO_ARENA


def banidos_da_sessao(s):
    """Campeoes ja banidos por qualquer um (acoes de ban travadas)."""
    return {a.get("championId") for g in s.get("actions", []) for a in g
            if a.get("type") == "ban" and a.get("completed") and (a.get("championId") or 0) > 0}


def runas_validas(r):
    return (isinstance(r, dict) and isinstance(r.get("primaria"), int) and isinstance(r.get("secundaria"), int)
            and r["primaria"] != r["secundaria"] and isinstance(r.get("perks"), list) and len(r["perks"]) == 9
            and all(isinstance(x, int) and not isinstance(x, bool) for x in r["perks"]))


# ---------------- config ----------------

OPCOES = ("abrir_com_windows", "atualizar_sozinho", "resumo_dia")  # todas ligadas por padrao


def config():
    """config.json opcional: as OPCOES do painel e o caminho do lockfile (quando o LoL nao esta na pasta padrao)."""
    try:
        d = json.loads(CONFIG.read_text(encoding="utf-8"))
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def salvar_config(mudou):
    cfg = {**config(), **mudou}
    tmp = CONFIG.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    tmp.replace(CONFIG)
    return cfg


def lockfile():
    return config().get("lockfile") or LOCKFILE_PADRAO


# ---------------- client ----------------

class LCU:
    def __init__(self, port, token):
        self.url = f"https://127.0.0.1:{port}"
        self.s = requests.Session()
        self.s.auth = ("riot", token)
        self.s.verify = False

    def req(self, method, path, **kw):
        return self.s.request(method, self.url + path, timeout=3, **kw)

    def get(self, path):
        r = self.req("GET", path)
        if r.ok and r.content:
            return r.json()
        return None


def find_credentials():
    """Pega porta e senha da linha de comando do client; se falhar, tenta o lockfile."""
    # so o nome de cada processo (barato); a linha de comando (cara no Windows) so do client
    aberto = False
    for p in psutil.process_iter(["name"]):
        if p.info.get("name") != "LeagueClientUx.exe":
            continue
        aberto = True
        try:
            cmd = p.cmdline()
        except psutil.Error:
            continue
        port = token = None
        for a in cmd or []:
            if a.startswith("--app-port="):
                port = a.split("=", 1)[1]
            elif a.startswith("--remoting-auth-token="):
                token = a.split("=", 1)[1]
        if _porta_ok(port) and token:
            return port, token

    # lockfile so com o client rodando: depois de o LoL fechar com erro o arquivo fica no disco
    if not aberto:
        return None
    try:
        parts = Path(lockfile()).read_text(encoding="utf-8").split(":")
    except OSError:
        return None
    # lockfile = nome:pid:porta:senha:protocolo
    if len(parts) >= 4 and _porta_ok(parts[2]) and (len(parts) < 5 or parts[4].strip() == "https"):
        return parts[2], parts[3]
    return None


def _porta_ok(port):
    """Porta so numero: com outra coisa no lugar ("443@site.com") a URL https://127.0.0.1:{porta} ia pra fora do PC."""
    return isinstance(port, str) and port.isdigit() and 0 < int(port) < 65536


_lock = threading.Lock()
LOCK = threading.Lock()  # requests.Session nao aguenta varias threads juntas
_lcu = None
_procurou = 0.0  # ultima vez que procurou o client (varre os processos do Windows: nao repete a cada chamada)


def cliente():
    global _lcu, _procurou
    with _lock:
        if _lcu is None and time.time() - _procurou >= 2:
            _procurou = time.time()
            cred = find_credentials()
            if cred:
                _lcu = LCU(*cred)
        return _lcu


def get(path):
    global _lcu, _procurou
    c = cliente()
    if not c:
        return None
    try:
        with LOCK:
            return c.get(path)
    except Exception:
        _lcu, _procurou = None, 0.0  # caiu: a proxima chamada ja procura de novo
        return None


def req(metodo, caminho, **kw):
    """Chamada qualquer na LCU. None com o client fechado."""
    c = cliente()
    if not c:
        return None
    with LOCK:
        return c.req(metodo, caminho, **kw)


# dados do jogo (campeoes, feiticos, itens, filas) so mudam com patch: guarda enquanto a conexao for a mesma
_fixos = {"lcu": None, "dados": {}}


def fixo(path, validade=None):
    """get com cache em memoria. Devolve (dados, novo): novo = acabou de vir do client."""
    c = cliente()
    if not c:
        return None, False
    with _lock:
        if _fixos["lcu"] is not c:
            _fixos.update(lcu=c, dados={})
        x = _fixos["dados"].get(path)
        if x and (validade is None or time.time() - x[1] < validade):
            return x[0], False
    dados = get(path)
    if dados:
        with _lock:
            if _fixos["lcu"] is c:
                _fixos["dados"][path] = (dados, time.time())
    return dados, bool(dados)


def json_cache(nome, dados=None):
    arq = CACHE / nome
    if dados is not None:
        try:
            CACHE.mkdir(exist_ok=True)
            arq.write_text(json.dumps(dados, ensure_ascii=False), encoding="utf-8")
        except OSError:
            pass
        return dados
    try:
        return json.loads(arq.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


# ---------------- Data Dragon (client fechado) ----------------

_dd = {}


def _baixar(url, timeout=8):
    req_ = urllib.request.Request(url, headers={"User-Agent": "ping"})
    with urllib.request.urlopen(req_, timeout=timeout) as r:
        return r.read()


def ddragon():
    # sem internet: nao tenta de novo a cada chamada (cada tentativa segura ate 8s)
    if "champs" not in _dd and time.time() - _dd.get("falhou", 0) > 300:
        try:
            ver = json.loads(_baixar(f"{DDRAGON}/api/versions.json"))[0]
            data = json.loads(_baixar(f"{DDRAGON}/cdn/{ver}/data/pt_BR/champion.json"))["data"]
            _dd["ver"] = ver
            _dd["champs"] = [{"id": int(v["key"]), "name": v["name"], "alias": v["id"]}
                             for v in data.values()]
        except Exception:
            _dd["falhou"] = time.time()
    return _dd


# ---------------- dados do jogo ----------------

def _so_base(lst):
    """Tira as variantes de modo (ex: Jade_Ahri, ID 60103): fica o ID menor de cada nome."""
    vistos, fora = set(), []
    for c in sorted(lst, key=lambda c: c["id"]):
        if c["name"] in vistos:
            continue
        vistos.add(c["name"])
        fora.append(c)
    return fora


def campeoes():
    data, novo = fixo("/lol-game-data/assets/v1/champion-summary.json")
    if isinstance(data, list) and data:
        lst = _so_base([{"id": c["id"], "name": c["name"], "alias": c["alias"]}
                        for c in data if c.get("id", -1) > 0])
        if novo:
            json_cache("campeoes.json", lst)
        return lst, "client"
    cache = json_cache("campeoes.json")
    if isinstance(cache, list) and cache:
        return _so_base(cache), "cache"
    dd = ddragon()
    if dd.get("champs"):
        json_cache("campeoes.json", dd["champs"])
        return dd["champs"], "ddragon"
    return [], None


FEITICOS_FALLBACK = [
    (4, "Flash"), (14, "Incendiar"), (3, "Exaustão"), (7, "Curar"), (21, "Barreira"), (12, "Teleporte"),
    (11, "Golpear"), (6, "Fantasma"), (1, "Purificar"), (13, "Clareza"), (32, "Marca"),
]
MODOS_ATUAIS = {"CLASSIC", "ARAM"}  # Summoner's Rift e ARAM


def _so_atuais(lst):
    """So feiticos dos modos normais; tira os de modos antigos/eventos (Jade, Poro, Arena...) e duplicados."""
    vistos, out = set(), []
    for s in sorted(lst, key=lambda s: s["id"]):
        if s.get("modos") and not MODOS_ATUAIS & set(s["modos"]):
            continue
        if s["nome"] in vistos:
            continue
        vistos.add(s["nome"])
        out.append(s)
    return out


def _feiticos_brutos():
    """Todos os feiticos do client (inclusive de modos de evento), com o cache de reserva."""
    data, novo = fixo("/lol-game-data/assets/v1/summoner-spells.json")
    if isinstance(data, list) and data:
        out = [{"id": s["id"], "nome": s.get("name"), "icone": s.get("iconPath"), "modos": s.get("gameModes") or []}
               for s in data if s.get("id", 0) > 0 and s.get("gameModes")]
        return json_cache("feiticos.json", out) if novo else out
    return json_cache("feiticos.json")


def feiticos():
    brutos = _feiticos_brutos()
    if brutos:
        return _so_atuais(brutos)
    return [{"id": i, "nome": n, "icone": None, "modos": []} for i, n in FEITICOS_FALLBACK]


def feiticos_arena():
    """Os feiticos da Arena (modo CHERRY: Fuga e Flash). Ficam fora de feiticos() porque nao valem nos outros modos."""
    return [f for f in _feiticos_brutos() or [] if "CHERRY" in (f.get("modos") or [])]


def _texto(html):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html or "")).strip()


def runas_dados():
    """Arvores de runas pro editor do celular. Do client; com ele fechado, do cache (o Data Dragon nao traz os
    fragmentos)."""
    estilos, novo = fixo("/lol-game-data/assets/v1/perkstyles.json")
    perks, novo2 = fixo("/lol-game-data/assets/v1/perks.json")
    if isinstance(estilos, dict) and isinstance(perks, list) and perks:
        info = {p["id"]: p for p in perks if p.get("id")}
        out = {"estilos": [], "perks": {}}
        for s in estilos.get("styles") or []:
            slots = [{"tipo": sl.get("type"), "nome": sl.get("slotLabel") or "", "perks": sl.get("perks") or []}
                     for sl in s.get("slots") or []]
            if not any(sl["tipo"] == "kKeyStone" for sl in slots):
                continue
            out["estilos"].append({"id": s["id"], "nome": s.get("name"), "icone": s.get("iconPath"),
                                   "subs": s.get("allowedSubStyles") or [], "slots": slots})
            for sl in slots:
                for pid in sl["perks"]:
                    p = info.get(pid) or {}
                    out["perks"][str(pid)] = {"nome": p.get("name") or str(pid), "icone": p.get("iconPath"),
                                              "desc": _texto(p.get("shortDesc"))[:220]}
        ordem = [8000, 8100, 8200, 8400, 8300]  # mesma ordem do client
        out["estilos"].sort(key=lambda s: (ordem.index(s["id"]) if s["id"] in ordem else 99, s["id"]))
        return {**(json_cache("runas.json", out) if novo or novo2 else out), "conectado": True}
    cache = json_cache("runas.json")
    return {**cache, "conectado": False} if cache else {"estilos": [], "perks": {}, "conectado": False}


# ---------------- historico de partidas (so leitura) ----------------

_hist = {"t": 0.0, "dados": None}
_hist_lock = threading.Lock()


def historico(forcar=False):
    """Ultimas 100 partidas. Guarda 10s: o client demora pra montar a lista."""
    with _hist_lock:
        if not forcar and _hist["dados"] and time.time() - _hist["t"] < 10:
            return _hist["dados"]
        dados = _historico()
        if dados.get("jogos") is not None:
            _hist.update(t=time.time(), dados=dados)
        return dados


def _historico():
    h = get("/lol-match-history/v1/products/lol/current-summoner/matches?begIndex=0&endIndex=99")
    if not isinstance(h, dict):
        return {"jogos": None}
    jogos = []
    for g in ((h.get("games") or {}).get("games") or []):
        part = (g.get("participants") or [{}])[0]
        stt = part.get("stats") or {}
        dur = g.get("gameDuration") or 0
        arena = g.get("gameMode") == "CHERRY" and stt.get("subteamPlacement")
        jogos.append({
            "id": g.get("gameId"), "fila": g.get("queueId"), "quando": g.get("gameCreation"),
            "duracao": dur, "campeao": part.get("championId"), "modo": g.get("gameMode"),
            # Arena: metade de cima (1o ao 4o) conta como vitoria, igual o client mostra
            "vitoria": (stt.get("subteamPlacement") or 9) <= 4 if arena else bool(stt.get("win")),
            "k": stt.get("kills", 0), "d": stt.get("deaths", 0), "a": stt.get("assists", 0), "remake": dur < 300,
            "cs": (stt.get("totalMinionsKilled") or 0) + (stt.get("neutralMinionsKilled") or 0),
            "ouro": stt.get("goldEarned") or 0, "dano": stt.get("totalDamageDealtToChampions") or 0,
            "visao": stt.get("visionScore") or 0, "multi": stt.get("largestMultiKill") or 0,
        })
    jogos.sort(key=lambda j: j["quando"] or 0, reverse=True)
    return {"jogos": jogos}
