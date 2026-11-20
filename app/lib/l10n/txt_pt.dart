// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'txt.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class TxtPt extends Txt {
  TxtPt([String locale = 'pt']) : super(locale);

  @override
  String get pagTema => 'Tema';

  @override
  String get temaAparencia => 'Aparência';

  @override
  String get temaTexto =>
      'As cores do app. O painel do PC tem os mesmos temas.';

  @override
  String get modoEscuro => 'Escuro';

  @override
  String get modoClaro => 'Claro';

  @override
  String modoSemantica(String nome) {
    return 'Modo $nome';
  }

  @override
  String temaSemantica(String nome) {
    return 'Tema $nome';
  }

  @override
  String get temaClient => 'Client';

  @override
  String get temaBilgewater => 'Águas de Sentina';

  @override
  String get temaSombras => 'Ilha das Sombras';

  @override
  String get temaBandopolis => 'Bandópolis';

  @override
  String get temaVazio => 'Vazio';

  @override
  String get idiomaTitulo => 'Idioma';

  @override
  String get idiomaCabecalho => 'Idioma';

  @override
  String get idiomaTexto => 'Automático segue o idioma do aparelho.';

  @override
  String get idiomaAutomatico => 'Automático';

  @override
  String temaResumo(String regiao, String modo) {
    return '$regiao, $modo';
  }

  @override
  String get abaAoVivo => 'Ao vivo';

  @override
  String get abaHoje => 'Hoje';

  @override
  String get abaMais => 'Mais';

  @override
  String get abasSemantica => 'Abas';

  @override
  String get hojeMinutos => 'Minutos';

  @override
  String get hojeHoras => 'Horas';

  @override
  String get hojeVazioTitulo => 'Nenhuma partida hoje';

  @override
  String get hojeVazioTexto =>
      'Jogue uma partida e o resumo do dia aparece aqui.';

  @override
  String get hojeSoRemakes => 'Só remakes até agora.';

  @override
  String get hojeTitulo => 'Hoje';

  @override
  String get hojeWinrate => 'Winrate';

  @override
  String hojeSiglaV(int n) {
    return '${n}V';
  }

  @override
  String hojeSiglaD(int n) {
    return '${n}D';
  }

  @override
  String get hojePartidas => 'Partidas';

  @override
  String get hojeMvp => 'MVP do dia';

  @override
  String hojeMvpVitorias(int v, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      v,
      locale: localeName,
      other: '$v vitórias',
      one: '1 vitória',
    );
    return '$_temp0 em $n';
  }

  @override
  String get hojePartidasTitulo => 'Partidas';

  @override
  String get hojeRemake => 'Remake';

  @override
  String get resVitoria => 'Vitória';

  @override
  String get resDerrota => 'Derrota';

  @override
  String get maisCelular => 'Este celular';

  @override
  String get maisAvisos => 'Avisos';

  @override
  String get maisAvisosAtivo => 'Chegam mesmo com o app fechado.';

  @override
  String get maisAvisosInativo =>
      'Partida encontrada, sua vez e mais, no celular.';

  @override
  String get maisTema => 'Tema';

  @override
  String get maisSons => 'Sons';

  @override
  String get maisSonsTexto => 'Os sons do client quando algo acontece.';

  @override
  String get voltar => 'Voltar';

  @override
  String get versaoNova => 'Versão nova!';

  @override
  String get versaoNovaTexto => 'Atualize antes de qualquer ação.';

  @override
  String get versaoBaixando => 'Baixando a versão nova';

  @override
  String get versaoAtualizar => 'Atualizar agora';

  @override
  String get x => 'Atualizar agora';

  @override
  String get aberturaRiot => 'Abrindo o Riot Client';

  @override
  String get aberturaLeague => 'Iniciando o LoL';

  @override
  String get aberturaUx => 'Carregando o client';

  @override
  String get aberturaPronto => 'Quase pronto';

  @override
  String get aberturaTitulo => 'Abrindo o LoL';

  @override
  String get aberturaLogin => 'Entre na sua conta no PC, se ele pedir.';

  @override
  String get aberturaPronto2 => 'Pronto';

  @override
  String get aberturaEsperandoLogin => 'Esperando o login';

  @override
  String get aberturaAberto => 'LoL aberto';

  @override
  String get aberturaQuaseLa => 'Quase lá';

  @override
  String aberturaFaltam(int s) {
    return 'Faltam ~${s}s';
  }

  @override
  String get aberturaEstimado => 'Tempo estimado: ainda aprendendo este PC.';

  @override
  String get posTop => 'Topo';

  @override
  String get posJungle => 'Selva';

  @override
  String get posMiddle => 'Meio';

  @override
  String get posBottom => 'Atirador';

  @override
  String get posUtility => 'Suporte';

  @override
  String get posFill => 'Qualquer';

  @override
  String get escolher => 'Escolher';

  @override
  String get posPrimeiraSem => 'Primeira posição';

  @override
  String get posSegundaSem => 'Segunda posição';

  @override
  String get posPrimeira => 'Primeira';

  @override
  String get posSegunda => 'Segunda';

  @override
  String get posSua => 'Sua posição';

  @override
  String get cartasTitulo => 'Escolha seu campeão';

  @override
  String get cartasTexto => 'Toque numa carta';

  @override
  String get cartasEscolher => 'Escolher carta';

  @override
  String cartasEscolherNome(String nome) {
    return 'Escolher $nome';
  }

  @override
  String get cartasSorte => 'Sorte';

  @override
  String get feiticoD => 'Feitiço D';

  @override
  String get feiticoF => 'Feitiço F';

  @override
  String get feiticosTitulo => 'Feitiços';

  @override
  String get banir => 'Banir';

  @override
  String get travar => 'Travar';

  @override
  String get escolhaBuscar => 'Buscar campeão';

  @override
  String get limpar => 'Limpar';

  @override
  String get escolhaNenhum => 'Nenhum campeão com esse nome.';

  @override
  String get ordemFavorito => 'Favorito';

  @override
  String get ordemNome => 'Nome';

  @override
  String get ordemMaestria => 'Maestria';

  @override
  String get ordenarPor => 'Ordenar por';

  @override
  String get salaTitulo => 'Na sala';

  @override
  String get salaConvidar => 'Convidar amigos';

  @override
  String get salaTrocar => 'Trocar';

  @override
  String get salaBuscar => 'Buscar partida';

  @override
  String get salaSair => 'Sair da sala';

  @override
  String get salaLiderInicia => 'O líder da sala inicia a fila.';

  @override
  String get salaEscolherPosicao => 'Escolher posição';

  @override
  String get salaEscolherSua => 'Escolher sua posição';

  @override
  String get salaConvidarCurto => 'Convidar';

  @override
  String get salaLider => 'Líder da sala';

  @override
  String get salaProcurando => 'Procurando partida';

  @override
  String get salaSairFila => 'Sair da fila';

  @override
  String get salaConvidado => 'Convidado, esperando resposta';

  @override
  String get salaChatFechado => 'O chat ainda não abriu.';

  @override
  String get salaChatVazio => 'Nenhuma mensagem ainda.';

  @override
  String salaVoce(String hh) {
    return 'Você · $hh';
  }

  @override
  String get salaChat => 'Chat da sala';

  @override
  String get erroConectar =>
      'Não consegui conectar. Confira a internet e abra de novo.';

  @override
  String get erroEmailEmUso => 'Esse e-mail já tem conta. Toque em Entrar.';

  @override
  String get erroEmailInvalido => 'Esse e-mail não parece certo.';

  @override
  String get erroSenhaFraca => 'A senha precisa de pelo menos 6 letras.';

  @override
  String get erroMuitasTentativas => 'Muitas tentativas. Espere um pouco.';

  @override
  String get erroSemInternet => 'Sem internet.';

  @override
  String get erroLogin => 'E-mail ou senha errados.';

  @override
  String get erroGenerico => 'Não deu certo. Tente de novo.';

  @override
  String get erroGenericoNet => 'Não deu certo. Confira a internet.';

  @override
  String get erroPreencher => 'Preencha o e-mail e a senha.';

  @override
  String get erroAbrirConta =>
      'Não consegui abrir a conta. Confira a internet.';

  @override
  String get erroMandar => 'Não consegui mandar. Confira a internet.';

  @override
  String get erroPcMudo => 'O PC não respondeu.';

  @override
  String get fechar => 'Fechar';

  @override
  String get contaCriarTitulo => 'Criar conta Ping';

  @override
  String get contaEntrarTitulo => 'Entrar na conta';

  @override
  String get contaCriarTexto => 'Depois entre com ela na janela do Ping no PC.';

  @override
  String get contaEntrarTexto => 'Os PCs da conta aparecem neste celular.';

  @override
  String get contaEmail => 'E-mail';

  @override
  String get contaSenha6 => 'Senha (6 letras ou mais)';

  @override
  String get contaSenha => 'Senha';

  @override
  String get contaBotaoCriar => 'Criar conta';

  @override
  String get contaBotaoEntrar => 'Entrar';

  @override
  String get contaJaTenho => 'Já tenho conta';

  @override
  String get contaCriarNova => 'Criar conta nova';

  @override
  String contaTambem(String contas) {
    return 'também $contas';
  }

  @override
  String get contaAberto => 'Aberto agora.';

  @override
  String contaAbertoResto(String resto) {
    return 'Aberto · $resto';
  }

  @override
  String get contaToqueAbrir => 'Toque pra abrir.';

  @override
  String get contaTirarQ => 'Tirar da conta?';

  @override
  String contaTirarTexto(String nome) {
    return '$nome sai da lista. Pra voltar, entre na conta de novo na janela do Ping dele.';
  }

  @override
  String get contaTirar => 'Tirar';

  @override
  String get cancelar => 'Cancelar';

  @override
  String get contaSairQ => 'Sair da conta?';

  @override
  String get contaSairTexto =>
      'Este celular para de ver os PCs. Eles continuam na conta: é só entrar de novo.';

  @override
  String get contaSair => 'Sair';

  @override
  String get contaTitulo => 'Conta Ping';

  @override
  String get contaCriarLinha =>
      'O vínculo não se perde e junta seus PCs e smurfs.';

  @override
  String get contaEntrarLinha => 'Entrar e ver os PCs da conta.';

  @override
  String contaPcsN(int n) {
    return '$n PCs nesta conta. Toque pra trocar.';
  }

  @override
  String get contaQualquerCel => 'Entre com ela em qualquer celular.';

  @override
  String get contaTirarSem => 'Tirar da conta';

  @override
  String get contaOutroPc => 'Outro PC';

  @override
  String get contaOutroPcTexto => 'Instale o Ping nele e entre com esta conta.';

  @override
  String get contaSairLinha => 'Sair da conta';

  @override
  String get contaSairLinhaTexto => 'Neste celular. Os PCs continuam na conta.';

  @override
  String get criarTrocarModo => 'Trocar modo';

  @override
  String get criarCriarSala => 'Criar sala';

  @override
  String get criarChamar => 'Chamar amigos';

  @override
  String get criarCriando => 'Criando sala...';

  @override
  String get criarPronto => 'Pronto';

  @override
  String criarConvidarN(int n) {
    return 'Convidar ($n)';
  }

  @override
  String get criarPassoModo => 'Modo';

  @override
  String get criarPassoAmigos => 'Amigos';

  @override
  String get criarModosAbrir =>
      'Os modos aparecem quando o LoL estiver aberto.';

  @override
  String get criarAtual => 'Atual';

  @override
  String get criarNenhumAmigo => 'Nenhum amigo online no LoL agora.';

  @override
  String get criarOnline => 'Online agora';

  @override
  String get criarDesmarcar => 'Desmarcar';

  @override
  String get criarMarcarTodos => 'Marcar todos';

  @override
  String get criarTudoParado => 'Tudo parado';

  @override
  String get criarTudoParadoTexto =>
      'Crie uma sala e chame os amigos daqui mesmo.';

  @override
  String criarOnline1(String a) {
    return '$a está online';
  }

  @override
  String criarOnline2(String a, String b) {
    return '$a e $b estão online';
  }

  @override
  String criarOnlineN(String a, int n) {
    return '$a e mais $n amigos estão online';
  }

  @override
  String get trocaAliado => 'o aliado';

  @override
  String trocaCom(String nome) {
    return 'Trocar com $nome';
  }

  @override
  String get trocaAceitar => 'Ele precisa aceitar.';

  @override
  String get trocaPosicao => 'Posição';

  @override
  String get trocaPosicaoSem => 'Vocês trocam de posição';

  @override
  String trocaVaiPraPos(String ganho) {
    return 'Você vai pra $ganho';
  }

  @override
  String get trocaOrdem => 'Ordem de pick';

  @override
  String get trocaOrdemSem => 'Vocês trocam a vez de escolher';

  @override
  String trocaEscolheEm(String ganho) {
    return 'Você escolhe em $ganho';
  }

  @override
  String get trocaCampeao => 'Campeão';

  @override
  String get trocaCampeaoSem => 'Vocês trocam de campeão';

  @override
  String trocaFicaCom(String ganho) {
    return 'Você fica com $ganho';
  }

  @override
  String get trocaUmAliado => 'Um aliado';

  @override
  String get trocaPosRec => 'Troca de posição';

  @override
  String get trocaPosEnv => 'Posição pedida';

  @override
  String get trocaOrdemRec => 'Troca de ordem';

  @override
  String get trocaOrdemEnv => 'Ordem pedida';

  @override
  String get trocaCampRec => 'Pedido de troca';

  @override
  String get trocaCampEnv => 'Troca pedida';

  @override
  String get trocaQuerPos => 'quer trocar de posição com você';

  @override
  String get trocaQuerOrdem => 'quer trocar a ordem de pick com você';

  @override
  String get trocaQuerCamp => 'quer trocar com você';

  @override
  String trocaRecebida(String nome, String quer) {
    return '$nome $quer.';
  }

  @override
  String trocaRecebidaFica(String nome, String quer, String fica) {
    return '$nome $quer: $fica.';
  }

  @override
  String trocaEsperando(String nome) {
    return 'Esperando $nome aceitar.';
  }

  @override
  String trocaEsperandoFica(String nome, String fica) {
    return 'Esperando $nome aceitar: $fica.';
  }

  @override
  String get recusar => 'Recusar';

  @override
  String get aceitar => 'Aceitar';

  @override
  String get trocaCancelar => 'Cancelar pedido';

  @override
  String get bancoTitulo => 'Banco';

  @override
  String get bancoNo => 'No banco';

  @override
  String get bancoToque => 'Toque pra pegar';

  @override
  String get bancoPegar => 'Pegar do banco';

  @override
  String bancoPegarNome(String nome) {
    return 'Pegar $nome do banco';
  }

  @override
  String evRoubado(String nome) {
    return '$nome (roubado)';
  }

  @override
  String get evPrimeiroAbate => 'Primeiro abate';

  @override
  String evDragao(String tipo) {
    String _temp0 = intl.Intl.selectLogic(tipo, {
      'fire': 'Dragão Infernal',
      'earth': 'Dragão da Montanha',
      'water': 'Dragão do Oceano',
      'air': 'Dragão das Nuvens',
      'hextech': 'Dragão Hextec',
      'chemtech': 'Dragão Quimtec',
      'elder': 'Dragão Ancião',
      'other': 'Dragão',
    });
    return '$_temp0';
  }

  @override
  String get evArauto => 'Arauto';

  @override
  String get evBarao => 'Barão';

  @override
  String get evVastilarvas => 'Vastilarvas';

  @override
  String get evAtakhan => 'Atakhan';

  @override
  String get evTorre => 'Torre';

  @override
  String get evInibidor => 'Inibidor';

  @override
  String get evAce => 'Time inteiro abatido';

  @override
  String get partidaCarregando => 'Tela de carregamento';

  @override
  String get partidaCarregandoTexto =>
      'A partida começa assim que todo mundo carregar.';

  @override
  String get partidaTropasCampo => 'Tropas em campo';

  @override
  String partidaTropasSaem(String tempo) {
    return 'Tropas saem em $tempo';
  }

  @override
  String get partidaTropasNao => 'Tropas ainda não saíram';

  @override
  String partidaVolta(String tempo) {
    return 'Você volta em $tempo';
  }

  @override
  String partidaDe(String campeao) {
    return 'Em partida de $campeao';
  }

  @override
  String get partidaEm => 'Em partida';

  @override
  String get partidaSeuTime => 'Seu time';

  @override
  String get partidaInimigo => 'Inimigo';

  @override
  String get eloIron => 'Ferro';

  @override
  String get eloBronze => 'Bronze';

  @override
  String get eloSilver => 'Prata';

  @override
  String get eloGold => 'Ouro';

  @override
  String get eloPlatinum => 'Platina';

  @override
  String get eloEmerald => 'Esmeralda';

  @override
  String get eloDiamond => 'Diamante';

  @override
  String get eloMaster => 'Mestre';

  @override
  String get eloGrandmaster => 'Grão-Mestre';

  @override
  String get eloChallenger => 'Desafiante';

  @override
  String get partidaCarregandoTitulo => 'Carregando';

  @override
  String get voce => 'Você';

  @override
  String timeN(int n) {
    return 'Time $n';
  }

  @override
  String get arenaBanimentos => 'Banimentos';

  @override
  String get arenaJogadores => 'Jogadores';

  @override
  String arenaJaBaniram(int feitos, int total) {
    return '$feitos/$total já baniram';
  }

  @override
  String arenaJaEscolheram(int feitos, int total) {
    return '$feitos/$total já escolheram';
  }

  @override
  String arenaJogadorN(int n) {
    return 'Jogador $n';
  }

  @override
  String arenaBaniu(String nome) {
    return 'Baniu $nome';
  }

  @override
  String arenaMarcou(String nome) {
    return 'Marcou $nome';
  }

  @override
  String get arenaBanindo => 'Banindo...';

  @override
  String get arenaNaoBaniu => 'Não baniu';

  @override
  String get arenaEscondido => 'Escondido';

  @override
  String get arenaEscolhendo => 'Escolhendo...';

  @override
  String get arenaOutros => 'Outros jogadores';

  @override
  String get fimCedo => 'Partida encerrada cedo';

  @override
  String get fimTitulo => 'Fim de partida';

  @override
  String get fimColocacao => 'Colocação';

  @override
  String get fimTempo => 'Tempo';

  @override
  String get msgMandarMensagem => 'Mandar mensagem';

  @override
  String get msgMandar => 'Mandar';

  @override
  String msgNovas(int n) {
    return 'Mensagens ($n novas)';
  }

  @override
  String get msgTitulo => 'Mensagens';

  @override
  String get msgConversas => 'Conversas';

  @override
  String msgVoceDois(String texto) {
    return 'Você: $texto';
  }

  @override
  String msgLinhaSem(String nome, int n) {
    return '$nome, $n mensagens novas';
  }

  @override
  String msgPrimeira(String nome) {
    return 'Mande a primeira mensagem pra $nome.';
  }

  @override
  String msgPara(String nome) {
    return 'Mensagem pra $nome';
  }

  @override
  String get msgOffline => 'Offline';

  @override
  String get avisosLigado => 'Ligado: chega mesmo com o app fechado.';

  @override
  String get avisosChega => 'Chega mesmo com o app fechado.';

  @override
  String get avisosNegado => 'Recusado nos ajustes do celular.';

  @override
  String get avisosTelaInicio => 'Adicione o app à tela de início pra ligar.';

  @override
  String get avisosConferindo => 'Conferindo...';

  @override
  String get avisosSemSuporte => 'Este navegador não recebe avisos.';

  @override
  String get avisosAvisar => 'Avisar neste celular';

  @override
  String get avisosMesmoNoPc => 'Mesmo com você no PC';

  @override
  String get avisosMesmoNoPcTexto => 'Avisa enquanto você está no PC.';

  @override
  String get avisosOQue => 'O que avisar';

  @override
  String get avisosErroMudar => 'Não consegui mudar o aviso neste celular.';

  @override
  String get avisosErroSalvar => 'Não salvou. Confira a internet.';

  @override
  String get runasFaltaPrim => 'caminho principal';

  @override
  String get runasFaltaPedra => 'pedra fundamental';

  @override
  String get runasFaltaRunasPrim => 'runas da principal';

  @override
  String get runasFaltaSec => 'caminho secundário';

  @override
  String get runasFaltaRunasSec => '2 runas da secundária';

  @override
  String get runasFaltaFrag => 'fragmentos';

  @override
  String get runasSalvar => 'Salvar e usar';

  @override
  String runasFalta(String item) {
    return 'Falta: $item';
  }

  @override
  String runasSem(String nome) {
    return 'Runas: $nome';
  }

  @override
  String get runasPaginaNovaNome => 'Página nova';

  @override
  String get runasTitulo => 'Runas';

  @override
  String get runasNovaPagina => 'Nova página';

  @override
  String get runasEditarPagina => 'Editar página';

  @override
  String get runasVoltar => 'Voltar pras páginas';

  @override
  String get runasSemPagina => 'Você ainda não tem página de runas.';

  @override
  String get runasSemEspaco =>
      'Sem espaço pra página nova: edite uma das suas.';

  @override
  String get runasIncompleta => 'Incompleta';

  @override
  String runasPaginaSem(String nome) {
    return '$nome, em uso';
  }

  @override
  String get runasEmUso => 'Em uso';

  @override
  String get runasPrincipal => 'Principal';

  @override
  String get runasEscolhaCaminho => 'Escolha um caminho pra começar.';

  @override
  String get runasSecundaria => 'Secundária';

  @override
  String get runasEscolhaPrincipal => 'Escolha o principal primeiro.';

  @override
  String get runasEscolhaSecundario => 'Escolha o caminho secundário.';

  @override
  String get runasFragmentos => 'Fragmentos';

  @override
  String get runasNomePagina => 'Nome da página';

  @override
  String get runasToque => 'Toque numa runa pra ver o que ela faz.';

  @override
  String get selChat => 'Chat da seleção';

  @override
  String get selSairQ => 'Sair da seleção?';

  @override
  String get selSairTexto => 'Você sai da partida, como no SAIR do LoL.';

  @override
  String get selSair => 'Sair';

  @override
  String get selFicar => 'Ficar';

  @override
  String get selSemChroma => 'Você não tem chroma desta skin';

  @override
  String get selChroma => 'Chroma';

  @override
  String get selChromaSem => 'Chroma que você não tem';

  @override
  String get selAramCaos => 'ARAM: Desordem';

  @override
  String get selBanimentos => 'Banimentos';

  @override
  String get selEscolhas => 'Escolhas';

  @override
  String get selPlanejamento => 'Planejamento';

  @override
  String get selFinalizacao => 'Finalização';

  @override
  String get selComecando => 'Começando';

  @override
  String get selTitulo => 'Seleção';

  @override
  String get selBoaPartida => 'Boa partida!';

  @override
  String get selEscolhaCarta => 'Escolha uma carta';

  @override
  String get selEscolhaPreparacao => 'Escolha sua preparação';

  @override
  String get selSorteando => 'Sorteando campeões';

  @override
  String get selSuaVezBanir => 'Sua vez de banir';

  @override
  String get selSuaVezEscolher => 'Sua vez de escolher';

  @override
  String get selPrepareSe => 'Prepare-se, os bans já vão abrir';

  @override
  String get selEsperandoBanirem => 'Esperando os outros banirem';

  @override
  String get selEscolhaSkin => 'Escolha sua skin';

  @override
  String get selEsperandoEscolherem => 'Esperando os outros escolherem';

  @override
  String get selDeclare => 'Declare seu campeão';

  @override
  String get selEsperandoBans => 'Esperando os bans';

  @override
  String get selTodosEscolheram => 'Todos escolheram';

  @override
  String get selVezTime => 'Vez do seu time';

  @override
  String get selVezInimigo => 'Vez do time inimigo';

  @override
  String get selEsperando => 'Esperando';

  @override
  String get selBanaCampeao => 'Bana um campeão!';

  @override
  String get selEscolhaCampeao => 'Escolha seu campeão!';

  @override
  String get selEscolhaPreparacaoEx => 'Escolha sua preparação!';

  @override
  String selChatSem(int n) {
    return 'Chat, $n novas';
  }

  @override
  String get selChatCurto => 'Chat';

  @override
  String get selTimeInimigos => 'Seu time';

  @override
  String get selInimigos => 'Inimigos';

  @override
  String get selBans => 'Bans';

  @override
  String get selNenhum => 'Nenhum';

  @override
  String get selBanPulado => 'Ban pulado';

  @override
  String get selAliado => 'Aliado';

  @override
  String selInimigoN(int n) {
    return 'Inimigo $n';
  }

  @override
  String selQuer(String nome) {
    return 'Quer $nome';
  }

  @override
  String selPedirTroca(String nome) {
    return 'Pedir troca com $nome';
  }

  @override
  String get selBanindo => 'Banindo';

  @override
  String get selEscolhendo => 'Escolhendo';

  @override
  String get selSairSem => 'Sair da seleção';

  @override
  String get selSairBotao => 'Sair';

  @override
  String get dicaTelaInicio =>
      'Dica: adicione à Tela de Início (Compartilhar > Adicionar). Pelo ícone, entre de novo com a sua conta.';

  @override
  String get mainConectando => 'Conectando';

  @override
  String get mainUmInstante => 'Só um instante.';

  @override
  String get mainFaltaPc => 'Falta o PC';

  @override
  String mainFaltaPcTexto(String conta) {
    return 'No painel do Ping no PC, abra Conta e entre com $conta. Ele aparece aqui na hora.';
  }

  @override
  String get mainEstaConta => 'esta conta';

  @override
  String get mainPcConectado => 'PC conectado';

  @override
  String get mainPcSemSinal => 'PC sem sinal';

  @override
  String get mainPingCelular => 'Ping no celular';

  @override
  String get mainEntreTexto =>
      'Entre com a mesma conta Ping do painel do PC. Não tem? Crie aqui e entre com ela no PC, em Conta.';

  @override
  String get mainOutraConta => 'Entrar com outra conta';

  @override
  String get mainEsperandoPc => 'Esperando o PC';

  @override
  String get mainEsperandoPcTexto =>
      'O Ping manda o primeiro sinal em alguns segundos.';

  @override
  String get mainPcSemSinalTexto =>
      'O PC está desligado, sem internet ou com o Ping fechado.';

  @override
  String get mainFechandoLolTexto =>
      'O LoL e o Riot Client estão fechando no PC.';

  @override
  String get mainLolFechado => 'LoL fechado';

  @override
  String get mainLolFechadoTexto => 'Abra o LoL no PC pra acompanhar por aqui.';

  @override
  String get mainAbrirLol => 'Abrir o LoL';

  @override
  String get mainEntreFila => 'Entre na fila no PC e acompanhe por aqui.';

  @override
  String get mainSelecao => 'Seleção de campeões';

  @override
  String get mainSelecaoTexto => 'Logo dá pra escolher o campeão por aqui.';

  @override
  String get mainPartidaAcabou => 'A partida acabou.';

  @override
  String mainEstimado(String tempo) {
    return 'Estimado $tempo';
  }

  @override
  String get mainAceita => 'Partida aceita';

  @override
  String get mainAceitaTexto => 'Esperando os outros jogadores.';

  @override
  String get mainRecusada => 'Partida recusada';

  @override
  String get mainRecusadaTexto => 'Você recusou esta partida.';

  @override
  String get maisPartida => 'Partida encontrada';

  @override
  String get mainEncontrada => 'Partida encontrada';

  @override
  String get mainAceitarQ => 'Aceitar?';

  @override
  String get mainFecharRiotQ => 'Fechar o Riot Client?';

  @override
  String get mainFecharLolQ => 'Fechar o LoL?';

  @override
  String get mainFecharRiotTexto => 'O Riot Client fecha no PC.';

  @override
  String get mainFecharFilaTexto =>
      'Você sai da fila e o LoL fecha no PC, junto com o Riot Client.';

  @override
  String get mainFecharLolTexto =>
      'O LoL fecha no PC, junto com o Riot Client.';

  @override
  String get mainFechar => 'Fechar';

  @override
  String get mainFecharRiot => 'Fechar o Riot Client';

  @override
  String get mainFecharLol => 'Fechar o LoL';

  @override
  String get mainLigarSons => 'Ligar sons';

  @override
  String get mainDesligarSons => 'Desligar sons';

  @override
  String get mainFechandoLol => 'Fechando o LoL';

  @override
  String get criarConvidado => 'Convidado';

  @override
  String runasEditarNome(String nome) {
    return 'Editar $nome';
  }

  @override
  String selSkinSem(String nome) {
    return '$nome, você não tem';
  }

  @override
  String get runaUma => 'Runa';

  @override
  String get avisoFilaN => 'Entrou na fila';

  @override
  String get avisoFilaT => 'Quando você ou o líder da sala entra na fila.';

  @override
  String get avisoPartidaN => 'Partida encontrada';

  @override
  String get avisoPartidaT => 'Quando a fila acha partida.';

  @override
  String get avisoVezN => 'Sua vez';

  @override
  String get avisoVezT => 'Quando chega sua vez de escolher ou banir.';

  @override
  String get avisoTrocaN => 'Pedido de troca';

  @override
  String get avisoTrocaT => 'Quando um aliado pede troca na seleção.';

  @override
  String get avisoConviteN => 'Convite pra sala';

  @override
  String get avisoConviteT => 'Quando alguém chama você pra sala.';

  @override
  String get avisoMensagemN => 'Mensagens';

  @override
  String get avisoMensagemT => 'Mensagem de amigo no chat privado ou da sala.';

  @override
  String get avisoLolProntoN => 'LoL aberto';

  @override
  String get avisoLolProntoT =>
      'Quando o LoL que você abriu pelo celular fica pronto.';

  @override
  String get avisoFimN => 'Fim da partida';

  @override
  String get avisoFimT => 'Vitória ou derrota, com o seu placar.';

  @override
  String get avisoResumoN => 'Resumo do dia';

  @override
  String get avisoResumoT => 'Quando você fecha o LoL.';

  @override
  String get rspLolFechado => 'LoL fechado';

  @override
  String get rspLolRecusou => 'O LoL recusou';

  @override
  String get rspConversaNaoAchada => 'Conversa não encontrada';

  @override
  String get rspLolRecusouMensagem => 'O LoL recusou a mensagem';

  @override
  String get rspMensagemVazia => 'Mensagem vazia';

  @override
  String get rspAmigoNaoAchado => 'Amigo não encontrado';

  @override
  String get rspModoInvalido => 'Modo inválido';

  @override
  String get rspSalaAgoraNao => 'Agora não dá pra criar sala';

  @override
  String get rspModoFechado => 'Esse modo não está aberto agora';

  @override
  String get rspSoLiderModo => 'Só o líder da sala troca o modo';

  @override
  String get rspLolRecusouModo => 'O LoL recusou esse modo';

  @override
  String get rspSalaCriada => 'Sala criada';

  @override
  String get rspNinguemEscolhido => 'Ninguém escolhido';

  @override
  String get rspForaDaSala => 'Você não está numa sala';

  @override
  String get rspLolRecusouConvite => 'O LoL recusou o convite';

  @override
  String get rspConviteMandado => 'Convite mandado';

  @override
  String rspConvitesMandados(int n) {
    return '$n convites mandados';
  }

  @override
  String get rspPosicaoInvalida => 'Posição inválida';

  @override
  String get rspModoSemPosicao => 'Esse modo não tem posição';

  @override
  String get rspPosicaoSegundaNao => 'Essa posição não dá na segunda';

  @override
  String get rspLolRecusouPosicao => 'O LoL recusou essa posição';

  @override
  String get rspSkinIndisponivel => 'Skin indisponível';

  @override
  String get rspLolRecusouSkin => 'O LoL recusou essa skin';

  @override
  String get rspFeiticoInvalido => 'Feitiço inválido';

  @override
  String get rspForaDaSelecao => 'Você não está na seleção';

  @override
  String get rspArenaSoOrdem =>
      'Na Arena só dá pra trocar a ordem dos feitiços';

  @override
  String get rspFeiticoModo => 'Esse feitiço não vale nesse modo';

  @override
  String get rspGolpearSelva => 'Golpear só na selva';

  @override
  String get rspLolRecusouFeitico => 'O LoL recusou esse feitiço';

  @override
  String get rspPaginaNaoAchada => 'Página não encontrada';

  @override
  String get rspLolRecusouPagina => 'O LoL recusou essa página';

  @override
  String get rspPaginaIncompleta => 'Página incompleta';

  @override
  String get rspPaginaNaoEdita => 'Essa página não dá pra editar';

  @override
  String get rspPaginaSemEspaco => 'Sem espaço pra página nova';

  @override
  String get rspPaginaSalva => 'Página salva';

  @override
  String get rspComandoInvalido => 'Comando inválido';

  @override
  String get rspComandoOutraConta => 'Comando de outra conta';

  @override
  String get rspComandoAtrasado => 'Comando chegou atrasado';

  @override
  String get rspComandoDesconhecido => 'Comando desconhecido';

  @override
  String get rspLolFechandoEspere => 'Espere o LoL terminar de fechar';

  @override
  String get rspLolJaAberto => 'O LoL já está aberto';

  @override
  String get rspLolJaAbrindo => 'O LoL já está abrindo';

  @override
  String get rspAbrindoLol => 'Abrindo o LoL';

  @override
  String get rspLolNaoAchado => 'Não achei o LoL neste PC';

  @override
  String get rspLolNaoAbriu => 'Não consegui abrir o LoL';

  @override
  String get rspFecharEmPartida => 'Agora não: você sairia da partida';

  @override
  String get rspLolJaFechando => 'O LoL já está fechando';

  @override
  String get rspLolJaFechado => 'O LoL já está fechado';

  @override
  String get rspFechandoLol => 'Fechando o LoL';

  @override
  String get rspSairSelecaoNao => 'Aqui não dá pra sair';

  @override
  String get rspSaiuSelecao => 'Saiu da seleção';

  @override
  String get rspTrocaInexistente => 'Essa troca não existe mais';

  @override
  String get rspTrocaTermineOutra => 'Termine a outra troca antes';

  @override
  String get rspTrocaAliadoOcupado => 'Esse aliado está em outra troca';

  @override
  String get rspTrocaAgoraNao => 'Agora não dá pra trocar com ele';

  @override
  String get rspTrocaJaPediu => 'Você já pediu essa troca';

  @override
  String get rspTrocaElePediu => 'Ele já pediu troca com você';

  @override
  String get rspTrocaInvalida => 'Essa troca não está mais valendo';

  @override
  String get rspTrocaTarde => 'Tarde demais pra trocar';

  @override
  String get rspTrocaOrdemNao => 'Agora não dá pra trocar a ordem';

  @override
  String get rspLolRecusouTroca => 'O LoL recusou a troca';

  @override
  String get rspPedidoCancelado => 'Pedido cancelado';

  @override
  String get rspTrocaPedida => 'Troca pedida';

  @override
  String get rspTrocaAceita => 'Troca aceita';

  @override
  String get rspTrocaRecusada => 'Troca recusada';

  @override
  String get rspTrocaPosPedida => 'Troca de posição pedida';

  @override
  String get rspTrocaPosAceita => 'Troca de posição aceita';

  @override
  String get rspTrocaPosRecusada => 'Troca de posição recusada';

  @override
  String get rspTrocaOrdemPedida => 'Troca de ordem pedida';

  @override
  String get rspTrocaOrdemAceita => 'Troca de ordem aceita';

  @override
  String get rspTrocaOrdemRecusada => 'Troca de ordem recusada';

  @override
  String get rspCampeaoInvalido => 'Campeão inválido';

  @override
  String get rspCartasFecharam => 'As cartas já fecharam';

  @override
  String get rspJaEscolheu => 'Você já escolheu';

  @override
  String get rspCartaInvalida => 'Essa carta não está mais valendo';

  @override
  String rspLolNegouCarta(String nome) {
    return 'O LoL não deixou escolher $nome';
  }

  @override
  String get rspLolRecusouCarta => 'O LoL não deixou escolher essa carta';

  @override
  String rspCartaEscolheu(String nome) {
    return 'Escolheu $nome';
  }

  @override
  String get rspCartaEscolhida => 'Carta escolhida';

  @override
  String get rspBancoSaiu => 'Esse campeão saiu do banco';

  @override
  String get rspBancoTermineTroca => 'Termine a troca com o aliado antes';

  @override
  String get rspBancoAindaNao => 'Ainda não dá pra pegar do banco';

  @override
  String rspLolNegouBanco(String nome) {
    return 'O LoL não deixou pegar $nome';
  }

  @override
  String get rspLolRecusouBanco => 'O LoL não deixou pegar esse campeão';

  @override
  String rspBancoPegou(String nome) {
    return 'Pegou $nome';
  }

  @override
  String get rspBancoPegouSem => 'Pegou do banco';

  @override
  String get rspAramSorteado => 'Na ARAM: Desordem o campeão é sorteado';

  @override
  String get rspEscolhaNaoAbriu => 'Ainda não abriu a escolha';

  @override
  String get rspNaoSuaVez => 'Não é sua vez';

  @override
  String get rspCampeaoBanido => 'Esse campeão foi banido';

  @override
  String get rspLolRecusouCampeao => 'O LoL recusou esse campeão';

  @override
  String rspBanido(String nome) {
    return 'Banido: $nome';
  }

  @override
  String rspTravado(String nome) {
    return 'Travado: $nome';
  }

  @override
  String get rspSemChat => 'Sem chat agora';

  @override
  String get rspMuitosComandos => 'Muitos comandos seguidos: espere um pouco';

  @override
  String get rspErroNoPc => 'Deu erro no PC';

  @override
  String get rspPartidaAceita => 'Partida aceita';

  @override
  String get rspPartidaRecusada => 'Partida recusada';

  @override
  String get rspSaiuFila => 'Saiu da fila';

  @override
  String get rspFilaIniciada => 'Fila iniciada';

  @override
  String get rspSaiuSala => 'Saiu da sala';

  @override
  String get stNoCelular => 'No celular';

  @override
  String get stEmPartida => 'Em partida';

  @override
  String get stNaSelecao => 'Na seleção';

  @override
  String get stNaFila => 'Na fila';

  @override
  String get stNumaSala => 'Numa sala';

  @override
  String get stAssistindo => 'Assistindo';

  @override
  String get stAusente => 'Ausente';

  @override
  String get stOcupado => 'Ocupado';

  @override
  String get stDisponivel => 'Disponível';

  @override
  String get grSummonersRift => 'Summoner\'s Rift';

  @override
  String get grAram => 'ARAM';

  @override
  String get grRiftClassico => 'Rift Clássico';

  @override
  String get grOutrosModos => 'Outros modos';

  @override
  String get grContraIa => 'Contra a IA';

  @override
  String get grPersonalizada => 'Personalizada';

  @override
  String get grTreino => 'Treino';

  @override
  String get grTft => 'TFT';

  @override
  String avEntrou(String quem) {
    return '$quem entrou';
  }

  @override
  String avSaiu(String quem) {
    return '$quem saiu';
  }

  @override
  String get avAlguem => 'Alguém';
}
