// Confere o texto dos avisos e quem recebe, sem rede.
import assert from "node:assert/strict";
import { TIPOS, montar, aparelhoQuer } from "../src/ping.js";

assert.equal(montar("partida").titulo, "Partida encontrada");
assert.equal(montar("vez", { acao: "pick" }).titulo, "Sua vez de escolher");
assert.equal(montar("vez", { acao: "outra" }), null);
assert.equal(montar("troca", { tipo: "pos", quem: "Fulano" }).texto, "Fulano quer trocar de posição com você.");
assert.equal(montar("mensagem", { texto: "oi" }), null); // sem puuid nem sala
assert.ok(montar("mensagem", { texto: "oi", puuid: "x" }).topico.startsWith("dm-"));
assert.equal(montar("fim", { resultado: "vitoria", campeao: "Ahri", kda: "5/1/7" }).texto, "Ahri 5/1/7");
assert.equal(montar("desconhecido"), null);
console.log("ok: textos");

const insc = { pc: "pc1", tipos: { fim: true }, sempre: false };
assert.equal(aparelhoQuer(insc, "partida", "pc1", false), true);
assert.equal(aparelhoQuer(insc, "partida", "pc2", false), false); // outro PC
assert.equal(aparelhoQuer(insc, "partida", "pc1", true), false); // você no PC
assert.equal(aparelhoQuer(insc, "fim", "pc1", false), true); // ligado na mão
assert.equal(aparelhoQuer(insc, "resumo", "pc1", false), false); // desligado por padrão
assert.equal(aparelhoQuer({ ...insc, sempre: true }, "partida", "pc1", true), true);
assert.ok(Object.values(TIPOS).every((t) => t.gap > 0 && t.ttl > 0));
console.log("ok: quem recebe");

const { servicoConhecido } = await import("../src/webpush.js");
assert.ok(servicoConhecido("https://fcm.googleapis.com/fcm/send/abc"));
assert.ok(servicoConhecido("https://web.push.apple.com/QK2"));
assert.ok(servicoConhecido("https://wns2-bl2p.notify.windows.com/w/?token=x"));
assert.ok(servicoConhecido("https://updates.push.services.mozilla.com/wpush/v2/x"));
assert.equal(servicoConhecido("https://exemplo.com/fcm.googleapis.com/"), false);
assert.equal(servicoConhecido("https://fcm.googleapis.com.exemplo.com/x"), false);
assert.equal(servicoConhecido("http://fcm.googleapis.com/x"), false);
assert.equal(servicoConhecido(undefined), false);
console.log("ok: só serviços de push conhecidos");

// PC sem conta confirmada: não grava nada no banco nem manda push
const gravados = [];
const dbFalso = (dados) => ({
  ler: async (c) => dados[c] ?? null,
  chaves: async (c) => (dados[c] ? Object.keys(dados[c]) : []),
  gravar: async (c, v) => gravados.push([c, v]),
});
const ping = (await import("../src/ping.js")).default;
const enviarPara = async () => 1;
let r = await ping.aviso({ db: dbFalso({}), enviarPara, log() {} }, "anon", { tipo: "partida" });
assert.deepEqual([r.entregues, gravados.length], [0, 0]);
r = await ping.aviso({ db: dbFalso({ "pcs/pc1/conta": "u1" }), enviarPara, log() {} }, "pc1", { tipo: "partida" });
assert.deepEqual([r.entregues, gravados.length], [0, 0]); // conta não confirmou o PC
r = await ping.aviso({ db: dbFalso({ "pcs/pc1/conta": "u1", "contas/u1/pcs/pc1": { desde: 1 } }), enviarPara, log() {} },
  "pc1", { tipo: "partida" });
assert.deepEqual([r.entregues, gravados.length], [1, 1]);
console.log("ok: PC sem conta não grava nada");
