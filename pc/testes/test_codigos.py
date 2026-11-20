"""
Testes do PC: codigos que o celular traduz (status, grupos, avisos, respostas), erros de conta, idioma e locale do
Data Dragon. LCU falso (get/req/fixo trocados) e cache/config numa pasta temporaria; nada toca o client nem a rede.

Rodar (na pasta pc/):  python -m unittest discover testes -v
"""
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

PC = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PC))

import idioma  # noqa: E402
import lcu  # noqa: E402
import ponte  # noqa: E402


class Resposta:
    def __init__(self, ok=True, status=200, corpo=None):
        self.ok, self.status_code = ok, status
        self._corpo = corpo or {}
        self.content = b"x" if corpo is not None else b""

    def json(self):
        return self._corpo


class Base(unittest.TestCase):
    """Cache e config em pasta temporaria; idioma do Windows travado em pt."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        raiz = Path(self.tmp.name)
        for alvo, valor in ((lcu, {"CACHE": raiz / "cache", "CONFIG": raiz / "config.json"}),
                            (ponte, {"CACHE": raiz / "cache", "ARQ_CONTA": raiz / "cache" / "conta.json"})):
            for k, v in valor.items():
                p = mock.patch.object(alvo, k, v)
                p.start()
                self.addCleanup(p.stop)
        p = mock.patch.object(idioma, "windows", lambda: "pt")
        p.start()
        self.addCleanup(p.stop)
        lcu._loc.update(v=None, t=0.0)
        lcu._dd.clear()
        self.addCleanup(self.tmp.cleanup)

    def lcu_falso(self, get=None, fixo=None):
        """lcu.get e lcu.fixo trocados: get = {caminho: dados}; fixo idem (o client fechado devolve None)."""
        get, fixo = get or {}, fixo or {}
        for nome, tabela in (("get", get), ("fixo", fixo)):
            def f(caminho, validade=None, _t=tabela, _n=nome):
                d = _t.get(caminho)
                return (d, bool(d)) if _n == "fixo" else d
            p = mock.patch.object(lcu, nome, f)
            p.start()
            self.addCleanup(p.stop)


class TestStatusEGrupos(Base):
    def test_status_do_amigo_vira_codigo(self):
        casos = [
            ({"availability": "mobile"}, ("no_celular", False)),
            ({"lol": {"gameStatus": "inGame"}}, ("em_partida", False)),
            ({"lol": {"gameStatus": "championSelect"}}, ("na_selecao", False)),
            ({"lol": {"gameStatus": "inQueue"}}, ("na_fila", True)),
            ({"lol": {"gameStatus": "hosting_NORMAL"}}, ("numa_sala", True)),
            ({"lol": {"gameStatus": "spectating"}}, ("assistindo", True)),
            ({"availability": "away"}, ("ausente", True)),
            ({"availability": "dnd"}, ("ocupado", False)),
            ({"availability": "chat"}, ("disponivel", True)),
        ]
        for amigo, esperado in casos:
            with self.subTest(amigo=amigo):
                self.assertEqual(ponte._status_amigo(amigo), esperado)

    def test_filas_agrupadas_por_codigo_com_nome_do_client(self):
        def fila(i, grupo, cat="kPvP", nome=None, prio=0):
            return {"id": i, "queueAvailability": "Available", "gameSelectCategory": cat,
                    "gameSelectModeGroup": grupo, "description": nome or f"Fila {i}", "gameSelectPriority": prio}
        filas = [fila(1, "kTeamfightTactics"), fila(2, "kARAM", nome="Ranked Flex"),
                 fila(3, None, cat="kVersusAI"), fila(4, None, cat="CreateCustom"), fila(5, None, cat="kTraining"),
                 fila(6, "kSummonersRift", nome="Draft Pick"), fila(7, "kJade"), fila(8, "kAlternativeLeagueGameModes"),
                 {**fila(9, "kARAM"), "queueAvailability": "PlayerLevelUnavailable"}]
        self.lcu_falso(fixo={"/lol-game-queues/v1/queues": filas})
        saida = ponte.filas_sala()
        self.assertEqual([f["grupo"] for f in saida], [
            "summoners_rift", "aram", "rift_classico", "outros_modos", "contra_ia", "personalizada", "treino", "tft"])
        self.assertEqual({f["nome"] for f in saida if f["grupo"] in ("aram", "summoners_rift")},
                         {"Ranked Flex", "Draft Pick"})  # o nome da fila segue como o client manda
        for g in ponte.ORDEM_GRUPOS:
            self.assertRegex(g, r"^[a-z_]+$")

    def test_aviso_do_chat_manda_codigo_e_nome(self):
        msgs = [{"type": "system", "body": "joined_room", "fromPuuid": "p1", "id": "1", "timestamp": "2026-01-01T00:00:00Z"},
                {"type": "system", "body": "left_room", "fromPuuid": "p2", "id": "2", "timestamp": "2026-01-01T00:00:01Z"},
                {"type": "information", "body": "Texto do client", "id": "3", "timestamp": "2026-01-01T00:00:02Z"}]
        self.lcu_falso(get={"/lol-chat/v1/conversations/c1/messages": msgs})
        with mock.patch.dict(ponte._nomes, {"p1": ("Fulano", "BR1")}, clear=True):
            chat = ponte._chat("c1", "eu")
        self.assertEqual([(m["texto"], m.get("quem")) for m in chat],
                         [("entrou", "Fulano"), ("saiu", ""), ("Texto do client", None)])


class TestRespostas(Base):
    def cmd(self, tipo, **extra):
        return {"tipo": tipo, "de": "u1", "em": ponte.agora_ms(), **extra}

    def setUp(self):
        super().setUp()
        for alvo, nome, v in ((ponte, "conta", lambda: {"uid": "u1"}),):
            p = mock.patch.object(alvo, nome, v)
            p.start()
            self.addCleanup(p.stop)

    def test_comandos_simples_devolvem_o_codigo(self):
        esperado = {"aceitar": "partida_aceita", "recusar": "partida_recusada", "sair_fila": "saiu_fila",
                    "buscar": "fila_iniciada", "sair_sala": "saiu_sala"}
        for tipo, codigo in esperado.items():
            with self.subTest(tipo=tipo), mock.patch.object(ponte, "_lcu", lambda *a, **k: Resposta()):
                self.assertEqual(ponte.executar("c", self.cmd(tipo)), (True, codigo))

    def test_erros_do_client(self):
        with mock.patch.object(ponte, "_lcu", lambda *a, **k: Resposta(ok=False, status=500)):
            self.assertEqual(ponte.executar("c", self.cmd("aceitar")), (False, "lol_recusou"))
        with mock.patch.object(ponte, "_lcu", lambda *a, **k: None):
            self.assertEqual(ponte.executar("c", self.cmd("aceitar")), (False, "lol_fechado"))

    def test_erros_do_proprio_pc(self):
        self.assertEqual(ponte.executar("c", {"tipo": "aceitar", "de": "outra", "em": ponte.agora_ms()}),
                         (False, "comando_outra_conta"))
        self.assertEqual(ponte.executar("c", {"tipo": "aceitar", "de": "u1", "em": 1}), (False, "comando_atrasado"))
        self.assertEqual(ponte.executar("c", self.cmd("xyz")), (False, "comando_desconhecido"))
        self.assertEqual(ponte.executar("c", "nao e dict"), (False, "comando_invalido"))

    def test_chat_vazio_e_sem_sala(self):
        self.lcu_falso()
        self.assertEqual(ponte.executar("c", self.cmd("chat", texto="")), (False, "mensagem_vazia"))
        self.assertEqual(ponte.executar("c", self.cmd("dm", puuid="x", texto="oi")), (False, "amigo_nao_achado"))
        self.assertEqual(ponte.executar("c", self.cmd("convidar", quem=["p"])), (False, "amigo_nao_achado"))

    def test_mensagem_com_parametros_vai_em_p(self):
        enviados = []
        with mock.patch.object(ponte, "_db", lambda m, c, **kw: enviados.append((m, c, kw))), \
                mock.patch.object(ponte, "uid", lambda: "pc1"):
            ponte._responder("id1", True, "saiu_fila")
            ponte._responder("id2", True, ("banido", {"nome": "Ahri"}))
            ponte._responder("id3", True, ("sala_criada_e", {"depois": "convites_mandados", "n": 2}))
        r1, r2, r3 = (e[2]["json"]["resposta"] for e in enviados)
        self.assertEqual((r1["msg"], "p" in r1), ("saiu_fila", False))
        self.assertEqual((r2["msg"], r2["p"]), ("banido", {"nome": "Ahri"}))
        self.assertEqual((r3["msg"], r3["p"]), ("sala_criada_e", {"depois": "convites_mandados", "n": 2}))

    def test_trocas_e_estados(self):
        self.assertEqual(ponte.TROCA_ESTADOS["SENT"], "troca_ja_pediu")
        sess = {"myTeam": [{"cellId": 0}, {"cellId": 1}], "trades": [{"id": 5, "cellId": 1, "state": "SENT"}]}
        self.lcu_falso(get={"/lol-champ-select/v1/session": sess})
        self.assertEqual(ponte._troca("troca_aceitar", 5, 1), (False, "troca_ja_pediu"))
        self.assertEqual(ponte._troca("troca_pedir", None, 1), (False, "troca_termine_outra"))
        sess["trades"] = []
        self.assertEqual(ponte._troca("troca_pedir", None, 1), (False, "troca_inexistente"))

    def test_codigos_do_pc_existem_no_app(self):
        """Todo codigo que o PC manda tem ramo em app/lib/codigos.dart (senao o celular mostraria o codigo cru)."""
        dart = (PC.parent / "app" / "lib" / "codigos.dart").read_text(encoding="utf-8")
        no_app = set(re.findall(r"^\s+'([a-z_]+)' =>", dart, re.M))
        fonte = (PC / "ponte.py").read_text(encoding="utf-8")
        achados = set(re.findall(r'return (?:False|True), \(?"([a-z_]+)"', fonte))
        achados |= set(re.findall(r'ok, msg = False, "([a-z_]+)"', fonte))
        achados |= {v[3] for v in ponte.COMANDOS.values()} | set(ponte.TROCA_ESTADOS.values())
        achados |= {f"{g[2]}_{a[2]}" for g in ponte.GRUPOS_TROCA.values() for a in ponte.ACOES_TROCA.values()
                    if a[2] != "cancelada"} | {"pedido_cancelado"}
        achados |= {"banido", "travado"}
        achados |= {v for v in list(ponte.GRUPOS_MODO.values()) + list(ponte.GRUPOS_CATEGORIA.values())}
        achados |= {"no_celular", "em_partida", "na_selecao", "na_fila", "numa_sala", "assistindo", "ausente",
                    "ocupado", "disponivel", "sala_criada_e"}
        achados -= {"nome", "depois"}
        self.assertGreater(len(achados), 100)
        self.assertEqual(sorted(achados - no_app), [])


class TestIdioma(Base):
    def test_idioma_do_windows(self):
        casos = {0x0416: "pt", 0x0816: "pt", 0x0409: "en", 0x0809: "en", 0x0C0A: "es", 0x080A: "es", 0x040A: "es",
                 0x0411: "en", 0x0407: "en", 0: "en"}
        for langid, esperado in casos.items():
            with self.subTest(langid=hex(langid)):
                self.assertEqual(idioma.de_langid(langid), esperado)

    def test_automatico_segue_o_windows_e_manual_vale_por_cima(self):
        self.assertEqual((idioma.escolha(), idioma.atual()), ("auto", "pt"))
        with mock.patch.object(idioma, "windows", lambda: "es"):
            self.assertEqual(idioma.atual(), "es")
            self.assertEqual(idioma.definir("en"), "en")  # manual
            self.assertEqual((idioma.escolha(), idioma.atual()), ("en", "en"))
            self.assertEqual(idioma.definir("auto"), "es")
        self.assertEqual(json.loads(lcu.CONFIG.read_text(encoding="utf-8"))["idioma"], "auto")

    def test_escolha_persiste_e_preserva_o_resto_do_config(self):
        lcu.salvar_config({"abrir_com_windows": False})
        idioma.definir("es")
        cfg = lcu.config()
        self.assertEqual((cfg["idioma"], cfg["abrir_com_windows"]), ("es", False))
        with self.assertRaises(ValueError):
            idioma.definir("fr")
        self.assertEqual(idioma.atual(), "es")

    def test_textos_em_todas_as_linguas_com_as_mesmas_chaves(self):
        for lg in ("en", "es"):
            self.assertEqual(set(idioma.TEXTOS[lg]), set(idioma.TEXTOS["pt"]), lg)
        for lg, tabela in idioma.TEXTOS.items():
            for k, v in tabela.items():
                self.assertNotIn("—", v)
                self.assertNotIn("–", v)
        idioma.definir("en")
        self.assertEqual(idioma.t("menu.sair"), "Quit")
        idioma.definir("es")
        self.assertEqual(idioma.t("menu.sair"), "Salir")
        self.assertEqual(idioma.t("chave.que.nao.existe"), "chave.que.nao.existe")

    def test_erros_de_conta_no_idioma_da_janela(self):
        def post(url, json=None, timeout=None):
            return Resposta(ok=False, status=400, corpo={"error": {"message": self.erro}})
        esperado = {
            "pt": {"EMAIL_EXISTS": "Esse e-mail já tem conta. Use Entrar.", "WEAK_PASSWORD": "A senha precisa de pelo menos 6 letras.",
                   "INVALID_LOGIN_CREDENTIALS": "E-mail ou senha errados.", "XYZ": "Não deu certo. Tente de novo."},
            "en": {"EMAIL_EXISTS": "That email already has an account. Use Sign in.",
                   "WEAK_PASSWORD": "The password needs at least 6 characters.",
                   "INVALID_LOGIN_CREDENTIALS": "Wrong email or password.", "XYZ": "That didn't work. Try again."},
            "es": {"EMAIL_EXISTS": "Ese correo ya tiene cuenta. Usa Entrar.",
                   "WEAK_PASSWORD": "La contraseña necesita al menos 6 caracteres.",
                   "INVALID_LOGIN_CREDENTIALS": "Correo o contraseña incorrectos.", "XYZ": "No funcionó. Inténtalo de nuevo."},
        }
        r = Resposta(ok=False, status=400, corpo={"error": {"message": ""}})
        with mock.patch.object(ponte.requests, "post", lambda *a, **k: r):
            for lg, erros in esperado.items():
                idioma.definir(lg)
                for erro, texto in erros.items():
                    with self.subTest(lg=lg, erro=erro):
                        r._corpo = {"error": {"message": erro}}
                        r.status_code, r.ok = 400, False
                        with self.assertRaises(ValueError) as c:
                            ponte.entrar_conta("a@b.c", "123456")
                        self.assertEqual(str(c.exception), texto)
                with self.assertRaises(ValueError) as c:
                    ponte.entrar_conta("", "")
                self.assertEqual(str(c.exception), idioma.TEXTOS[lg]["conta.preencha"])


class TestLocale(Base):
    REGIAO = "/riotclient/region-locale"

    def test_locale_vem_do_client_e_fica_guardado(self):
        for loc in ("pt_BR", "en_US", "es_MX"):
            lcu._loc.update(v=None, t=0.0)
            self.lcu_falso(get={self.REGIAO: {"locale": loc, "region": "X"}})
            self.assertEqual(lcu.locale_dd(), loc)
            self.assertEqual(lcu.json_cache("locale.json"), {"locale": loc})

    def test_sem_client_usa_o_guardado_e_sem_nada_o_idioma_do_pc(self):
        self.lcu_falso()
        self.assertEqual(lcu.locale_dd(), "pt_BR")  # Windows em pt
        for lg, loc in (("en", "en_US"), ("es", "es_ES"), ("pt", "pt_BR")):
            lcu._loc.update(v=None, t=0.0)
            idioma.definir(lg)
            self.assertEqual(lcu.locale_dd(), loc)
        lcu.json_cache("locale.json", {"locale": "es_MX"})
        lcu._loc.update(v=None, t=0.0)
        self.assertEqual(lcu.locale_dd(), "es_MX")  # o que o client tinha avisado da ultima vez

    def test_locale_estranho_do_client_e_ignorado(self):
        self.lcu_falso(get={self.REGIAO: {"locale": "../../x"}})
        self.assertEqual(lcu.locale_dd(), "pt_BR")

    def test_ddragon_baixa_no_locale_e_refaz_se_ele_mudar(self):
        pedidos = []

        def baixar(url, timeout=8):
            pedidos.append(url)
            if url.endswith("versions.json"):
                return b'["16.1.1"]'
            loc = url.split("/data/")[1].split("/")[0]
            return json.dumps({"data": {"A": {"key": "1", "name": f"Ahri-{loc}", "id": "Ahri"}}}).encode()

        with mock.patch.object(lcu, "_baixar", baixar):
            self.lcu_falso(get={self.REGIAO: {"locale": "en_US"}})
            self.assertEqual(lcu.campeoes(), ([{"id": 1, "name": "Ahri-en_US", "alias": "Ahri"}], "ddragon"))
            self.assertEqual(json.loads((lcu.CACHE / "campeoes.json").read_text(encoding="utf-8"))["locale"], "en_US")
            n = len(pedidos)
            self.assertEqual(lcu.campeoes()[1], "cache")  # mesmo locale: usa o cache
            self.assertEqual(len(pedidos), n)
            lcu._loc.update(v=None, t=0.0)
            self.lcu_falso(get={self.REGIAO: {"locale": "es_MX"}})
            lst, de = lcu.campeoes()
            self.assertEqual((lst[0]["name"], de), ("Ahri-es_MX", "ddragon"))  # locale mudou: baixa de novo
            self.assertTrue(any("/es_MX/champion.json" in u for u in pedidos))
            self.assertEqual(json.loads((lcu.CACHE / "campeoes.json").read_text(encoding="utf-8"))["locale"], "es_MX")

    def test_cache_de_outro_idioma_serve_se_nao_der_pra_baixar(self):
        lcu.json_cache("campeoes.json", {"locale": "pt_BR", "campeoes": [{"id": 1, "name": "Ahri", "alias": "Ahri"}]})
        self.lcu_falso(get={self.REGIAO: {"locale": "en_US"}})
        with mock.patch.object(lcu, "_baixar", mock.Mock(side_effect=OSError("sem internet"))):
            self.assertEqual(lcu.campeoes()[1], "cache")
        # formato antigo (lista pura, sem locale) tambem entra como reserva
        lcu.json_cache("campeoes.json", [{"id": 2, "name": "Zed", "alias": "Zed"}])
        lcu._dd.clear()
        with mock.patch.object(lcu, "_baixar", mock.Mock(side_effect=OSError("sem internet"))):
            self.assertEqual(lcu.campeoes(), ([{"id": 2, "name": "Zed", "alias": "Zed"}], "cache"))

    def test_campeoes_do_client_guardam_o_locale(self):
        self.lcu_falso(get={self.REGIAO: {"locale": "es_MX"}}, fixo={
            "/lol-game-data/assets/v1/champion-summary.json": [{"id": 1, "name": "Ahri", "alias": "Ahri"}]})
        self.assertEqual(lcu.campeoes()[1], "client")
        self.assertEqual(lcu.json_cache("campeoes.json")["locale"], "es_MX")

    def test_feiticos_de_reserva_nos_tres_idiomas(self):
        self.lcu_falso()  # sem client, sem cache de feiticos
        esperado = {"pt": "Incendiar", "en": "Ignite", "es": "Ignición"}
        for lg, nome in esperado.items():
            idioma.definir(lg)
            lcu._loc.update(v=None, t=0.0)
            fb = {f["id"]: f["nome"] for f in lcu.feiticos()}
            self.assertEqual(fb[14], nome)
            self.assertEqual(len(fb), len(lcu.FEITICOS_FALLBACK))
        lcu.json_cache("locale.json", {"locale": "ko_KR"})  # locale de outra lingua: ingles
        lcu._loc.update(v=None, t=0.0)
        self.assertEqual({f["id"]: f["nome"] for f in lcu.feiticos()}[14], "Ignite")


if __name__ == "__main__":
    unittest.main()
