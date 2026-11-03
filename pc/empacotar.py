"""
Gera o que vai no release do GitHub (so no Windows: o .exe sai pelo IExpress, que vem no Windows):

- dist/Ping-<versao>.exe: instalador. Por dentro e um zip portatil (o Python vem na pasta python/) embrulhado
  pelo IExpress: extrai em AppData/Local/Ping e roda o instalar.ps1. Abrir o .exe de uma versao nova atualiza
  por cima e mantem a config.
- dist/ping-<versao>.zip: so os arquivos do programa (sem Python), pra atualizacao sozinha (atualizar.py)
- dist/versao.json: versao, zip, sha256 e hash das bibliotecas, assinado com Ed25519 (assinatura.py)

Uso: python empacotar.py <versao>   (ex.: 1.2.0; o workflow de release passa a tag)
     python empacotar.py travar     (regrava o requirements.lock)

Python 3.12 oficial pra Windows (pacote "python" do NuGet, sha256 fixo) + bibliotecas compiladas pra Windows
(pip, versao e hash travados no requirements.lock).
"""
import hashlib
import json
import os
import shutil
import subprocess
import urllib.request
import zipfile
from pathlib import Path

import sys

import atualizar

BASE = Path(__file__).resolve().parent
CACHE = BASE / "dist" / "cache"
PYTHON = "3.12.10"
NUGET = f"https://api.nuget.org/v3-flatcontainer/python/{PYTHON}/python.{PYTHON}.nupkg"
# sha256 do nupkg (conferido com o packageHash SHA512 do catalogo do NuGet). Trocar o PYTHON = trocar isso junto
NUGET_SHA256 = "0eb85c2dfccccf1b17352de4c397f69194035b7d37149eacc16f1147d93de3b8"
# bibliotecas do .exe com versao e hash travados (gerado por: python empacotar.py travar)
LOCK = "requirements.lock"

# arquivos do programa (o resto da pasta e de desenvolvimento ou gerado: cache, dist, log, config)
APP = ("ping.pyw", "ponte.py", "lcu.py", "painel.py", "avisos.py", "hoje.py", "servidor.py", "atualizar.py",
       "assinatura.py", "inicio_windows.py", "qrcodegen.py", "requirements.txt", "ping.ico", "ui/index.html")
# pedacos do Python que o app nao usa
PY_FORA = ("include/", "libs/", "Scripts/", "Lib/ensurepip/", "Lib/venv/", "Lib/lib2to3/", "Lib/pydoc_data/",
           "Lib/idlelib/", "Lib/tkinter/", "Lib/turtledemo/", "Lib/test/", "Lib/site-packages/")
# dependencias so de Linux que o pip baixa junto
WHEEL_FORA = ("python_xlib", "evdev")


SEM_JANELA = getattr(subprocess, "CREATE_NO_WINDOW", 0)  # rodando pelo pythonw nao pisca console


