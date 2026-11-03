// Web Push padrão (RFC 8030) com VAPID (RFC 8292) e conteúdo criptografado aes128gcm (RFC 8291),
// só com a WebCrypto: roda igual no Worker da Cloudflare e no Node (testes).

const te = new TextEncoder();

export function b64url(bytes) {
  let s = "";
  for (const b of new Uint8Array(bytes)) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function deB64url(txt) {
  const s = atob(txt.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((txt.length + 3) % 4));
  return Uint8Array.from(s, (c) => c.charCodeAt(0));
}

function juntar(...partes) {
  const total = partes.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(total);
  let i = 0;
  for (const p of partes) {
    out.set(p, i);
    i += p.length;
  }
  return out;
}

async function hkdf(salt, ikm, info, tamanho) {
  const chave = await crypto.subtle.importKey("raw", ikm, "HKDF", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "HKDF", hash: "SHA-256", salt, info }, chave, tamanho * 8);
  return new Uint8Array(bits);
}

/** Par de chaves VAPID novo: { publica (base64url, 65 bytes, vai no app), privada (JWK, fica no segredo) }. */
export async function gerarVapid() {
  const par = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const publica = new Uint8Array(await crypto.subtle.exportKey("raw", par.publicKey));
  const privada = await crypto.subtle.exportKey("jwk", par.privateKey);
  return { publica: b64url(publica), privada };
}

const _vapid = new Map(); // JWT reaproveitado por origem enquanto vale (cada assinatura gasta CPU)

async function cabecalhoVapid(endpoint, vapid) {
  const aud = new URL(endpoint).origin;
  const agora = Math.floor(Date.now() / 1000);
  const salvo = _vapid.get(aud);
  if (salvo && salvo.exp - agora > 3600) return salvo.valor;
  const exp = agora + 12 * 3600;
  const cab = b64url(te.encode(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const corpo = b64url(te.encode(JSON.stringify({ aud, exp, sub: vapid.assunto })));
  const chave = await crypto.subtle.importKey("jwk", vapid.privada, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const assinatura = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, chave, te.encode(`${cab}.${corpo}`));
  const valor = `vapid t=${cab}.${corpo}.${b64url(assinatura)}, k=${vapid.publica}`;
  _vapid.set(aud, { exp, valor });
  return valor;
}

/** Criptografa o conteúdo pra uma inscrição ({ endpoint, keys: { p256dh, auth } }). Registro único, aes128gcm. */
export async function criptografar(inscricao, texto) {
  const uaPublica = deB64url(inscricao.keys.p256dh);
  const segredo = deB64url(inscricao.keys.auth);
  const efemera = await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"]);
  const asPublica = new Uint8Array(await crypto.subtle.exportKey("raw", efemera.publicKey));
  const uaChave = await crypto.subtle.importKey("raw", uaPublica, { name: "ECDH", namedCurve: "P-256" }, false, []);
  const compartilhado = new Uint8Array(
    await crypto.subtle.deriveBits({ name: "ECDH", public: uaChave }, efemera.privateKey, 256),
  );
  const ikm = await hkdf(segredo, compartilhado, juntar(te.encode("WebPush: info\0"), uaPublica, asPublica), 32);
  const sal = crypto.getRandomValues(new Uint8Array(16));
  const cek = await hkdf(sal, ikm, te.encode("Content-Encoding: aes128gcm\0"), 16);
  const nonce = await hkdf(sal, ikm, te.encode("Content-Encoding: nonce\0"), 12);
  const chave = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["encrypt"]);
  const claro = juntar(te.encode(texto), new Uint8Array([2])); // 0x02: último (e único) registro
  const cifrado = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, chave, claro));
  const rs = 4096;
  const cabecalho = juntar(sal, new Uint8Array([rs >>> 24, (rs >>> 16) & 255, (rs >>> 8) & 255, rs & 255, 65]), asPublica);
  return juntar(cabecalho, cifrado);
}

/**
 * Conteúdo no formato declarativo do Safari (iOS 18.4+ mostra sem service worker). Os outros navegadores
 * recebem o mesmo JSON e o service worker do app mostra (ver push-sw.js da skill).
 */
export function mensagem({ titulo, texto, link, selo }) {
  const notification = { title: titulo, body: texto || "", navigate: link, lang: "pt-BR", dir: "ltr" };
  if (selo != null) notification.app_badge = String(selo);
  return JSON.stringify({ web_push: 8030, notification });
}

/**
 * Manda um push. Devolve { ok, status, expirada }: expirada = a inscrição morreu (404/410) e deve ser apagada.
 * vapid = { publica, privada (JWK), assunto ("mailto:...") }.
 */
export async function enviar(inscricao, conteudo, vapid, { ttl = 86400, urgencia = "high", topico } = {}) {
  const corpo = await criptografar(inscricao, conteudo);
  const cab = {
    Authorization: await cabecalhoVapid(inscricao.endpoint, vapid),
    "Content-Encoding": "aes128gcm",
    "Content-Type": "application/octet-stream",
    TTL: String(ttl),
    Urgency: urgencia,
  };
  if (topico) cab.Topic = topico; // mesmo tópico substitui a mensagem ainda não entregue
  const r = await fetch(inscricao.endpoint, { method: "POST", headers: cab, body: corpo });
  return { ok: r.ok, status: r.status, expirada: r.status === 404 || r.status === 410, erro: r.ok ? null : await r.text() };
}
