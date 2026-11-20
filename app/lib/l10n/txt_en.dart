// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'txt.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class TxtEn extends Txt {
  TxtEn([String locale = 'en']) : super(locale);

  @override
  String get pagTema => 'Theme';

  @override
  String get temaAparencia => 'Appearance';

  @override
  String get temaTexto => 'The app colors. The PC window has the same themes.';

  @override
  String get modoEscuro => 'Dark';

  @override
  String get modoClaro => 'Light';

  @override
  String modoSemantica(String nome) {
    return '$nome mode';
  }

  @override
  String temaSemantica(String nome) {
    return '$nome theme';
  }

  @override
  String get temaClient => 'Client';

  @override
  String get temaBilgewater => 'Bilgewater';

  @override
  String get temaSombras => 'Shadow Isles';

  @override
  String get temaBandopolis => 'Bandle City';

  @override
  String get temaVazio => 'The Void';

  @override
  String get idiomaTitulo => 'Language';

  @override
  String get idiomaCabecalho => 'Language';

  @override
  String get idiomaTexto => 'Automatic follows your device language.';

  @override
  String get idiomaAutomatico => 'Automatic';

  @override
  String temaResumo(String regiao, String modo) {
    return '$regiao, $modo';
  }

  @override
  String get abaAoVivo => 'Live';

  @override
  String get abaHoje => 'Today';

  @override
  String get abaMais => 'More';

  @override
  String get abasSemantica => 'Tabs';

  @override
  String get hojeMinutos => 'Minutes';

  @override
  String get hojeHoras => 'Hours';

  @override
  String get hojeVazioTitulo => 'No games today';

  @override
  String get hojeVazioTexto =>
      'Play a game and your daily summary shows up here.';

  @override
  String get hojeSoRemakes => 'Only remakes so far.';

  @override
  String get hojeTitulo => 'Today';

  @override
  String get hojeWinrate => 'Win rate';

  @override
  String hojeSiglaV(int n) {
    return '${n}W';
  }

  @override
  String hojeSiglaD(int n) {
    return '${n}L';
  }

  @override
  String get hojePartidas => 'Games';

  @override
  String get hojeMvp => 'MVP of the day';

  @override
  String hojeMvpVitorias(int v, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      v,
      locale: localeName,
      other: '$v wins',
      one: '1 win',
    );
    return '$_temp0 out of $n';
  }

  @override
  String get hojePartidasTitulo => 'Games';

  @override
  String get hojeRemake => 'Remake';

  @override
  String get resVitoria => 'Victory';

  @override
  String get resDerrota => 'Defeat';

  @override
  String get maisCelular => 'This phone';

  @override
  String get maisAvisos => 'Notifications';

  @override
  String get maisAvisosAtivo => 'They arrive even with the app closed.';

  @override
  String get maisAvisosInativo =>
      'Match found, your turn and more, on your phone.';

  @override
  String get maisTema => 'Theme';

  @override
  String get maisSons => 'Sounds';

  @override
  String get maisSonsTexto => 'The client sounds when something happens.';

  @override
  String get voltar => 'Back';

  @override
  String get versaoNova => 'New version!';

  @override
  String get versaoNovaTexto => 'Update before doing anything.';

  @override
  String get versaoBaixando => 'Downloading the new version';

  @override
  String get versaoAtualizar => 'Update now';

  @override
  String get x => 'Update now';

  @override
  String get aberturaRiot => 'Opening the Riot Client';

  @override
  String get aberturaLeague => 'Starting LoL';

  @override
  String get aberturaUx => 'Loading the client';

  @override
  String get aberturaPronto => 'Almost ready';

  @override
  String get aberturaTitulo => 'Opening LoL';

  @override
  String get aberturaLogin => 'Sign in on your PC if it asks.';

  @override
  String get aberturaPronto2 => 'Ready';

  @override
  String get aberturaEsperandoLogin => 'Waiting for sign-in';

  @override
  String get aberturaAberto => 'LoL is open';

  @override
  String get aberturaQuaseLa => 'Almost there';

  @override
  String aberturaFaltam(int s) {
    return '~${s}s left';
  }

  @override
  String get aberturaEstimado => 'Estimated time: still learning this PC.';

  @override
  String get posTop => 'Top';

  @override
  String get posJungle => 'Jungle';

  @override
  String get posMiddle => 'Mid';

  @override
  String get posBottom => 'Bot';

  @override
  String get posUtility => 'Support';

  @override
  String get posFill => 'Fill';

  @override
  String get escolher => 'Choose';

  @override
  String get posPrimeiraSem => 'First role';

  @override
  String get posSegundaSem => 'Second role';

  @override
  String get posPrimeira => 'First';

  @override
  String get posSegunda => 'Second';

  @override
  String get posSua => 'Your role';

  @override
  String get cartasTitulo => 'Choose your champion';

  @override
  String get cartasTexto => 'Tap a card';

  @override
  String get cartasEscolher => 'Choose card';

  @override
  String cartasEscolherNome(String nome) {
    return 'Choose $nome';
  }

  @override
  String get cartasSorte => 'Lucky';

  @override
  String get feiticoD => 'Summoner Spell D';

  @override
  String get feiticoF => 'Summoner Spell F';

  @override
  String get feiticosTitulo => 'Summoner Spells';

  @override
  String get banir => 'Ban';

  @override
  String get travar => 'Lock In';

  @override
  String get escolhaBuscar => 'Search champion';

  @override
  String get limpar => 'Clear';

  @override
  String get escolhaNenhum => 'No champion with that name.';

  @override
  String get ordemFavorito => 'Favorite';

  @override
  String get ordemNome => 'Name';

  @override
  String get ordemMaestria => 'Mastery';

  @override
  String get ordenarPor => 'Sort by';

  @override
  String get salaTitulo => 'In the lobby';

  @override
  String get salaConvidar => 'Invite friends';

  @override
  String get salaTrocar => 'Switch';

  @override
  String get salaBuscar => 'Find match';

  @override
  String get salaSair => 'Leave lobby';

  @override
  String get salaLiderInicia => 'The lobby leader starts the queue.';

  @override
  String get salaEscolherPosicao => 'Choose role';

  @override
  String get salaEscolherSua => 'Choose your role';

  @override
  String get salaConvidarCurto => 'Invite';

  @override
  String get salaLider => 'Lobby leader';

  @override
  String get salaProcurando => 'Searching for a match';

  @override
  String get salaSairFila => 'Leave queue';

  @override
  String get salaConvidado => 'Invited, waiting for a reply';

  @override
  String get salaChatFechado => 'The chat hasn\'t opened yet.';

  @override
  String get salaChatVazio => 'No messages yet.';

  @override
  String salaVoce(String hh) {
    return 'You · $hh';
  }

  @override
  String get salaChat => 'Lobby chat';

  @override
  String get erroConectar =>
      'Couldn\'t connect. Check your internet and open the app again.';

  @override
  String get erroEmailEmUso =>
      'That email already has an account. Tap Sign in.';

  @override
  String get erroEmailInvalido => 'That email doesn\'t look right.';

  @override
  String get erroSenhaFraca => 'The password needs at least 6 characters.';

  @override
  String get erroMuitasTentativas => 'Too many attempts. Wait a bit.';

  @override
  String get erroSemInternet => 'No internet.';

  @override
  String get erroLogin => 'Wrong email or password.';

  @override
  String get erroGenerico => 'Something went wrong. Try again.';

  @override
  String get erroGenericoNet => 'Something went wrong. Check your internet.';

  @override
  String get erroPreencher => 'Fill in the email and password.';

  @override
  String get erroAbrirConta =>
      'Couldn\'t open the account. Check your internet.';

  @override
  String get erroMandar => 'Couldn\'t send. Check your internet.';

  @override
  String get erroPcMudo => 'The PC didn\'t respond.';

  @override
  String get fechar => 'Close';

  @override
  String get contaCriarTitulo => 'Create a Ping account';

  @override
  String get contaEntrarTitulo => 'Sign in';

  @override
  String get contaCriarTexto =>
      'Then sign in with it in the Ping window on your PC.';

  @override
  String get contaEntrarTexto =>
      'The PCs on the account show up on this phone.';

  @override
  String get contaEmail => 'Email';

  @override
  String get contaSenha6 => 'Password (6 characters or more)';

  @override
  String get contaSenha => 'Password';

  @override
  String get contaBotaoCriar => 'Create account';

  @override
  String get contaBotaoEntrar => 'Sign in';

  @override
  String get contaJaTenho => 'I already have an account';

  @override
  String get contaCriarNova => 'Create a new account';

  @override
  String contaTambem(String contas) {
    return 'also $contas';
  }

  @override
  String get contaAberto => 'Open now.';

  @override
  String contaAbertoResto(String resto) {
    return 'Open · $resto';
  }

  @override
  String get contaToqueAbrir => 'Tap to open.';

  @override
  String get contaTirarQ => 'Remove from account?';

  @override
  String contaTirarTexto(String nome) {
    return '$nome leaves the list. To bring it back, sign in again in its Ping window.';
  }

  @override
  String get contaTirar => 'Remove';

  @override
  String get cancelar => 'Cancel';

  @override
  String get contaSairQ => 'Sign out?';

  @override
  String get contaSairTexto =>
      'This phone stops seeing the PCs. They stay on the account: just sign in again.';

  @override
  String get contaSair => 'Sign out';

  @override
  String get contaTitulo => 'Ping account';

  @override
  String get contaCriarLinha =>
      'The link is never lost and brings your PCs and smurfs together.';

  @override
  String get contaEntrarLinha => 'Sign in and see the account\'s PCs.';

  @override
  String contaPcsN(int n) {
    return '$n PCs on this account. Tap to switch.';
  }

  @override
  String get contaQualquerCel => 'Sign in with it on any phone.';

  @override
  String get contaTirarSem => 'Remove from account';

  @override
  String get contaOutroPc => 'Another PC';

  @override
  String get contaOutroPcTexto =>
      'Install Ping on it and sign in with this account.';

  @override
  String get contaSairLinha => 'Sign out';

  @override
  String get contaSairLinhaTexto =>
      'On this phone. The PCs stay on the account.';

  @override
  String get criarTrocarModo => 'Change mode';

  @override
  String get criarCriarSala => 'Create lobby';

  @override
  String get criarChamar => 'Call friends';

  @override
  String get criarCriando => 'Creating lobby...';

  @override
  String get criarPronto => 'Done';

  @override
  String criarConvidarN(int n) {
    return 'Invite ($n)';
  }

  @override
  String get criarPassoModo => 'Mode';

  @override
  String get criarPassoAmigos => 'Friends';

  @override
  String get criarModosAbrir => 'Modes show up when LoL is open.';

  @override
  String get criarAtual => 'Current';

  @override
  String get criarNenhumAmigo => 'No friends online in LoL right now.';

  @override
  String get criarOnline => 'Online now';

  @override
  String get criarDesmarcar => 'Deselect all';

  @override
  String get criarMarcarTodos => 'Select all';

  @override
  String get criarTudoParado => 'All quiet';

  @override
  String get criarTudoParadoTexto =>
      'Create a lobby and call your friends right from here.';

  @override
  String criarOnline1(String a) {
    return '$a is online';
  }

  @override
  String criarOnline2(String a, String b) {
    return '$a and $b are online';
  }

  @override
  String criarOnlineN(String a, int n) {
    return '$a and $n more friends are online';
  }

  @override
  String get trocaAliado => 'your ally';

  @override
  String trocaCom(String nome) {
    return 'Swap with $nome';
  }

  @override
  String get trocaAceitar => 'They have to accept.';

  @override
  String get trocaPosicao => 'Role';

  @override
  String get trocaPosicaoSem => 'You swap roles';

  @override
  String trocaVaiPraPos(String ganho) {
    return 'You go to $ganho';
  }

  @override
  String get trocaOrdem => 'Pick order';

  @override
  String get trocaOrdemSem => 'You swap pick turns';

  @override
  String trocaEscolheEm(String ganho) {
    return 'You pick $ganho';
  }

  @override
  String get trocaCampeao => 'Champion';

  @override
  String get trocaCampeaoSem => 'You swap champions';

  @override
  String trocaFicaCom(String ganho) {
    return 'You get $ganho';
  }

  @override
  String get trocaUmAliado => 'An ally';

  @override
  String get trocaPosRec => 'Role swap';

  @override
  String get trocaPosEnv => 'Role requested';

  @override
  String get trocaOrdemRec => 'Pick order swap';

  @override
  String get trocaOrdemEnv => 'Pick order requested';

  @override
  String get trocaCampRec => 'Swap request';

  @override
  String get trocaCampEnv => 'Swap requested';

  @override
  String get trocaQuerPos => 'wants to swap roles with you';

  @override
  String get trocaQuerOrdem => 'wants to swap pick order with you';

  @override
  String get trocaQuerCamp => 'wants to swap with you';

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
    return 'Waiting for $nome to accept.';
  }

  @override
  String trocaEsperandoFica(String nome, String fica) {
    return 'Waiting for $nome to accept: $fica.';
  }

  @override
  String get recusar => 'Decline';

  @override
  String get aceitar => 'Accept';

  @override
  String get trocaCancelar => 'Cancel request';

  @override
  String get bancoTitulo => 'Bench';

  @override
  String get bancoNo => 'On the bench';

  @override
  String get bancoToque => 'Tap to grab';

  @override
  String get bancoPegar => 'Grab from the bench';

  @override
  String bancoPegarNome(String nome) {
    return 'Grab $nome from the bench';
  }

  @override
  String evRoubado(String nome) {
    return '$nome (stolen)';
  }

  @override
  String get evPrimeiroAbate => 'First Blood';

  @override
  String evDragao(String tipo) {
    String _temp0 = intl.Intl.selectLogic(tipo, {
      'fire': 'Infernal Drake',
      'earth': 'Mountain Drake',
      'water': 'Ocean Drake',
      'air': 'Cloud Drake',
      'hextech': 'Hextech Drake',
      'chemtech': 'Chemtech Drake',
      'elder': 'Elder Dragon',
      'other': 'Dragon',
    });
    return '$_temp0';
  }

  @override
  String get evArauto => 'Rift Herald';

  @override
  String get evBarao => 'Baron Nashor';

  @override
  String get evVastilarvas => 'Void Grubs';

  @override
  String get evAtakhan => 'Atakhan';

  @override
  String get evTorre => 'Turret';

  @override
  String get evInibidor => 'Inhibitor';

  @override
  String get evAce => 'Ace';

  @override
  String get partidaCarregando => 'Loading screen';

  @override
  String get partidaCarregandoTexto =>
      'The game starts as soon as everyone loads.';

  @override
  String get partidaTropasCampo => 'Minions are out';

  @override
  String partidaTropasSaem(String tempo) {
    return 'Minions spawn in $tempo';
  }

  @override
  String get partidaTropasNao => 'Minions haven\'t spawned yet';

  @override
  String partidaVolta(String tempo) {
    return 'You respawn in $tempo';
  }

  @override
  String partidaDe(String campeao) {
    return 'In a game as $campeao';
  }

  @override
  String get partidaEm => 'In game';

  @override
  String get partidaSeuTime => 'Your team';

  @override
  String get partidaInimigo => 'Enemy';

  @override
  String get eloIron => 'Iron';

  @override
  String get eloBronze => 'Bronze';

  @override
  String get eloSilver => 'Silver';

  @override
  String get eloGold => 'Gold';

  @override
  String get eloPlatinum => 'Platinum';

  @override
  String get eloEmerald => 'Emerald';

  @override
  String get eloDiamond => 'Diamond';

  @override
  String get eloMaster => 'Master';

  @override
  String get eloGrandmaster => 'Grandmaster';

  @override
  String get eloChallenger => 'Challenger';

  @override
  String get partidaCarregandoTitulo => 'Loading';

  @override
  String get voce => 'You';

  @override
  String timeN(int n) {
    return 'Team $n';
  }

  @override
  String get arenaBanimentos => 'Bans';

  @override
  String get arenaJogadores => 'Players';

  @override
  String arenaJaBaniram(int feitos, int total) {
    return '$feitos/$total have banned';
  }

  @override
  String arenaJaEscolheram(int feitos, int total) {
    return '$feitos/$total have picked';
  }

  @override
  String arenaJogadorN(int n) {
    return 'Player $n';
  }

  @override
  String arenaBaniu(String nome) {
    return 'Banned $nome';
  }

  @override
  String arenaMarcou(String nome) {
    return 'Marked $nome';
  }

  @override
  String get arenaBanindo => 'Banning...';

  @override
  String get arenaNaoBaniu => 'Didn\'t ban';

  @override
  String get arenaEscondido => 'Hidden';

  @override
  String get arenaEscolhendo => 'Picking...';

  @override
  String get arenaOutros => 'Other players';

  @override
  String get fimCedo => 'Game ended early';

  @override
  String get fimTitulo => 'Game over';

  @override
  String get fimColocacao => 'Placement';

  @override
  String get fimTempo => 'Time';

  @override
  String get msgMandarMensagem => 'Send message';

  @override
  String get msgMandar => 'Send';

  @override
  String msgNovas(int n) {
    return 'Messages ($n new)';
  }

  @override
  String get msgTitulo => 'Messages';

  @override
  String get msgConversas => 'Chats';

  @override
  String msgVoceDois(String texto) {
    return 'You: $texto';
  }

  @override
  String msgLinhaSem(String nome, int n) {
    return '$nome, $n new messages';
  }

  @override
  String msgPrimeira(String nome) {
    return 'Send $nome the first message.';
  }

  @override
  String msgPara(String nome) {
    return 'Message $nome';
  }

  @override
  String get msgOffline => 'Offline';

  @override
  String get avisosLigado => 'On: arrives even with the app closed.';

  @override
  String get avisosChega => 'Arrives even with the app closed.';

  @override
  String get avisosNegado => 'Blocked in your phone settings.';

  @override
  String get avisosTelaInicio =>
      'Add the app to your home screen to turn it on.';

  @override
  String get avisosConferindo => 'Checking...';

  @override
  String get avisosSemSuporte => 'This browser can\'t receive notifications.';

  @override
  String get avisosAvisar => 'Notify on this phone';

  @override
  String get avisosMesmoNoPc => 'Even when you\'re on the PC';

  @override
  String get avisosMesmoNoPcTexto => 'Notifies you while you\'re on the PC.';

  @override
  String get avisosOQue => 'What to notify';

  @override
  String get avisosErroMudar =>
      'Couldn\'t change the notification on this phone.';

  @override
  String get avisosErroSalvar => 'Couldn\'t save. Check your internet.';

  @override
  String get runasFaltaPrim => 'primary path';

  @override
  String get runasFaltaPedra => 'keystone';

  @override
  String get runasFaltaRunasPrim => 'primary runes';

  @override
  String get runasFaltaSec => 'secondary path';

  @override
  String get runasFaltaRunasSec => '2 secondary runes';

  @override
  String get runasFaltaFrag => 'shards';

  @override
  String get runasSalvar => 'Save and use';

  @override
  String runasFalta(String item) {
    return 'Missing: $item';
  }

  @override
  String runasSem(String nome) {
    return 'Runes: $nome';
  }

  @override
  String get runasPaginaNovaNome => 'New page';

  @override
  String get runasTitulo => 'Runes';

  @override
  String get runasNovaPagina => 'New page';

  @override
  String get runasEditarPagina => 'Edit page';

  @override
  String get runasVoltar => 'Back to pages';

  @override
  String get runasSemPagina => 'You don\'t have a rune page yet.';

  @override
  String get runasSemEspaco => 'No room for a new page: edit one of yours.';

  @override
  String get runasIncompleta => 'Incomplete';

  @override
  String runasPaginaSem(String nome) {
    return '$nome, in use';
  }

  @override
  String get runasEmUso => 'In use';

  @override
  String get runasPrincipal => 'Primary';

  @override
  String get runasEscolhaCaminho => 'Choose a path to start.';

  @override
  String get runasSecundaria => 'Secondary';

  @override
  String get runasEscolhaPrincipal => 'Choose the primary first.';

  @override
  String get runasEscolhaSecundario => 'Choose the secondary path.';

  @override
  String get runasFragmentos => 'Shards';

  @override
  String get runasNomePagina => 'Page name';

  @override
  String get runasToque => 'Tap a rune to see what it does.';

  @override
  String get selChat => 'Champ select chat';

  @override
  String get selSairQ => 'Leave champion select?';

  @override
  String get selSairTexto => 'You leave the game, like LEAVE in LoL.';

  @override
  String get selSair => 'Leave';

  @override
  String get selFicar => 'Stay';

  @override
  String get selSemChroma => 'You don\'t have a chroma for this skin';

  @override
  String get selChroma => 'Chroma';

  @override
  String get selChromaSem => 'Chroma you don\'t own';

  @override
  String get selAramCaos => 'ARAM: Mayhem';

  @override
  String get selBanimentos => 'Bans';

  @override
  String get selEscolhas => 'Picks';

  @override
  String get selPlanejamento => 'Planning';

  @override
  String get selFinalizacao => 'Finalizing';

  @override
  String get selComecando => 'Starting';

  @override
  String get selTitulo => 'Champion Select';

  @override
  String get selBoaPartida => 'Good luck!';

  @override
  String get selEscolhaCarta => 'Choose a card';

  @override
  String get selEscolhaPreparacao => 'Choose your setup';

  @override
  String get selSorteando => 'Rolling champions';

  @override
  String get selSuaVezBanir => 'Your turn to ban';

  @override
  String get selSuaVezEscolher => 'Your turn to pick';

  @override
  String get selPrepareSe => 'Get ready, bans are about to open';

  @override
  String get selEsperandoBanirem => 'Waiting for the others to ban';

  @override
  String get selEscolhaSkin => 'Choose your skin';

  @override
  String get selEsperandoEscolherem => 'Waiting for the others to pick';

  @override
  String get selDeclare => 'Declare your champion';

  @override
  String get selEsperandoBans => 'Waiting for the bans';

  @override
  String get selTodosEscolheram => 'Everyone has picked';

  @override
  String get selVezTime => 'Your team\'s turn';

  @override
  String get selVezInimigo => 'Enemy team\'s turn';

  @override
  String get selEsperando => 'Waiting';

  @override
  String get selBanaCampeao => 'Ban a champion!';

  @override
  String get selEscolhaCampeao => 'Pick your champion!';

  @override
  String get selEscolhaPreparacaoEx => 'Choose your setup!';

  @override
  String selChatSem(int n) {
    return 'Chat, $n new';
  }

  @override
  String get selChatCurto => 'Chat';

  @override
  String get selTimeInimigos => 'Your team';

  @override
  String get selInimigos => 'Enemies';

  @override
  String get selBans => 'Bans';

  @override
  String get selNenhum => 'None';

  @override
  String get selBanPulado => 'Ban skipped';

  @override
  String get selAliado => 'Ally';

  @override
  String selInimigoN(int n) {
    return 'Enemy $n';
  }

  @override
  String selQuer(String nome) {
    return 'Wants $nome';
  }

  @override
  String selPedirTroca(String nome) {
    return 'Ask $nome to swap';
  }

  @override
  String get selBanindo => 'Banning';

  @override
  String get selEscolhendo => 'Picking';

  @override
  String get selSairSem => 'Leave champion select';

  @override
  String get selSairBotao => 'Leave';

  @override
  String get dicaTelaInicio =>
      'Tip: add the app to your Home Screen (Share > Add). Sign in again with your account from the icon.';

  @override
  String get mainConectando => 'Connecting';

  @override
  String get mainUmInstante => 'Just a moment.';

  @override
  String get mainFaltaPc => 'PC missing';

  @override
  String mainFaltaPcTexto(String conta) {
    return 'In the Ping window on your PC, open Account and sign in with $conta. It shows up here right away.';
  }

  @override
  String get mainEstaConta => 'this account';

  @override
  String get mainPcConectado => 'PC connected';

  @override
  String get mainPcSemSinal => 'PC offline';

  @override
  String get mainPingCelular => 'Ping on your phone';

  @override
  String get mainEntreTexto =>
      'Sign in with the same Ping account as the PC window. Don\'t have one? Create it here and sign in with it on the PC, under Account.';

  @override
  String get mainOutraConta => 'Sign in with another account';

  @override
  String get mainEsperandoPc => 'Waiting for the PC';

  @override
  String get mainEsperandoPcTexto =>
      'Ping sends its first signal in a few seconds.';

  @override
  String get mainPcSemSinalTexto =>
      'The PC is off, offline or has Ping closed.';

  @override
  String get mainFechandoLolTexto =>
      'LoL and the Riot Client are closing on the PC.';

  @override
  String get mainLolFechado => 'LoL is closed';

  @override
  String get mainLolFechadoTexto => 'Open LoL on the PC to follow along here.';

  @override
  String get mainAbrirLol => 'Open LoL';

  @override
  String get mainEntreFila => 'Join the queue on the PC and follow along here.';

  @override
  String get mainSelecao => 'Champion Select';

  @override
  String get mainSelecaoTexto =>
      'Soon you\'ll be able to pick your champion here.';

  @override
  String get mainPartidaAcabou => 'The game has ended.';

  @override
  String mainEstimado(String tempo) {
    return 'Estimated $tempo';
  }

  @override
  String get mainAceita => 'Match accepted';

  @override
  String get mainAceitaTexto => 'Waiting for the other players.';

  @override
  String get mainRecusada => 'Match declined';

  @override
  String get mainRecusadaTexto => 'You declined this match.';

  @override
  String get maisPartida => 'Match found';

  @override
  String get mainEncontrada => 'Match found';

  @override
  String get mainAceitarQ => 'Accept?';

  @override
  String get mainFecharRiotQ => 'Close the Riot Client?';

  @override
  String get mainFecharLolQ => 'Close LoL?';

  @override
  String get mainFecharRiotTexto => 'The Riot Client closes on the PC.';

  @override
  String get mainFecharFilaTexto =>
      'You leave the queue and LoL closes on the PC, along with the Riot Client.';

  @override
  String get mainFecharLolTexto =>
      'LoL closes on the PC, along with the Riot Client.';

  @override
  String get mainFechar => 'Close';

  @override
  String get mainFecharRiot => 'Close the Riot Client';

  @override
  String get mainFecharLol => 'Close LoL';

  @override
  String get mainLigarSons => 'Turn sounds on';

  @override
  String get mainDesligarSons => 'Turn sounds off';

  @override
  String get mainFechandoLol => 'Closing LoL';

  @override
  String get criarConvidado => 'Invited';

  @override
  String runasEditarNome(String nome) {
    return 'Edit $nome';
  }

  @override
  String selSkinSem(String nome) {
    return '$nome, you don\'t have it';
  }

  @override
  String get runaUma => 'Rune';

  @override
  String get avisoFilaN => 'Entered the queue';

  @override
  String get avisoFilaT => 'When you or the lobby leader enters the queue.';

  @override
  String get avisoPartidaN => 'Match found';

  @override
  String get avisoPartidaT => 'When the queue finds a match.';

  @override
  String get avisoVezN => 'Your turn';

  @override
  String get avisoVezT => 'When it\'s your turn to pick or ban.';

  @override
  String get avisoTrocaN => 'Swap request';

  @override
  String get avisoTrocaT => 'When an ally asks for a swap in champion select.';

  @override
  String get avisoConviteN => 'Lobby invite';

  @override
  String get avisoConviteT => 'When someone invites you to a lobby.';

  @override
  String get avisoMensagemN => 'Messages';

  @override
  String get avisoMensagemT =>
      'A friend\'s message in a private or lobby chat.';

  @override
  String get avisoLolProntoN => 'LoL is open';

  @override
  String get avisoLolProntoT =>
      'When the LoL you opened from your phone is ready.';

  @override
  String get avisoFimN => 'Game over';

  @override
  String get avisoFimT => 'Victory or defeat, with your score.';

  @override
  String get avisoResumoN => 'Daily summary';

  @override
  String get avisoResumoT => 'When you close LoL.';
}
