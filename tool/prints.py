"""Refaz os prints do README (docs/) a partir do app e da janela do PC de verdade.

    python tool/prints.py                 # compila o app e refaz todos
    python tool/prints.py pick painel     # so esses
    python tool/prints.py --skip-build    # usa o app/build/web que ja esta em disco

Flags: --skip-build, --saida <pasta> (padrao docs/), --dry-run, --no-color.
Telas: partida, pick, sala, carregamento, jogo, vitoria, painel.

Celular: o app compilado abre no modo vitrine (?vitrine=<tela>, dados de mentira, sem Firebase) num Chromium
sem janela, tela de 390x844 em 2x. partida e pick saem soltas; as outras saem em pe e deitadas na mesma moldura.
Janela do PC: pc/ui/index.html com a API do painel respondida aqui mesmo (sem conta, conectado ao LoL), no tema
escuro e no claro, na largura que a janela abre (880) e na altura que ela mesma calcula.

Precisa de: pip install playwright pillow && python -m playwright install chromium
"""
import argparse
import base64
import functools
import io
import sys
import threading
import time
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

import cli
from cli import RAIZ

TELAS_SOLTAS = ("partida", "pick")
TELAS_MOLDURA = ("sala", "carregamento", "jogo", "vitoria")
TODAS = TELAS_SOLTAS + TELAS_MOLDURA + ("painel",)

CELULAR = (390, 844)
LARGURA_PAINEL = 880  # LARGURA de ajustarJanela() em pc/ui/index.html
# depois do primeiro quadro do Flutter: as entradas animadas terminarem e as fotos do CommunityDragon chegarem
ASSENTAR_MS = 3000

# moldura dos prints em pe e deitado: 1442x952 com fundo transparente (o README mostra em 760 de largura)
MOLDURA = """<!doctype html><html><head><style>
html,body{margin:0;background:transparent}
.c{position:relative;width:1442px;height:952px}
.f{position:absolute;background:#0b0d10;border-radius:62px;padding:21px;box-sizing:border-box;
 box-shadow:0 0 0 1.5px #2a2e35 inset,0 18px 40px rgba(0,0,0,.28),0 4px 10px rgba(0,0,0,.18)}
.f img{display:block;border-radius:42px}
</style></head><body><div class="c">
<div class="f" style="left:33px;top:33px"><img src="data:image/png;base64,{P}" width="390" height="844"></div>
<div class="f" style="left:522px;top:260px"><img src="data:image/png;base64,{L}" width="844" height="390"></div>
</div></body></html>"""


class _Silencioso(SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


def servir(pasta):
    """Servidor local do build, numa porta livre qualquer, numa thread que morre com o script."""
    srv = ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(_Silencioso, directory=str(pasta)))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def tela_celular(navegador, base, tela, largura, altura):
    ctx = navegador.new_context(viewport={"width": largura, "height": altura}, device_scale_factor=2,
                                is_mobile=True, has_touch=True)
    try:
        pg = ctx.new_page()
        pg.goto(f"{base}/?vitrine={tela}")
        pg.wait_for_selector("flutter-view, flt-glass-pane", state="attached", timeout=30_000)
        pg.wait_for_load_state("networkidle")
        pg.wait_for_timeout(ASSENTAR_MS)
        return pg.screenshot()
    finally:
        ctx.close()


def moldura(navegador, em_pe, deitado):
    ctx = navegador.new_context(viewport={"width": 1442, "height": 952})
    try:
        pg = ctx.new_page()
        pg.set_content(MOLDURA.replace("{P}", base64.b64encode(em_pe).decode())
                       .replace("{L}", base64.b64encode(deitado).decode()))
        return pg.screenshot(omit_background=True)
    finally:
        ctx.close()


def painel(navegador, qr, claro):
    """Janela do PC sem o Ping rodando: o HTML e a API saem daqui, com o mesmo formato do pc/painel.py."""
    html = (RAIZ / "pc/ui/index.html").read_text(encoding="utf-8").replace("__TOKEN__", "0" * 32)
    respostas = {
        "/api/atividade": {"conectado": True, "fase": "None", "boot": 1, "erro": None},
        "/api/conta": {"conta": None, "qr": qr},
        "/api/opcoes": {"opcoes": {"abrir_com_windows": True, "atualizar_sozinho": True}, "versao": None,
                        "desinstalar": False},
    }

    def rota(r):
        caminho = "/" + r.request.url.split("/", 3)[3].split("?")[0]
        if caminho in respostas:
            return r.fulfill(json=respostas[caminho])
        if caminho == "/ping":
            return r.fulfill(body=html, content_type="text/html; charset=utf-8")
        if caminho == "/logo.ico":
            return r.fulfill(path=str(RAIZ / "pc/ping.ico"), content_type="image/x-icon")
        return r.fulfill(status=404, json={})

    ctx = navegador.new_context(viewport={"width": LARGURA_PAINEL, "height": 700}, device_scale_factor=2)
    try:
        if claro:
            ctx.add_init_script("localStorage.setItem('modo', 'claro')")
        pg = ctx.new_page()
        pg.route("http://painel.test/**", rota)
        pg.goto("http://painel.test/ping")
        pg.wait_for_load_state("networkidle")  # fontes do Google e o QR
        pg.wait_for_timeout(1000)
        # mesma conta de ajustarJanela(): a janela abre na altura do conteudo
        altura = pg.evaluate("['header', 'main', '.versao'].reduce((s, q) => s + document.querySelector(q)"
                             ".offsetHeight, 0) - 10")
        pg.set_viewport_size({"width": LARGURA_PAINEL, "height": altura})
        pg.wait_for_timeout(500)
        return pg.screenshot(), altura
    finally:
        ctx.close()


