// Disparador das notificações push do Ping (Cloudflare Worker, plano grátis).
//
// - POST /aviso: o PC de um usuário pede um aviso, provando quem é com o ID token do Firebase (sem segredo no
//   PC). O ping.js decide pra quem vai e segura enxurrada.
// - GET /: saúde, pra conferir que está no ar.
//
// Inscrições ficam no Firebase em push/<uid>/<aparelho> (o app grava, ninguém lê; o Worker lê como
// administrador pela conta de serviço, segredo FIREBASE_CONTA).

import { enviar, mensagem, servicoConhecido } from "./webpush.js";
import { rtdb } from "./firebase.js";
import { verificarIdToken } from "./idtoken.js";
import ping from "./ping.js";

function config(env) {
  const projeto = env.FIREBASE_PROJETO;
  return {
    projeto,
    rtdbUrl: `https://${projeto}-default-rtdb.firebaseio.com`,
    link: env.LINK_APP || `https://${projeto}.web.app/`,
  };
}

/** Banco e "mandar pra um usuário" (todos os aparelhos dele). `filtro(inscricao)` escolhe os aparelhos. */
export function contexto(env, log = console.log) {
  const cfg = config(env);
  const conta = env.FIREBASE_CONTA ? JSON.parse(env.FIREBASE_CONTA) : null;
  const db = rtdb({ url: cfg.rtdbUrl, conta, emulador: env.EMULADOR_RTDB });
  const vapid = { publica: env.VAPID_PUBLICA, privada: JSON.parse(env.VAPID_PRIVADA), assunto: env.VAPID_ASSUNTO };
  async function enviarPara(uid, aviso, filtro = () => true) {
    const aparelhos = (await db.ler(`push/${uid}`)) || {};
    // link vazio cai no do app: sem `navigate` o iPhone descarta o aviso em silêncio
    const conteudo = mensagem({ ...aviso, link: aviso.link || cfg.link });
    let entregues = 0;
    for (const [id, insc] of Object.entries(aparelhos)) {
      if (!servicoConhecido(insc?.endpoint) || !insc?.keys || !filtro(insc)) continue;
      try {
        const r = await enviar(insc, conteudo, vapid, { topico: aviso.topico, ttl: aviso.ttl });
        if (r.ok) entregues++;
        else if (r.expirada) await db.apagar(`push/${uid}/${id}`); // desinstalou ou revogou
        else log(`push recusado ${r.status}: ${r.erro}`);
      } catch (e) {
        log(`erro no push: ${e.message}`);
      }
    }
    return entregues;
  }
  return { db, env, log, enviarPara, projeto: cfg.projeto };
}

const CORPO_MAX = 4096; // o PC manda só tipo e uns poucos textos curtos

function json(corpo, status = 200) {
  return new Response(JSON.stringify(corpo), { status, headers: { "Content-Type": "application/json" } });
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (req.method === "GET" && url.pathname === "/") {
      return json({ ok: true, projeto: env.FIREBASE_PROJETO, vapid: Boolean(env.VAPID_PRIVADA) });
    }
    if (req.method === "POST" && url.pathname === "/aviso") {
      let corpo;
      try {
        const texto = await req.text();
        if (texto.length > CORPO_MAX) return json({ erro: "corpo grande demais" }, 413);
        corpo = JSON.parse(texto);
      } catch {
        return json({ erro: "corpo inválido" }, 400);
      }
      let uid;
      try {
        const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
        uid = await verificarIdToken(token, env.FIREBASE_PROJETO, { emulador: Boolean(env.EMULADOR_AUTH) });
      } catch (e) {
        return json({ erro: `sem permissão: ${e.message}` }, 401);
      }
      const r = await ping.aviso(contexto(env), uid, corpo || {});
      return json(r, r.status || 200);
    }
    return json({ erro: "não encontrado" }, 404);
  },
};