def _sha256(arquivo):
    h = hashlib.sha256()
    with open(arquivo, "rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            h.update(bloco)
    return h.hexdigest()


def baixar(url, destino, sha256):
    """Baixa uma vez e guarda em cache, mas sempre confere o sha256 (cache adulterado ou corrompido baixa de novo)."""
    if destino.exists() and _sha256(destino) == sha256:
        return destino
    destino.parent.mkdir(parents=True, exist_ok=True)
    tmp = destino.with_suffix(".tmp")  # download cortado nao fica passando por arquivo bom
    with urllib.request.urlopen(url, timeout=120) as r:
        tmp.write_bytes(r.read())
    if _sha256(tmp) != sha256:
        tmp.unlink(missing_ok=True)
        raise RuntimeError(f"download de {destino.name} nao bate com o sha256 esperado")
    tmp.replace(destino)
    return destino


def _pip_download(pasta, *args):
    r = subprocess.run([sys.executable, "-m", "pip", "download", "-q", "--disable-pip-version-check",
                        "--no-cache-dir", "--platform", "win_amd64", "--python-version", PYTHON.rsplit(".", 1)[0],
                        "--only-binary=:all:", "-d", str(pasta), *args],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", creationflags=SEM_JANELA)
    if r.returncode != 0:
        err = (r.stderr or r.stdout or "").strip().splitlines()
        raise RuntimeError("pip falhou: " + (err[-1] if err else "sem detalhe"))


def wheels():
    """Bibliotecas exatamente como no requirements.lock: versao fixa, hash conferido pelo pip, sem dependencia extra,
    numa pasta limpa a cada build (nada sobrando de build antigo entra no .exe)."""
    pasta = CACHE / f"wheels-{PYTHON}"
    shutil.rmtree(pasta, ignore_errors=True)
    _pip_download(pasta, "--no-deps", "--require-hashes", "-r", str(BASE / LOCK))
    return sorted(pasta.glob("*.whl"))


def travar():
    """Regrava o requirements.lock a partir dos requirements (rodar quando quiser subir as bibliotecas).
    Resolve pro Windows/Python do .exe e confere cada wheel com o sha256 que o PyPI publica."""
    import tempfile
    reqs = []
    for f in atualizar.DEPS:
        reqs += [x.strip() for x in (BASE / f).read_text(encoding="utf-8").splitlines() if x.strip() and not x.startswith("#")]
    linhas = []
    with tempfile.TemporaryDirectory() as tmp:
        _pip_download(tmp, *reqs)
        for w in sorted(Path(tmp).glob("*.whl")):
            if w.name.lower().startswith(WHEEL_FORA):
                continue
            nome, versao = w.name.split("-")[:2]
            with urllib.request.urlopen(f"https://pypi.org/pypi/{nome}/{versao}/json", timeout=60) as r:
                arquivos = {a["filename"]: a["digests"]["sha256"] for a in json.load(r)["urls"]}
            sha = _sha256(w)
            if arquivos.get(w.name) != sha:
                raise RuntimeError(f"{w.name} nao bate com o sha256 do PyPI")
            linhas.append(f"{nome.replace('_', '-').lower()}=={versao} \\\n    --hash=sha256:{sha}")
    (BASE / LOCK).write_text(
        f"# gerado por: python empacotar.py travar (Windows x64, Python {PYTHON.rsplit('.', 1)[0]}); nao editar a mao\n"
        + "\n".join(linhas) + "\n", encoding="utf-8")
    return linhas


DIST = BASE / "dist"


def montar_exe(zip_, destino):
    """Embrulha o zip + instalador/ num .exe com o IExpress do Windows."""
    iexpress = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32" / "iexpress.exe"
    if not iexpress.exists():
        raise RuntimeError("Sem o IExpress: o .exe so sai no Windows")
    pasta = zip_.parent
    for f in ("setup.cmd", "setup.ps1"):
        shutil.copy2(BASE / "instalador" / f, pasta / f)
    saida = pasta / "Ping.exe"  # nome sem espaco pro IExpress; renomeia no fim
    saida.unlink(missing_ok=True)
    sed = pasta / "ping.sed"
    sed.write_text(f"""[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName={saida}
FriendlyName=Ping
AppLaunched=cmd /c setup.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
FILE0="{zip_.name}"
FILE1="setup.cmd"
FILE2="setup.ps1"
[SourceFiles]
SourceFiles0={pasta}\\
[SourceFiles0]
%FILE0%=
%FILE1%=
%FILE2%=
""", encoding="mbcs" if os.name == "nt" else "utf-8")
    subprocess.run([str(iexpress), "/N", "/Q", str(sed)], cwd=pasta, timeout=600, creationflags=SEM_JANELA)
    if not saida.exists() or saida.stat().st_size < zip_.stat().st_size:
        raise RuntimeError("IExpress nao gerou o .exe")
    trocar_icone(saida, BASE / "ping.ico")
    saida.replace(destino)


RT_ICON, RT_GROUP_ICON, RT_MANIFEST = 3, 14, 24


def _k32():
    import ctypes
    from ctypes import wintypes as w
    k = ctypes.WinDLL("kernel32", use_last_error=True)
    V = ctypes.c_void_p
    k.LoadLibraryExW.restype = w.HMODULE
    k.LoadLibraryExW.argtypes = [w.LPCWSTR, w.HANDLE, w.DWORD]
    k.FreeLibrary.argtypes = [w.HMODULE]
    k.FindResourceExW.restype = V
    k.FindResourceExW.argtypes = [w.HMODULE, V, V, w.WORD]
    k.LoadResource.restype = V
    k.LoadResource.argtypes = [w.HMODULE, V]
    k.LockResource.restype = V
    k.LockResource.argtypes = [V]
    k.SizeofResource.restype = w.DWORD
    k.SizeofResource.argtypes = [w.HMODULE, V]
    k.BeginUpdateResourceW.restype = w.HANDLE
    k.BeginUpdateResourceW.argtypes = [w.LPCWSTR, w.BOOL]
    k.UpdateResourceW.restype = w.BOOL
    k.UpdateResourceW.argtypes = [w.HANDLE, V, V, w.WORD, V, w.DWORD]
    k.EndUpdateResourceW.restype = w.BOOL
    k.EndUpdateResourceW.argtypes = [w.HANDLE, w.BOOL]
    return ctypes, k


def _id(ctypes, x):
    """Nome de recurso: numero (MAKEINTRESOURCE) ou texto."""
    return ctypes.cast(ctypes.c_wchar_p(x), ctypes.c_void_p) if isinstance(x, str) else ctypes.c_void_p(x)


def _buf(ctypes, b):
    return ctypes.create_string_buffer(b, len(b))


def recursos(exe):
    """{tipo: [(nome, idioma, bytes)]} dos icones e do manifesto de um .exe."""
    ctypes, k = _k32()
    h = k.LoadLibraryExW(str(exe), None, 0x2)  # LOAD_LIBRARY_AS_DATAFILE
    if not h:
        raise RuntimeError(f"nao abriu o .exe ({ctypes.get_last_error()})")
    achados = {RT_ICON: [], RT_GROUP_ICON: [], RT_MANIFEST: []}
    LANG_CB = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ushort, ctypes.c_void_p)
    NOME_CB = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p)
    try:
        for tipo in achados:
            nomes = []
            cb = NOME_CB(lambda _h, _t, n, _p: nomes.append(n if n >> 16 == 0 else ctypes.wstring_at(n)) or True)
            ctypes.windll.kernel32.EnumResourceNamesW(ctypes.c_void_p(h), ctypes.c_void_p(tipo), cb, None)
            for n in nomes:
                langs = []
                lcb = LANG_CB(lambda _h, _t, _n, l, _p: langs.append(l) or True)
                ctypes.windll.kernel32.EnumResourceLanguagesW(ctypes.c_void_p(h), ctypes.c_void_p(tipo), _id(ctypes, n), lcb, None)
                for l in langs:
                    r = k.FindResourceExW(h, ctypes.c_void_p(tipo), _id(ctypes, n), l)
                    tam = k.SizeofResource(h, r)
                    achados[tipo].append((n, l, ctypes.string_at(k.LockResource(k.LoadResource(h, r)), tam)))
    finally:
        k.FreeLibrary(h)
    return achados


