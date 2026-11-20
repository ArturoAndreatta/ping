import 'l10n/txt.dart';

// Textos que o PC manda como código estável (snake_case) e o app traduz. O PC antigo ainda manda a frase em
// português: código desconhecido volta como veio, então o app novo serve aos dois. Gerado a partir da tabela de
// códigos do contrato (ver CLAUDE.md); chave nova no PC pede ramo novo aqui e nas três ARB.

String _p(Map? p, String k) => '${p?[k] ?? ''}';

/// Mensagem da resposta de um comando (`resposta.msg`, com os parâmetros em `resposta.p`).
String textoMsg(Txt t, String codigo, [Map? p]) => switch (codigo) {
  'sala_criada_e' => '${t.rspSalaCriada}. ${textoMsg(t, _p(p, 'depois'), p)}',
  'lol_fechado' => t.rspLolFechado,
  'lol_recusou' => t.rspLolRecusou,
  'conversa_nao_achada' => t.rspConversaNaoAchada,
  'lol_recusou_mensagem' => t.rspLolRecusouMensagem,
  'mensagem_vazia' => t.rspMensagemVazia,
  'amigo_nao_achado' => t.rspAmigoNaoAchado,
  'modo_invalido' => t.rspModoInvalido,
  'sala_agora_nao' => t.rspSalaAgoraNao,
  'modo_fechado' => t.rspModoFechado,
  'so_lider_modo' => t.rspSoLiderModo,
  'lol_recusou_modo' => t.rspLolRecusouModo,
  'sala_criada' => t.rspSalaCriada,
  'ninguem_escolhido' => t.rspNinguemEscolhido,
  'fora_da_sala' => t.rspForaDaSala,
  'lol_recusou_convite' => t.rspLolRecusouConvite,
  'convite_mandado' => t.rspConviteMandado,
  'convites_mandados' => t.rspConvitesMandados(int.tryParse(_p(p, 'n')) ?? 0),
  'posicao_invalida' => t.rspPosicaoInvalida,
  'modo_sem_posicao' => t.rspModoSemPosicao,
  'posicao_segunda_nao' => t.rspPosicaoSegundaNao,
  'lol_recusou_posicao' => t.rspLolRecusouPosicao,
  'skin_indisponivel' => t.rspSkinIndisponivel,
  'lol_recusou_skin' => t.rspLolRecusouSkin,
  'feitico_invalido' => t.rspFeiticoInvalido,
  'fora_da_selecao' => t.rspForaDaSelecao,
  'arena_so_ordem' => t.rspArenaSoOrdem,
  'feitico_modo' => t.rspFeiticoModo,
  'golpear_selva' => t.rspGolpearSelva,
  'lol_recusou_feitico' => t.rspLolRecusouFeitico,
  'pagina_nao_achada' => t.rspPaginaNaoAchada,
  'lol_recusou_pagina' => t.rspLolRecusouPagina,
  'pagina_incompleta' => t.rspPaginaIncompleta,
  'pagina_nao_edita' => t.rspPaginaNaoEdita,
  'pagina_sem_espaco' => t.rspPaginaSemEspaco,
  'pagina_salva' => t.rspPaginaSalva,
  'comando_invalido' => t.rspComandoInvalido,
  'comando_outra_conta' => t.rspComandoOutraConta,
  'comando_atrasado' => t.rspComandoAtrasado,
  'comando_desconhecido' => t.rspComandoDesconhecido,
  'lol_fechando_espere' => t.rspLolFechandoEspere,
  'lol_ja_aberto' => t.rspLolJaAberto,
  'lol_ja_abrindo' => t.rspLolJaAbrindo,
  'abrindo_lol' => t.rspAbrindoLol,
  'lol_nao_achado' => t.rspLolNaoAchado,
  'lol_nao_abriu' => t.rspLolNaoAbriu,
  'fechar_em_partida' => t.rspFecharEmPartida,
  'lol_ja_fechando' => t.rspLolJaFechando,
  'lol_ja_fechado' => t.rspLolJaFechado,
  'fechando_lol' => t.rspFechandoLol,
  'sair_selecao_nao' => t.rspSairSelecaoNao,
  'saiu_selecao' => t.rspSaiuSelecao,
  'troca_inexistente' => t.rspTrocaInexistente,
  'troca_termine_outra' => t.rspTrocaTermineOutra,
  'troca_aliado_ocupado' => t.rspTrocaAliadoOcupado,
  'troca_agora_nao' => t.rspTrocaAgoraNao,
  'troca_ja_pediu' => t.rspTrocaJaPediu,
  'troca_ele_pediu' => t.rspTrocaElePediu,
  'troca_invalida' => t.rspTrocaInvalida,
  'troca_tarde' => t.rspTrocaTarde,
  'troca_ordem_nao' => t.rspTrocaOrdemNao,
  'lol_recusou_troca' => t.rspLolRecusouTroca,
  'pedido_cancelado' => t.rspPedidoCancelado,
  'troca_pedida' => t.rspTrocaPedida,
  'troca_aceita' => t.rspTrocaAceita,
  'troca_recusada' => t.rspTrocaRecusada,
  'troca_pos_pedida' => t.rspTrocaPosPedida,
  'troca_pos_aceita' => t.rspTrocaPosAceita,
  'troca_pos_recusada' => t.rspTrocaPosRecusada,
  'troca_ordem_pedida' => t.rspTrocaOrdemPedida,
  'troca_ordem_aceita' => t.rspTrocaOrdemAceita,
  'troca_ordem_recusada' => t.rspTrocaOrdemRecusada,
  'campeao_invalido' => t.rspCampeaoInvalido,
  'cartas_fecharam' => t.rspCartasFecharam,
  'ja_escolheu' => t.rspJaEscolheu,
  'carta_invalida' => t.rspCartaInvalida,
  'lol_negou_carta' => t.rspLolNegouCarta(_p(p, 'nome')),
  'lol_recusou_carta' => t.rspLolRecusouCarta,
  'carta_escolheu' => t.rspCartaEscolheu(_p(p, 'nome')),
  'carta_escolhida' => t.rspCartaEscolhida,
  'banco_saiu' => t.rspBancoSaiu,
  'banco_termine_troca' => t.rspBancoTermineTroca,
  'banco_ainda_nao' => t.rspBancoAindaNao,
  'lol_negou_banco' => t.rspLolNegouBanco(_p(p, 'nome')),
  'lol_recusou_banco' => t.rspLolRecusouBanco,
  'banco_pegou' => t.rspBancoPegou(_p(p, 'nome')),
  'banco_pegou_sem' => t.rspBancoPegouSem,
  'aram_sorteado' => t.rspAramSorteado,
  'escolha_nao_abriu' => t.rspEscolhaNaoAbriu,
  'nao_sua_vez' => t.rspNaoSuaVez,
  'campeao_banido' => t.rspCampeaoBanido,
  'lol_recusou_campeao' => t.rspLolRecusouCampeao,
  'banido' => t.rspBanido(_p(p, 'nome')),
  'travado' => t.rspTravado(_p(p, 'nome')),
  'sem_chat' => t.rspSemChat,
  'muitos_comandos' => t.rspMuitosComandos,
  'erro_no_pc' => t.rspErroNoPc,
  'partida_aceita' => t.rspPartidaAceita,
  'partida_recusada' => t.rspPartidaRecusada,
  'saiu_fila' => t.rspSaiuFila,
  'fila_iniciada' => t.rspFilaIniciada,
  'saiu_sala' => t.rspSaiuSala,
  _ => codigo,
};

