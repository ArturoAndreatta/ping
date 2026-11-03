// Acesso de administrador ao Firebase de cada projeto pela conta de serviço (JSON guardado como segredo
// do Worker). Passa por cima das regras, então só o Worker tem isso: nunca vai pro app nem pro repositório.

import { b64url } from "./webpush.js";

const te = new TextEncoder();
const ESCOPOS = [
  "https://www.googleapis.com/auth/firebase.database",
  "https://www.googleapis.com/auth/userinfo.email",
  "https://www.googleapis.com/auth/datastore",
].join(" ");

const _tokens = new Map(); // por conta de serviço, enquanto vale (assinar RS256 gasta CPU)

function pemParaDer(pem) {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

async function token(conta) {
  const agora = Math.floor(Date.now() / 1000);
  const salvo = _tokens.get(conta.client_email);
  if (salvo && salvo.exp - agora > 300) return salvo.valor;
  const cab = b64url(te.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const corpo = b64url(te.encode(JSON.stringify({
    iss: conta.client_email, scope: ESCOPOS, aud: "https://oauth2.googleapis.com/token", iat: agora, exp: agora + 3600,
  })));
  const chave = await crypto.subtle.importKey(
    "pkcs8", pemParaDer(conta.private_key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const ass = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", chave, te.encode(`${cab}.${corpo}`));
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${cab}.${corpo}.${b64url(ass)}` }),
  });
  if (!r.ok) throw new Error(`token do Google recusado (${r.status}): ${await r.text()}`);
  const j = await r.json();
  _tokens.set(conta.client_email, { valor: j.access_token, exp: agora + (j.expires_in || 3600) });
  return j.access_token;
}

/**
 * Realtime Database. `url` = https://<projeto>-default-rtdb.firebaseio.com. Com `emulador` (testes), usa a
 * URL dele e o token "owner", que o emulador aceita como administrador.
 */
export function rtdb({ url, conta, emulador }) {
  const base = emulador || url;
  const ns = emulador ? `?ns=${new URL(url).hostname.split(".")[0]}` : "";
  async function chamar(caminho, metodo = "GET", corpo, extra = "") {
    const tk = emulador ? "owner" : await token(conta);
    const params = [ns.slice(1), extra].filter(Boolean).join("&");
    const r = await fetch(`${base}/${caminho.replace(/^\/+/, "")}.json${params ? "?" + params : ""}`, {
      method: metodo,
      headers: { Authorization: `Bearer ${tk}`, "Content-Type": "application/json" },
      body: corpo === undefined ? undefined : JSON.stringify(corpo),
    });
    if (!r.ok) throw new Error(`RTDB ${metodo} ${caminho}: ${r.status} ${await r.text()}`);
    return r.json();
  }
  return {
    ler: (c) => chamar(c),
    /** Só as chaves do nó (shallow): barato pra conferir quem é novo. */
    chaves: async (c) => Object.keys((await chamar(c, "GET", undefined, "shallow=true")) || {}),
    gravar: (c, v) => chamar(c, "PUT", v),
    mudar: (c, v) => chamar(c, "PATCH", v),
    apagar: (c) => chamar(c, "DELETE"),
  };
}
