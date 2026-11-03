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
