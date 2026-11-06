// Confere a criptografia e o VAPID contra implementações independentes (http_ece e o crypto do Node).
import assert from "node:assert/strict";
import nodeCrypto from "node:crypto";
import ece from "http_ece";
import { b64url, deB64url, criptografar, gerarVapid, mensagem } from "../src/webpush.js";

// 1) aes128gcm: o "navegador" (ECDH do Node) consegue abrir o que o Worker cifrou
const navegador = nodeCrypto.createECDH("prime256v1");
navegador.generateKeys();
const auth = nodeCrypto.randomBytes(16);
const inscricao = { endpoint: "https://exemplo.test/x", keys: { p256dh: b64url(navegador.getPublicKey()), auth: b64url(auth) } };
const texto = mensagem({ titulo: "Partida encontrada", texto: "Toque pra aceitar.", link: "https://ping-celular.web.app/" });
const cifrado = await criptografar(inscricao, texto);
const aberto = ece.decrypt(Buffer.from(cifrado), { version: "aes128gcm", privateKey: navegador, authSecret: auth });
assert.equal(aberto.toString("utf8"), texto);
const j = JSON.parse(aberto.toString("utf8"));
assert.equal(j.web_push, 8030);
assert.equal(j.notification.title, "Partida encontrada");
console.log("ok: aes128gcm abre do outro lado");

// 2) VAPID: a assinatura ES256 confere com a chave pública
const vapid = await gerarVapid();
assert.equal(deB64url(vapid.publica).length, 65);
const { enviar } = await import("../src/webpush.js");
let pedido;
globalThis.fetch = async (url, op) => {
  pedido = { url, op };
  return new Response("", { status: 201 });
};
const r = await enviar(inscricao, texto, { ...vapid, assunto: "mailto:teste@exemplo.test" });
assert.equal(r.ok, true);
const m = /^vapid t=([^,]+), k=(.+)$/.exec(pedido.op.headers.Authorization);
assert.ok(m, "cabeçalho vapid");
assert.equal(m[2], vapid.publica);
const [cab, corpo, ass] = m[1].split(".");
const claims = JSON.parse(Buffer.from(deB64url(corpo)).toString());
assert.equal(claims.aud, "https://exemplo.test");
assert.equal(claims.sub, "mailto:teste@exemplo.test");
const chavePub = nodeCrypto.createPublicKey({ key: { kty: "EC", crv: "P-256", x: vapid.privada.x, y: vapid.privada.y }, format: "jwk" });
assert.ok(nodeCrypto.verify("sha256", Buffer.from(`${cab}.${corpo}`), { key: chavePub, dsaEncoding: "ieee-p1363" }, Buffer.from(deB64url(ass))));
assert.equal(pedido.op.headers["Content-Encoding"], "aes128gcm");
console.log("ok: VAPID assinado e conferido");

// 3) aviso sem link: sai com o link do app (sem navigate o iPhone descarta calado)
const { contexto } = await import("../src/index.js");
const enviados = [];
globalThis.fetch = async (url, op) => {
  if (String(url).includes("firebaseio") || String(url).includes(":9")) {
    // "fora": endereço que não é de serviço de push nenhum, nunca recebe POST do Worker
    return new Response(JSON.stringify({ ap: { ...inscricao, endpoint: "https://fcm.googleapis.com/fcm/send/x" }, fora: inscricao }), { status: 200 });
  }
  enviados.push(op.body);
  return new Response("", { status: 201 });
};
const env = { FIREBASE_PROJETO: "ping-celular", VAPID_PUBLICA: vapid.publica, VAPID_PRIVADA: JSON.stringify(vapid.privada), VAPID_ASSUNTO: "https://x.test", EMULADOR_RTDB: "http://127.0.0.1:9" };
const ctx = contexto(env, () => {});
assert.equal(await ctx.enviarPara("u", { titulo: "T", texto: "x", link: undefined }), 1);
assert.equal(enviados.length, 1);
const aberto2 = ece.decrypt(Buffer.from(enviados[0]), { version: "aes128gcm", privateKey: navegador, authSecret: auth });
assert.equal(JSON.parse(aberto2.toString()).notification.navigate, "https://ping-celular.web.app/");
console.log("ok: aviso sem link sai com o link do app");
