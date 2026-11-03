// Confere o ID token do Firebase Auth (o mesmo que o app ou o PC usa no banco) sem SDK: assinatura RS256
// com as chaves públicas do Google, emissor e público do projeto, validade. Devolve o uid (`sub`).
// Assim quem chama o Worker não precisa de segredo nenhum: prova quem é com o login dele.

const CHAVES_URL = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
const te = new TextEncoder();
let _chaves = { exp: 0, mapa: {} }; // as chaves do Google trocam de tempos em tempos; o cache segue o max-age

// sem "=" no fim: o atob aceita base64 sem preenchimento
function deB64url(s) {
  const b = atob(s.replace(/-/g, "+").replace(/_/g, "/").replace(/=+$/, ""));
  return Uint8Array.from(b, (c) => c.charCodeAt(0));
}

async function chaves(forcar = false) {
  if (!forcar && Date.now() < _chaves.exp) return _chaves.mapa;
  const r = await fetch(CHAVES_URL);
  if (!r.ok) throw new Error(`chaves do Google: ${r.status}`);
  const idade = Number((r.headers.get("Cache-Control") || "").match(/max-age=(\d+)/)?.[1] || 3600);
  const mapa = {};
  for (const k of (await r.json()).keys || []) {
    mapa[k.kid] = await crypto.subtle.importKey("jwk", k, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  }
  _chaves = { exp: Date.now() + idade * 1000, mapa };
  return mapa;
}

/**
 * uid do token, ou erro. `emulador` = true só nos testes: o emulador do Auth assina com `alg: none`, e aí
 * só confere o resto. Nunca ligar em produção (o `EMULADOR_AUTH` só existe no `.dev.vars` do teste).
 */
export async function verificarIdToken(token, projeto, { emulador = false } = {}) {
  const partes = (token || "").split(".");
  if (partes.length !== 3) throw new Error("token mal formado");
  const cab = JSON.parse(new TextDecoder().decode(deB64url(partes[0])));
  const corpo = JSON.parse(new TextDecoder().decode(deB64url(partes[1])));
  if (emulador && cab.alg === "none") {
    // sem assinatura: só o emulador
  } else {
    if (cab.alg !== "RS256" || !cab.kid) throw new Error("algoritmo inválido");
    let chave = (await chaves())[cab.kid];
    if (!chave) chave = (await chaves(true))[cab.kid]; // chave nova do Google
    if (!chave) throw new Error("chave desconhecida");
    const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", chave, deB64url(partes[2]), te.encode(`${partes[0]}.${partes[1]}`));
    if (!ok) throw new Error("assinatura inválida");
  }
  const agora = Math.floor(Date.now() / 1000);
  if (corpo.aud !== projeto || corpo.iss !== `https://securetoken.google.com/${projeto}`) throw new Error("projeto errado");
  if (!(corpo.exp > agora) || !(corpo.iat <= agora + 60) || !(corpo.auth_time <= agora + 60)) throw new Error("token vencido");
  if (typeof corpo.sub !== "string" || !corpo.sub || corpo.sub.length > 128) throw new Error("sem uid");
  return corpo.sub;
}
