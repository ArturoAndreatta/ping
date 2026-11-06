// Avisos do Ping: o PC (login anônimo dele) pede um aviso na hora (partida encontrada, sua vez...).
// Vai só pros celulares da conta do PC (conta que confirmou o PC) E que escolheram ouvir esse PC (`pc` na
// inscrição, que só a conta do celular grava): um PC não consegue avisar o celular de outra pessoa nem
// apontando a conta dele pra conta dela. O texto é montado aqui (o PC só manda o tipo e os dados).

/**
 * Tipos que o PC pode pedir. `padrao` = ligado num aparelho que ainda não escolheu; `gap` = intervalo mínimo
 * (ms) entre dois do mesmo tipo pro mesmo PC (por `chave`, quando tem: amigo da mensagem, quem convidou);
 * `ttl` = segundos até o serviço de push descartar (partida achada há 1 min já não serve). A mesma lista
 * (nomes e padrões) está no app (`app/lib/avisos.dart`).
 */
export const TIPOS = {
  fila: { padrao: true, gap: 15_000, ttl: 60 },
  partida: { padrao: true, gap: 20_000, ttl: 30 },
  vez: { padrao: true, gap: 8_000, ttl: 30 },
  troca: { padrao: true, gap: 10_000, ttl: 30 },
  convite: { padrao: true, gap: 15_000, ttl: 120 },
  mensagem: { padrao: true, gap: 20_000, ttl: 3600 },
  lol_pronto: { padrao: true, gap: 60_000, ttl: 600 },
  fim: { padrao: false, gap: 60_000, ttl: 3600 },
  resumo: { padrao: false, gap: 3_600_000, ttl: 86400 },
};
export const POR_HORA = 60; // total de avisos por PC numa hora (mais que isso é defeito ou abuso)

/** Texto curto vindo do PC: só texto, sem quebra de linha, cortado. */
function txt(v, max = 60) {
  if (typeof v !== "string" && typeof v !== "number") return "";
  return String(v).replace(/\s+/g, " ").trim().slice(0, max);
}

/** Chave curta e segura pra nome de nó do banco (puuid, Riot ID). */
function resumo(v) {
  let h = 0x811c9dc5;
  for (const c of String(v)) h = Math.imul(h ^ c.codePointAt(0), 16777619) >>> 0;
  return h.toString(36);
}

/** Título e texto de cada tipo. null = dados inválidos. */
export function montar(tipo, d = {}) {
  const quem = txt(d.quem, 40) || "Alguém";
  switch (tipo) {
    // o iPhone já põe "from Ping" entre o título e o texto: nesses o título basta, sem texto
    case "fila": {
      const fila = txt(d.fila, 40);
      return { titulo: fila ? `Na fila: ${fila}` : "Você entrou na fila", texto: "" };
    }
    case "partida":
      return { titulo: "Partida encontrada", texto: "" };
    case "vez": {
      if (d.acao !== "pick" && d.acao !== "ban") return null;
      return { titulo: d.acao === "pick" ? "Sua vez de escolher" : "Sua vez de banir", texto: "" };
    }
    case "troca": {
      const o = { troca: "trocar de campeão", pos: "trocar de posição", ordem: "trocar a ordem de escolha" }[d.tipo];
      if (!o) return null;
      return { titulo: "Pedido de troca", texto: `${quem} quer ${o} com você.` };
    }
    case "convite":
      return { titulo: "Convite pra sala", texto: `${quem} chamou você.`, chave: resumo(quem) };
    case "mensagem": {
      const texto = txt(d.texto, 160);
      if (!texto) return null;
      // chat da sala: sem puuid, o amigo é pelo nick
      if (d.sala === true) {
        const chave = resumo(`sala-${quem}`);
        return { titulo: `Mensagem de ${quem}`, texto, chave, topico: `sala-${chave}` };
      }
      if (!d.puuid) return null;
      const chave = resumo(d.puuid);
      return { titulo: `Mensagem de ${quem}`, texto, chave, topico: `dm-${chave}` };
    }
    case "lol_pronto":
      return { titulo: "LoL aberto", texto: "Pronto pra jogar." };
    case "fim": {
      const r = { vitoria: "Vitória!", derrota: "Derrota", remake: "Remake" }[d.resultado];
      if (!r) return null;
      const linha = [txt(d.campeao, 30), txt(d.kda, 20)].filter(Boolean).join(" ");
      return { titulo: r, texto: linha || "A partida terminou." };
    }
    case "resumo": {
      const texto = txt(d.texto, 200);
      return texto ? { titulo: "Resumo do dia", texto } : null;
    }
  }
  return null;
}

/** Aparelho quer esse aviso? (`pc`, `tipos` e `sempre` gravados pelo próprio aparelho junto da inscrição) */
export function aparelhoQuer(insc, tipo, pc, perto) {
  if (insc.pc !== pc) return false;
  const t = insc.tipos?.[tipo];
  if (t === false || (t !== true && !TIPOS[tipo].padrao)) return false;
  return !perto || insc.sempre === true;
}

export default {
  id: "ping",

  /** POST /aviso do PC: { tipo, dados, perto }. `pc` = uid do token (já conferido). */
  async aviso({ db, enviarPara, log }, pc, { tipo, dados, perto }) {
    const def = Object.hasOwn(TIPOS, tipo) ? TIPOS[tipo] : null;
    if (!def) return { status: 400, erro: "tipo desconhecido" };
    const msg = montar(tipo, dados && typeof dados === "object" ? dados : {});
    if (!msg) return { status: 400, erro: "dados inválidos" };
    // destinatário: a conta do PC, só se a conta confirmou o PC (o PC sozinho não consegue gravar isso). PC sem
    // conta confirmada para aqui, sem gravar nada: login anônimo de qualquer um não enche o banco
    const conta = await db.ler(`pcs/${pc}/conta`);
    if (typeof conta !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(conta)) return { ok: true, entregues: 0 };
    if (!(await db.chaves(`contas/${conta}/pcs/${pc}`)).length) return { ok: true, entregues: 0 };
    const estado = await db.ler(`push_estado/limite/${pc}`);
    // contra enxurrada: intervalo por tipo (e por amigo/convite) e teto por hora
    const agora = Date.now();
    const chaveLimite = msg.chave ? `${tipo}_${msg.chave}` : tipo;
    const ultimo = estado?.[chaveLimite] || 0;
    const hora = estado?.hora && agora - estado.hora.inicio < 3_600_000 ? estado.hora : { inicio: agora, n: 0 };
    if (agora - ultimo < def.gap || hora.n >= POR_HORA) return { status: 429, erro: "muitos avisos seguidos" };
    const aviso = { titulo: msg.titulo, texto: msg.texto, topico: msg.topico, ttl: def.ttl };
    const entregues = await enviarPara(conta, aviso, (insc) => aparelhoQuer(insc, tipo, pc, perto === true));
    // o intervalo só começa a contar quando chegou em alguém (você no PC não gasta o próximo aviso);
    // o teto por hora conta todo pedido. Guarda só o que ainda conta (as chaves por amigo cresceriam)
    const novo = { hora: { inicio: hora.inicio, n: hora.n + 1 } };
    for (const [k, v] of Object.entries(estado || {})) {
      if (k !== "hora" && typeof v === "number" && agora - v < 3_600_000) novo[k] = v;
    }
    if (entregues) novo[chaveLimite] = agora;
    await db.gravar(`push_estado/limite/${pc}`, novo);
    log(`[ping] aviso ${tipo} de ${pc}: ${entregues} aparelho(s)`);
    return { ok: true, entregues };
  },
};