def main():
    p = argparse.ArgumentParser(description="Refaz os prints do README.")
    p.add_argument("telas", nargs="*", metavar="tela", help=", ".join(TODAS) + " (sem nenhuma: todas)")
    p.add_argument("--skip-build", action="store_true")
    p.add_argument("--saida", default=str(RAIZ / "docs"))
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--no-color", action="store_true")
    a = p.parse_args()
    if errado := [t for t in a.telas if t not in TODAS]:
        p.error(f"tela desconhecida: {', '.join(errado)}. Use: {', '.join(TODAS)}")
    telas = a.telas or list(TODAS)
    celular = [t for t in telas if t != "painel"]
    saida = RAIZ / a.saida  # absoluto continua absoluto

    cli.iniciar_console()
    cli.banner(" · ".join(["prints do README"] + (["sem build"] if a.skip_build else [])
                          + (["dry-run"] if cli.DRY else [])))
    # etapas: ferramentas, build (ou reaproveitar), celular (se pediu tela de celular), janela do PC (se pediu)
    passos = cli.Etapas(2 + bool(celular) + ("painel" in telas))
    inicio = time.time()

    t = passos.comecar("Conferindo as ferramentas")
    if not (RAIZ / "app/pubspec.yaml").is_file():
        cli.falhar("Rode da raiz do repositório: python tool/prints.py")
    try:
        from PIL import Image
        from playwright.sync_api import Error as ErroPlaywright, sync_playwright
    except ImportError as e:
        cli.falhar(f"Falta o módulo {e.name}. Instale com:\n"
                   "pip install playwright pillow\npython -m playwright install chromium")
    cli.ok(f"telas: {', '.join(telas)}", t)

    web = RAIZ / "app/build/web"
    if a.skip_build:
        t = passos.comecar("Reaproveitando o build", "app/build/web")
        if celular and not (web / "index.html").is_file() and not cli.DRY:
            cli.falhar("Não tem build em app/build/web. Rode sem --skip-build.")
        cli.ok("build em disco", t)
    else:
        t = passos.comecar("Compilando o app para web", "a primeira vez demora")
        cli.rodar(["flutter", "build", "web", "--release", "--base-href", "/"], RAIZ / "app",
                  "O build falhou. Rode flutter analyze em app/ e corrija.")
        cli.ok("build pronto", t)

    gerados = []
    if cli.DRY:
        if celular:
            passos.comecar("Tirando os prints do celular", "vitrine em 390x844")
        if "painel" in telas:
            passos.comecar("Tirando os prints da janela do PC", "escuro e claro")
        cli.resumo("Nada gerado", saida.as_posix(), [("telas", ", ".join(telas))])
        return

    saida.mkdir(parents=True, exist_ok=True)
    srv = servir(web)
    base = f"http://127.0.0.1:{srv.server_address[1]}"
    try:
        with sync_playwright() as pw:
            try:
                navegador = pw.chromium.launch()
            except ErroPlaywright:
                cli.falhar("O Chromium do Playwright não está instalado. Rode:\npython -m playwright install chromium")

            if celular:
                t = passos.comecar("Tirando os prints do celular", "vitrine em 390x844")
                for tela in celular:
                    with cli.Girinho(tela):
                        em_pe = tela_celular(navegador, base, tela, *CELULAR)
                        if tela in TELAS_SOLTAS:
                            arq = saida / f"{tela}.jpg"
                            Image.open(io.BytesIO(em_pe)).convert("RGB").resize((600, 1298), Image.LANCZOS).save(
                                arq, "JPEG", quality=90)
                        else:
                            deitado = tela_celular(navegador, base, tela, *reversed(CELULAR))
                            arq = saida / f"{tela}-celular.webp"
                            Image.open(io.BytesIO(moldura(navegador, em_pe, deitado))).save(
                                arq, "WEBP", quality=90, method=6)
                    gerados.append(arq)
                    cli.ok(arq.name)
                cli.ok(f"{len(celular)} telas", t)

            if "painel" in telas:
                t = passos.comecar("Tirando os prints da janela do PC", "escuro e claro")
                sys.path.insert(0, str(RAIZ / "pc"))
                import ponte  # o QR de verdade, com o endereco do app
                qr = ponte.qr_app()
                for claro, nome in ((False, "painel.jpg"), (True, "painel-claro.jpg")):
                    png, altura = painel(navegador, qr, claro)
                    arq = saida / nome
                    # 2x reduzido pra 1,25x: nitido no README (620 de largura) sem pesar
                    Image.open(io.BytesIO(png)).convert("RGB").resize(
                        (round(LARGURA_PAINEL * 1.25), round(altura * 1.25)), Image.LANCZOS).save(
                        arq, "JPEG", quality=90)
                    gerados.append(arq)
                    cli.ok(nome)
                cli.ok("2 temas", t)
            navegador.close()
    finally:
        srv.shutdown()

    peso = sum(f.stat().st_size for f in gerados) / 1024
    cli.resumo("Prints prontos", saida.as_posix(), [
        ("arquivos", len(gerados)),
        ("peso", f"{peso:.0f} KB"),
        ("tempo total", cli._dur(time.time() - inicio)),
        ("conferir", "git diff --stat docs"),
    ])


if __name__ == "__main__":
    main()