/// Status do amigo (`amigo.status`): código novo ou a frase antiga em português.
String textoStatus(Txt t, String codigo) => switch (codigo) {
  'no_celular' => t.stNoCelular,
  'No celular' => t.stNoCelular,
  'em_partida' => t.stEmPartida,
  'Em partida' => t.stEmPartida,
  'na_selecao' => t.stNaSelecao,
  'Na seleção' => t.stNaSelecao,
  'na_fila' => t.stNaFila,
  'Na fila' => t.stNaFila,
  'numa_sala' => t.stNumaSala,
  'Numa sala' => t.stNumaSala,
  'assistindo' => t.stAssistindo,
  'Assistindo' => t.stAssistindo,
  'ausente' => t.stAusente,
  'Ausente' => t.stAusente,
  'ocupado' => t.stOcupado,
  'Ocupado' => t.stOcupado,
  'disponivel' => t.stDisponivel,
  'Disponível' => t.stDisponivel,
  _ => codigo,
};

/// Amigo disponível (cor verde), com o código novo ou o texto antigo.
bool statusDisponivel(String s) => s == 'disponivel' || s == 'Disponível';

/// Amigo ausente ou ocupado (cor de aviso), com o código novo ou o texto antigo.
bool statusAusente(String s) =>
    s == 'ausente' || s == 'ocupado' || s == 'Ausente' || s == 'Ocupado';

/// Grupo de modos da sala (`fila.grupo`): código novo ou o nome antigo em português.
String textoGrupo(Txt t, String codigo) => switch (codigo) {
  'summoners_rift' => t.grSummonersRift,
  'Summoner\'s Rift' => t.grSummonersRift,
  'aram' => t.grAram,
  'rift_classico' => t.grRiftClassico,
  'Rift Clássico' => t.grRiftClassico,
  'outros_modos' => t.grOutrosModos,
  'Outros modos' => t.grOutrosModos,
  'contra_ia' => t.grContraIa,
  'Contra a IA' => t.grContraIa,
  'personalizada' => t.grPersonalizada,
  'Personalizada' => t.grPersonalizada,
  'treino' => t.grTreino,
  'Treino' => t.grTreino,
  'tft' => t.grTft,
  _ => codigo,
};

/// Texto de um aviso do chat. Do PC novo vem `texto` = código e `quem` = nome; do antigo vem a frase pronta.
String textoAvisoChat(Txt t, Map m) {
  final quem = m['quem'];
  if (quem == null) return '${m['texto']}';
  final nome = '$quem'.isEmpty ? t.avAlguem : '$quem';
  return switch ('${m['texto']}') {
    'entrou' => t.avEntrou(nome),
    'saiu' => t.avSaiu(nome),
    _ => '${m['texto']}',
  };
}