def trocar_icone(exe, ico):
    """Icone do Ping no lugar do generico do IExpress, e o .exe abre sem pedir administrador."""
    import re
    import struct
    ctypes, k = _k32()
    antes = recursos(exe)
    dados = Path(ico).read_bytes()
    _, _, n = struct.unpack_from("<HHH", dados)
    imagens, grupo = [], struct.pack("<HHH", 0, 1, n)
    for i in range(n):
        w_, h_, cores, _, planos, bits, tam, ofs = struct.unpack_from("<BBBBHHII", dados, 6 + 16 * i)
        imagens.append(dados[ofs:ofs + tam])
        grupo += struct.pack("<BBBBHHIH", w_, h_, cores, 0, planos or 1, bits, tam, i + 1)
    lang = antes[RT_GROUP_ICON][0][1] if antes[RT_GROUP_ICON] else 1033
    manifesto = [(nm, l, re.sub(rb'(requestedExecutionLevel[^>]*level=)"[^"]*"', rb'\1"asInvoker"', b))
                 for nm, l, b in antes[RT_MANIFEST]]

    hu = k.BeginUpdateResourceW(str(exe), False)
    if not hu:
        raise RuntimeError(f"nao deu pra mexer no .exe ({ctypes.get_last_error()})")
    ok = True
    for tipo in (RT_GROUP_ICON, RT_ICON):  # tira os icones do IExpress
        for nm, l, _ in antes[tipo]:
            ok &= bool(k.UpdateResourceW(hu, ctypes.c_void_p(tipo), _id(ctypes, nm), l, None, 0))
    for i, img in enumerate(imagens, 1):
        ok &= bool(k.UpdateResourceW(hu, ctypes.c_void_p(RT_ICON), ctypes.c_void_p(i), lang, _buf(ctypes, img), len(img)))
    ok &= bool(k.UpdateResourceW(hu, ctypes.c_void_p(RT_GROUP_ICON), ctypes.c_void_p(1), lang, _buf(ctypes, grupo), len(grupo)))
    for nm, l, b in manifesto:
        ok &= bool(k.UpdateResourceW(hu, ctypes.c_void_p(RT_MANIFEST), _id(ctypes, nm), l, _buf(ctypes, b), len(b)))
    if not ok:
        k.EndUpdateResourceW(hu, True)  # descarta
        raise RuntimeError(f"nao deu pra trocar o icone ({ctypes.get_last_error()})")
    if not k.EndUpdateResourceW(hu, False):
        raise RuntimeError(f"nao deu pra gravar o icone ({ctypes.get_last_error()})")
    depois = recursos(exe)
    if len(depois[RT_GROUP_ICON]) != 1 or len(depois[RT_ICON]) != n:
        raise RuntimeError("icone nao ficou no .exe")


