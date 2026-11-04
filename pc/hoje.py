"""
Resumo do dia (so leitura do historico de partidas do client): guarda as partidas de hoje em cache/hoje.json,
que o celular mostra na aba Hoje, e avisa ao fechar o LoL.
"""
import json
import threading
import time
from datetime import datetime, timedelta

import psutil

import lcu

HOJE_CACHE = lcu.CACHE / "hoje.json"
VIRADA_DO_DIA = 5  # o "dia" vira as 5h (partida de madrugada conta pro dia anterior)
PROCESSOS_LOL = {"LeagueClient.exe", "LeagueClientUx.exe", "League of Legends.exe"}
FECHADO_CONFIRMA = 2  # leituras seguidas sem o LoL pra contar como fechado


def lol_rodando():
    try:
        return any(p.info.get("name") in PROCESSOS_LOL for p in psutil.process_iter(["name"]))
    except psutil.Error:
        return True  # na duvida, aberto: o aviso so sai com o LoL fechado de verdade


def dia_de(ts_ms):
    return (datetime.fromtimestamp(ts_ms / 1000) - timedelta(hours=VIRADA_DO_DIA)).date()


def hoje():
    return (datetime.now() - timedelta(hours=VIRADA_DO_DIA)).date()


def salvar_hoje(jogos):
    try:
        HOJE_CACHE.parent.mkdir(exist_ok=True)
        HOJE_CACHE.write_text(json.dumps({"dia": str(hoje()), "jogos": jogos}, ensure_ascii=False), encoding="utf-8")
    except OSError:
        pass


def jogos_de_hoje_cache():
    try:
        d = json.loads(HOJE_CACHE.read_text(encoding="utf-8"))
        if d.get("dia") == str(hoje()):
            return d.get("jogos") or []
    except (OSError, ValueError):
        pass
    return []


def atualizar_hoje(lista_jogos):
    """lista_jogos no formato do lcu.historico(); guarda so os de hoje."""
    jogos = [j for j in lista_jogos if j.get("quando") and dia_de(j["quando"]) == hoje()]
    salvar_hoje(jogos)
    return jogos


def nomes_campeoes():
    return {c["id"]: (c["name"], c["alias"]) for c in lcu.campeoes()[0]}


def resumo(jogos, nomes=None):
    validos = [j for j in jogos if not j.get("remake")]
    if not validos:
        return None
    v = sum(1 for j in validos if j["vitoria"])
    k = sum(j["k"] for j in validos)
    d = sum(j["d"] for j in validos)
    a = sum(j["a"] for j in validos)
    por = {}
    for j in validos:
        x = por.setdefault(j["campeao"], {"id": j["campeao"], "n": 0, "v": 0, "k": 0, "d": 0, "a": 0})
        x["n"] += 1
        x["v"] += j["vitoria"]
        x["k"] += j["k"]
        x["d"] += j["d"]
        x["a"] += j["a"]
    # MVP: mais vitorias; empate vai pro melhor KDA
    mvp = max(por.values(), key=lambda x: (x["v"], (x["k"] + x["a"]) / max(1, x["d"])))
    nome_mvp = (nomes or {}).get(mvp["id"], (str(mvp["id"]),))[0]
    return {
        "partidas": len(validos), "vitorias": v, "derrotas": len(validos) - v,
        "kda": round((k + a) / max(1, d), 2), "k": k, "d": d, "a": a,
        "minutos": round(sum(j.get("duracao") or 0 for j in validos) / 60),
        "mvp": {"id": mvp["id"], "nome": nome_mvp, "partidas": mvp["n"], "vitorias": mvp["v"]},
    }


def texto_resumo(r):
    p = r["partidas"]
    return (f"Hoje: {p} partida{'s' if p > 1 else ''}, {r['vitorias']} vitoria{'s' if r['vitorias'] != 1 else ''}"
            f" · KDA {r['kda']:.2f} · MVP: {r['mvp']['nome']}")


def rodar(notificar=None):
    """Roda numa thread da bandeja. notificar(titulo, texto) mostra aviso do Windows."""
    conectado_antes, ultima_fase = False, None
    aberto_antes, sem_lol = False, 0
    while True:
        try:
            fase = lcu.get("/lol-gameflow/v1/gameflow-phase")
            conectado = fase is not None
            if conectado and not conectado_antes:
                threading.Timer(5, _pos_jogo).start()  # pega as de hoje ja jogadas
            # saiu da partida: atualiza o resumo de hoje
            jogo = ("InProgress", "WaitingForStats", "PreEndOfGame")
            if ultima_fase in jogo and fase not in jogo:
                threading.Timer(8, _pos_jogo, args=(True,)).start()
            ultima_fase = fase
            # fechou o client: mostra o resumo do dia. Leitura que falha (client ocupado) nao conta: so com os
            # processos do LoL sumidos em leituras seguidas
            if conectado:
                aberto_antes, sem_lol = True, 0
            elif aberto_antes:
                sem_lol = 0 if lol_rodando() else sem_lol + 1
                if sem_lol >= FECHADO_CONFIRMA:
                    aberto_antes, sem_lol = False, 0
                    r = resumo(jogos_de_hoje_cache(), nomes_campeoes())
                    if r and notificar:
                        notificar("Resumo do dia", texto_resumo(r))
                    if r:
                        import avisos  # no celular: cada aparelho escolhe se quer
                        avisos.resumo_do_dia(texto_resumo(r))
            conectado_antes = conectado
            time.sleep(3)
        except Exception as e:  # nunca derruba a bandeja
            lcu.log(f"Hoje: erro ({e.__class__.__name__}: {e})")
            time.sleep(10)


def _pos_jogo(logar=False):
    """Depois da partida: atualiza o cache de hoje com o historico."""
    try:
        h = lcu.historico(forcar=True)  # partida acabou de entrar: nao serve o guardado
        if h.get("jogos") is not None:
            r = resumo(atualizar_hoje(h["jogos"]), nomes_campeoes())
            if r and logar:
                lcu.log(texto_resumo(r))
    except Exception:
        pass
