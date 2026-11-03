"""
Assinatura da atualizacao (Ed25519, RFC 8032, em Python puro: nenhuma biblioteca a mais no instalador).

- O workflow de release assina o versao.json com a chave privada (fora do repo: arquivo em ~/.ping ou o secret
  PING_ASSINATURA do GitHub Actions)
- atualizar.py so aceita versao.json com assinatura valida de uma das CHAVES abaixo. O sha256 do zip esta dentro
  do que e assinado, entao quem conseguisse trocar um arquivo do release nao conseguiria trocar o pacote

Trocar de chave: por a nova em CHAVES, publicar assinado com a velha, e so depois tirar a velha.
Gerar uma chave nova: python assinatura.py gerar (grava a privada em ~/.ping e mostra a publica).
Quem publica o proprio Ping (fork) gera a propria chave e troca CHAVES.
"""
import hashlib
import json
import os
import sys
from pathlib import Path

# chaves publicas aceitas (hex). A privada nunca entra no repo
CHAVES = ("226bb5c9636d8429c21f3b3060522ab832769b679c9f6850ab1501e7e771a0e4",)

ARQUIVO_CHAVE = Path.home() / ".ping" / "assinatura.key"
VAR_CHAVE = "PING_ASSINATURA"

# ---------------- Ed25519 (RFC 8032, secao 5.1) ----------------
_P = 2 ** 255 - 19
_L = 2 ** 252 + 27742317777372353535851937790883648493
_D = -121665 * pow(121666, _P - 2, _P) % _P
_I = pow(2, (_P - 1) // 4, _P)  # raiz quadrada de -1


def _h(m):
    return int.from_bytes(hashlib.sha512(m).digest(), "little")


def _soma(a, b):
    x1, y1, z1, t1 = a
    x2, y2, z2, t2 = b
    A = (y1 - x1) * (y2 - x2) % _P
    B = (y1 + x1) * (y2 + x2) % _P
    C = 2 * t1 * t2 * _D % _P
    D = 2 * z1 * z2 % _P
    E, F, G, H = B - A, D - C, D + C, B + A
    return (E * F % _P, G * H % _P, F * G % _P, E * H % _P)


def _vezes(s, p):
    q = (0, 1, 1, 0)  # neutro
    while s:
        if s & 1:
            q = _soma(q, p)
        p = _soma(p, p)
        s >>= 1
    return q


def _igual(a, b):
    x1, y1, z1, _ = a
    x2, y2, z2, _ = b
    return (x1 * z2 - x2 * z1) % _P == 0 and (y1 * z2 - y2 * z1) % _P == 0


def _x(y, sinal):
    if y >= _P:
        return None
    x2 = (y * y - 1) * pow(_D * y * y + 1, _P - 2, _P) % _P
    if x2 == 0:
        return None if sinal else 0
    x = pow(x2, (_P + 3) // 8, _P)
    if (x * x - x2) % _P:
        x = x * _I % _P
    if (x * x - x2) % _P:
        return None
    if (x & 1) != sinal:
        x = _P - x
    return x


_GY = 4 * pow(5, _P - 2, _P) % _P
_GX = _x(_GY, 0)
_G = (_GX, _GY, 1, _GX * _GY % _P)


def _codificar(p):
    x, y, z, _ = p
    zi = pow(z, _P - 2, _P)
    x, y = x * zi % _P, y * zi % _P
    return int.to_bytes(y | ((x & 1) << 255), 32, "little")


def _decodificar(b):
    if len(b) != 32:
        return None
    y = int.from_bytes(b, "little")
    sinal = y >> 255
    y &= (1 << 255) - 1
    x = _x(y, sinal)
    return None if x is None else (x, y, 1, x * y % _P)


def _expandir(semente):
    h = hashlib.sha512(semente).digest()
    a = int.from_bytes(h[:32], "little")
    a &= (1 << 254) - 8
    a |= 1 << 254
    return a, h[32:]


def publica(semente):
    a, _ = _expandir(semente)
    return _codificar(_vezes(a, _G))


def assinar(semente, msg):
    a, prefixo = _expandir(semente)
    A = _codificar(_vezes(a, _G))
    r = _h(prefixo + msg) % _L
    R = _codificar(_vezes(r, _G))
    s = (r + _h(R + A + msg) * a) % _L
    return R + int.to_bytes(s, 32, "little")


def conferir(chave, msg, assinatura):
    """True so com assinatura Ed25519 valida (chave e assinatura em bytes)."""
    if len(chave) != 32 or len(assinatura) != 64:
        return False
    A = _decodificar(chave)
    R = _decodificar(assinatura[:32])
    if A is None or R is None:
        return False
    s = int.from_bytes(assinatura[32:], "little")
    if s >= _L:
        return False
    k = _h(assinatura[:32] + chave + msg) % _L
    return _igual(_vezes(s, _G), _soma(R, _vezes(k, A)))


# ---------------- versao.json ----------------

def _texto(info):
    """Bytes assinados: o versao.json sem a assinatura, com as chaves em ordem e sem espaco."""
    corpo = {k: v for k, v in info.items() if k != "assinatura"}
    return json.dumps(corpo, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii")


def _semente():
    txt = os.environ.get(VAR_CHAVE) or ""
    if not txt:
        try:
            txt = ARQUIVO_CHAVE.read_text(encoding="ascii")
        except OSError:
            raise RuntimeError(f"sem chave de assinatura: crie com 'python assinatura.py gerar' ou defina {VAR_CHAVE}")
    try:
        semente = bytes.fromhex(txt.strip())
    except ValueError:
        semente = b""
    if len(semente) != 32:
        raise RuntimeError("chave de assinatura invalida (esperava 64 caracteres hex)")
    return semente


def assinar_info(info, semente=None):
    """Devolve o versao.json com o campo assinatura. A chave tem que estar em CHAVES (senao ninguem aceitaria)."""
    semente = semente or _semente()
    if publica(semente).hex() not in CHAVES:
        raise RuntimeError("a chave de assinatura nao e nenhuma das CHAVES do assinatura.py")
    return dict(info, assinatura=assinar(semente, _texto(info)).hex())


def info_valida(info):
    """True se o versao.json foi assinado por uma das CHAVES."""
    try:
        sig = bytes.fromhex(info.get("assinatura") or "")
        msg = _texto(info)
    except (ValueError, TypeError, AttributeError):
        return False
    for c in CHAVES:
        try:
            if conferir(bytes.fromhex(c), msg, sig):
                return True
        except ValueError:
            continue
    return False


def gerar_chave():
    if ARQUIVO_CHAVE.exists():
        raise SystemExit(f"ja existe {ARQUIVO_CHAVE}: apague antes se quiser mesmo trocar")
    semente = os.urandom(32)
    ARQUIVO_CHAVE.parent.mkdir(parents=True, exist_ok=True)
    ARQUIVO_CHAVE.write_text(semente.hex(), encoding="ascii")
    print(f"privada em {ARQUIVO_CHAVE} (guarde uma copia; sem ela quem instalou precisa do .exe novo)")
    print(f"publica (vai em CHAVES): {publica(semente).hex()}")


if __name__ == "__main__":
    if sys.argv[1:] == ["gerar"]:
        gerar_chave()
    else:
        raise SystemExit("uso: python assinatura.py gerar")