def conteudo_app(versao):
    """Arquivos do programa como (origem, nome na pasta Ping). O .exe e o zip de atualizacao levam isso."""
    app = [(BASE / nome, nome) for nome in APP]
    # instalador, desinstalador e "Como usar" na raiz da pasta
    app += [(f, f.name) for f in sorted((BASE / "portatil").iterdir()) if f.is_file()]
    faltando = [n for o, n in app if not o.is_file()]
    if faltando:
        raise RuntimeError("faltando: " + ", ".join(faltando))
    return app


def zip_atualizacao(app, versao):
    """ping-<versao>.zip (so o programa) e o versao.json assinado."""
    import assinatura
    nome = f"ping-{versao}.zip"
    destino = DIST / nome
    with zipfile.ZipFile(destino, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for origem, rel in app:
            z.write(origem, rel)
        z.writestr("versao.txt", versao + "\n")
    info = {"versao": versao, "arquivo": nome, "sha256": _sha256(destino), "deps": atualizar.hash_deps()}
    (DIST / "versao.json").write_text(json.dumps(assinatura.assinar_info(info), indent=1) + "\n", encoding="utf-8")
    return destino


def gerar(versao, etapa=print):
    """Monta o .exe, o zip de atualizacao e o versao.json. etapa(texto) recebe cada passo."""
    if not atualizar.num(versao):
        raise RuntimeError(f"versao invalida: {versao!r} (use 1.2.3)")
    etapa("Lendo os arquivos")
    app = conteudo_app(versao)
    DIST.mkdir(exist_ok=True)
    etapa("Zip de atualizacao e versao.json assinado")
    zip_atualizacao(app, versao)
    etapa(f"Baixando o Python {PYTHON}")
    nupkg = baixar(NUGET, CACHE / f"python-{PYTHON}.nupkg", NUGET_SHA256)
    etapa("Baixando as bibliotecas")
    whls = wheels()

    etapa("Montando os arquivos")
    obra = CACHE / "exe"
    shutil.rmtree(obra, ignore_errors=True)
    obra.mkdir(parents=True)
    zip_ = obra / "Ping.zip"
    with zipfile.ZipFile(zip_, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for origem, nome in app:
            z.write(origem, f"Ping/{nome}")
        z.writestr("Ping/versao.txt", versao + "\n")
        # Python portatil
        with zipfile.ZipFile(nupkg) as pk:
            for i in pk.infolist():
                if not i.filename.startswith("tools/") or i.is_dir():
                    continue
                rel = i.filename[len("tools/"):]
                if rel.startswith(PY_FORA):
                    continue
                z.writestr(f"Ping/python/{rel}", pk.read(i))
        # bibliotecas (wheel e um zip: extrair em site-packages e instalar)
        for w in whls:
            with zipfile.ZipFile(w) as wz:
                for i in wz.infolist():
                    if not i.is_dir():
                        z.writestr(f"Ping/python/Lib/site-packages/{i.filename}", wz.read(i))
    etapa("Gerando o .exe")
    exe = DIST / f"Ping-{versao}.exe"
    montar_exe(zip_, exe)
    shutil.rmtree(obra, ignore_errors=True)
    return {"exe": str(exe), "versao": versao, "mb": round(exe.stat().st_size / 1e6, 1)}


def main():
    if sys.argv[1:] == ["travar"]:
        try:
            linhas = travar()
        except RuntimeError as e:
            raise SystemExit(str(e))
        print(f"{LOCK}: {len(linhas)} bibliotecas travadas")
        return
    if len(sys.argv) != 2:
        raise SystemExit("uso: python empacotar.py <versao> | travar")
    try:
        r = gerar(sys.argv[1].lstrip("v"))
    except RuntimeError as e:
        raise SystemExit(str(e))
    print(f"{r['exe']}  (v{r['versao']}, Python {PYTHON} portatil, {r['mb']} MB)")


if __name__ == "__main__":
    main()
