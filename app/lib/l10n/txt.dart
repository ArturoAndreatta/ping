import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'txt_en.dart';
import 'txt_es.dart';
import 'txt_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of Txt
/// returned by `Txt.of(context)`.
///
/// Applications need to include `Txt.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/txt.dart';
///
/// return MaterialApp(
///   localizationsDelegates: Txt.localizationsDelegates,
///   supportedLocales: Txt.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the Txt.supportedLocales
/// property.
abstract class Txt {
  Txt(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static Txt of(BuildContext context) {
    return Localizations.of<Txt>(context, Txt)!;
  }

  static const LocalizationsDelegate<Txt> delegate = _TxtDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// No description provided for @pagTema.
  ///
  /// In pt, this message translates to:
  /// **'Tema'**
  String get pagTema;

  /// No description provided for @temaAparencia.
  ///
  /// In pt, this message translates to:
  /// **'Aparência'**
  String get temaAparencia;

  /// No description provided for @temaTexto.
  ///
  /// In pt, this message translates to:
  /// **'As cores do app. O painel do PC tem os mesmos temas.'**
  String get temaTexto;

  /// No description provided for @modoEscuro.
  ///
  /// In pt, this message translates to:
  /// **'Escuro'**
  String get modoEscuro;

  /// No description provided for @modoClaro.
  ///
  /// In pt, this message translates to:
  /// **'Claro'**
  String get modoClaro;

  /// No description provided for @modoSemantica.
  ///
  /// In pt, this message translates to:
  /// **'Modo {nome}'**
  String modoSemantica(String nome);

  /// No description provided for @temaSemantica.
  ///
  /// In pt, this message translates to:
  /// **'Tema {nome}'**
  String temaSemantica(String nome);

  /// No description provided for @temaClient.
  ///
  /// In pt, this message translates to:
  /// **'Client'**
  String get temaClient;

  /// No description provided for @temaBilgewater.
  ///
  /// In pt, this message translates to:
  /// **'Águas de Sentina'**
  String get temaBilgewater;

  /// No description provided for @temaSombras.
  ///
  /// In pt, this message translates to:
  /// **'Ilha das Sombras'**
  String get temaSombras;

  /// No description provided for @temaBandopolis.
  ///
  /// In pt, this message translates to:
  /// **'Bandópolis'**
  String get temaBandopolis;

  /// No description provided for @temaVazio.
  ///
  /// In pt, this message translates to:
  /// **'Vazio'**
  String get temaVazio;

  /// No description provided for @idiomaTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get idiomaTitulo;

  /// No description provided for @idiomaCabecalho.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get idiomaCabecalho;

  /// No description provided for @idiomaTexto.
  ///
  /// In pt, this message translates to:
  /// **'Automático segue o idioma do aparelho.'**
  String get idiomaTexto;

  /// No description provided for @idiomaAutomatico.
  ///
  /// In pt, this message translates to:
  /// **'Automático'**
  String get idiomaAutomatico;

  /// No description provided for @temaResumo.
  ///
  /// In pt, this message translates to:
  /// **'{regiao}, {modo}'**
  String temaResumo(String regiao, String modo);

  /// No description provided for @abaAoVivo.
  ///
  /// In pt, this message translates to:
  /// **'Ao vivo'**
  String get abaAoVivo;

  /// No description provided for @abaHoje.
  ///
  /// In pt, this message translates to:
  /// **'Hoje'**
  String get abaHoje;

  /// No description provided for @abaMais.
  ///
  /// In pt, this message translates to:
  /// **'Mais'**
  String get abaMais;

  /// No description provided for @abasSemantica.
  ///
  /// In pt, this message translates to:
  /// **'Abas'**
  String get abasSemantica;

  /// No description provided for @hojeMinutos.
  ///
  /// In pt, this message translates to:
  /// **'Minutos'**
  String get hojeMinutos;

  /// No description provided for @hojeHoras.
  ///
  /// In pt, this message translates to:
  /// **'Horas'**
  String get hojeHoras;

  /// No description provided for @hojeVazioTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma partida hoje'**
  String get hojeVazioTitulo;

  /// No description provided for @hojeVazioTexto.
  ///
  /// In pt, this message translates to:
  /// **'Jogue uma partida e o resumo do dia aparece aqui.'**
  String get hojeVazioTexto;

  /// No description provided for @hojeSoRemakes.
  ///
  /// In pt, this message translates to:
  /// **'Só remakes até agora.'**
  String get hojeSoRemakes;

  /// No description provided for @hojeTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Hoje'**
  String get hojeTitulo;

  /// No description provided for @hojeWinrate.
  ///
  /// In pt, this message translates to:
  /// **'Winrate'**
  String get hojeWinrate;

  /// No description provided for @hojeSiglaV.
  ///
  /// In pt, this message translates to:
  /// **'{n}V'**
  String hojeSiglaV(int n);

  /// No description provided for @hojeSiglaD.
  ///
  /// In pt, this message translates to:
  /// **'{n}D'**
  String hojeSiglaD(int n);

  /// No description provided for @hojePartidas.
  ///
  /// In pt, this message translates to:
  /// **'Partidas'**
  String get hojePartidas;

  /// No description provided for @hojeMvp.
  ///
  /// In pt, this message translates to:
  /// **'MVP do dia'**
  String get hojeMvp;

  /// No description provided for @hojeMvpVitorias.
  ///
  /// In pt, this message translates to:
  /// **'{v, plural, =1{1 vitória} other{{v} vitórias}} em {n}'**
  String hojeMvpVitorias(int v, int n);

  /// No description provided for @hojePartidasTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Partidas'**
  String get hojePartidasTitulo;

  /// No description provided for @hojeRemake.
  ///
  /// In pt, this message translates to:
  /// **'Remake'**
  String get hojeRemake;

  /// No description provided for @resVitoria.
  ///
  /// In pt, this message translates to:
  /// **'Vitória'**
  String get resVitoria;

  /// No description provided for @resDerrota.
  ///
  /// In pt, this message translates to:
  /// **'Derrota'**
  String get resDerrota;

  /// No description provided for @maisCelular.
  ///
  /// In pt, this message translates to:
  /// **'Este celular'**
  String get maisCelular;

  /// No description provided for @maisAvisos.
  ///
  /// In pt, this message translates to:
  /// **'Avisos'**
  String get maisAvisos;

  /// No description provided for @maisAvisosAtivo.
  ///
  /// In pt, this message translates to:
  /// **'Chegam mesmo com o app fechado.'**
  String get maisAvisosAtivo;

  /// No description provided for @maisAvisosInativo.
  ///
  /// In pt, this message translates to:
  /// **'Partida encontrada, sua vez e mais, no celular.'**
  String get maisAvisosInativo;

  /// No description provided for @maisTema.
  ///
  /// In pt, this message translates to:
  /// **'Tema'**
  String get maisTema;

  /// No description provided for @maisSons.
  ///
  /// In pt, this message translates to:
  /// **'Sons'**
  String get maisSons;

  /// No description provided for @maisSonsTexto.
  ///
  /// In pt, this message translates to:
  /// **'Os sons do client quando algo acontece.'**
  String get maisSonsTexto;

  /// No description provided for @voltar.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get voltar;

  /// No description provided for @versaoNova.
  ///
  /// In pt, this message translates to:
  /// **'Versão nova!'**
  String get versaoNova;

  /// No description provided for @versaoNovaTexto.
  ///
  /// In pt, this message translates to:
  /// **'Atualize antes de qualquer ação.'**
  String get versaoNovaTexto;

  /// No description provided for @versaoBaixando.
  ///
  /// In pt, this message translates to:
  /// **'Baixando a versão nova'**
  String get versaoBaixando;

  /// No description provided for @versaoAtualizar.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar agora'**
  String get versaoAtualizar;

  /// No description provided for @x.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar agora'**
  String get x;

  /// No description provided for @aberturaRiot.
  ///
  /// In pt, this message translates to:
  /// **'Abrindo o Riot Client'**
  String get aberturaRiot;

  /// No description provided for @aberturaLeague.
  ///
  /// In pt, this message translates to:
  /// **'Iniciando o LoL'**
  String get aberturaLeague;

  /// No description provided for @aberturaUx.
  ///
  /// In pt, this message translates to:
  /// **'Carregando o client'**
  String get aberturaUx;

  /// No description provided for @aberturaPronto.
  ///
  /// In pt, this message translates to:
  /// **'Quase pronto'**
  String get aberturaPronto;

  /// No description provided for @aberturaTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Abrindo o LoL'**
  String get aberturaTitulo;

  /// No description provided for @aberturaLogin.
  ///
  /// In pt, this message translates to:
  /// **'Entre na sua conta no PC, se ele pedir.'**
  String get aberturaLogin;

  /// No description provided for @aberturaPronto2.
  ///
  /// In pt, this message translates to:
  /// **'Pronto'**
  String get aberturaPronto2;

  /// No description provided for @aberturaEsperandoLogin.
  ///
  /// In pt, this message translates to:
  /// **'Esperando o login'**
  String get aberturaEsperandoLogin;

  /// No description provided for @aberturaAberto.
  ///
  /// In pt, this message translates to:
  /// **'LoL aberto'**
  String get aberturaAberto;

  /// No description provided for @aberturaQuaseLa.
  ///
  /// In pt, this message translates to:
  /// **'Quase lá'**
  String get aberturaQuaseLa;

  /// No description provided for @aberturaFaltam.
  ///
  /// In pt, this message translates to:
  /// **'Faltam ~{s}s'**
  String aberturaFaltam(int s);

  /// No description provided for @aberturaEstimado.
  ///
  /// In pt, this message translates to:
  /// **'Tempo estimado: ainda aprendendo este PC.'**
  String get aberturaEstimado;

  /// No description provided for @posTop.
  ///
  /// In pt, this message translates to:
  /// **'Topo'**
  String get posTop;

  /// No description provided for @posJungle.
  ///
  /// In pt, this message translates to:
  /// **'Selva'**
  String get posJungle;

  /// No description provided for @posMiddle.
  ///
  /// In pt, this message translates to:
  /// **'Meio'**
  String get posMiddle;

  /// No description provided for @posBottom.
  ///
  /// In pt, this message translates to:
  /// **'Atirador'**
  String get posBottom;

  /// No description provided for @posUtility.
  ///
  /// In pt, this message translates to:
  /// **'Suporte'**
  String get posUtility;

  /// No description provided for @posFill.
  ///
  /// In pt, this message translates to:
  /// **'Qualquer'**
  String get posFill;

  /// No description provided for @escolher.
  ///
  /// In pt, this message translates to:
  /// **'Escolher'**
  String get escolher;

  /// No description provided for @posPrimeiraSem.
  ///
  /// In pt, this message translates to:
  /// **'Primeira posição'**
  String get posPrimeiraSem;

  /// No description provided for @posSegundaSem.
  ///
  /// In pt, this message translates to:
  /// **'Segunda posição'**
  String get posSegundaSem;

  /// No description provided for @posPrimeira.
  ///
  /// In pt, this message translates to:
  /// **'Primeira'**
  String get posPrimeira;

  /// No description provided for @posSegunda.
  ///
  /// In pt, this message translates to:
  /// **'Segunda'**
  String get posSegunda;

  /// No description provided for @posSua.
  ///
  /// In pt, this message translates to:
  /// **'Sua posição'**
  String get posSua;

  /// No description provided for @cartasTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Escolha seu campeão'**
  String get cartasTitulo;

  /// No description provided for @cartasTexto.
  ///
  /// In pt, this message translates to:
  /// **'Toque numa carta'**
  String get cartasTexto;

  /// No description provided for @cartasEscolher.
  ///
  /// In pt, this message translates to:
  /// **'Escolher carta'**
  String get cartasEscolher;

  /// No description provided for @cartasEscolherNome.
  ///
  /// In pt, this message translates to:
  /// **'Escolher {nome}'**
  String cartasEscolherNome(String nome);

  /// No description provided for @cartasSorte.
  ///
  /// In pt, this message translates to:
  /// **'Sorte'**
  String get cartasSorte;

  /// No description provided for @feiticoD.
  ///
  /// In pt, this message translates to:
  /// **'Feitiço D'**
  String get feiticoD;

  /// No description provided for @feiticoF.
  ///
  /// In pt, this message translates to:
  /// **'Feitiço F'**
  String get feiticoF;

  /// No description provided for @feiticosTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Feitiços'**
  String get feiticosTitulo;

  /// No description provided for @banir.
  ///
  /// In pt, this message translates to:
  /// **'Banir'**
  String get banir;

  /// No description provided for @travar.
  ///
  /// In pt, this message translates to:
  /// **'Travar'**
  String get travar;

  /// No description provided for @escolhaBuscar.
  ///
  /// In pt, this message translates to:
  /// **'Buscar campeão'**
  String get escolhaBuscar;

  /// No description provided for @limpar.
  ///
  /// In pt, this message translates to:
  /// **'Limpar'**
  String get limpar;

  /// No description provided for @escolhaNenhum.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum campeão com esse nome.'**
  String get escolhaNenhum;

  /// No description provided for @ordemFavorito.
  ///
  /// In pt, this message translates to:
  /// **'Favorito'**
  String get ordemFavorito;

  /// No description provided for @ordemNome.
  ///
  /// In pt, this message translates to:
  /// **'Nome'**
  String get ordemNome;

  /// No description provided for @ordemMaestria.
  ///
  /// In pt, this message translates to:
  /// **'Maestria'**
  String get ordemMaestria;

  /// No description provided for @ordenarPor.
  ///
  /// In pt, this message translates to:
  /// **'Ordenar por'**
  String get ordenarPor;

  /// No description provided for @salaTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Na sala'**
  String get salaTitulo;

  /// No description provided for @salaConvidar.
  ///
  /// In pt, this message translates to:
  /// **'Convidar amigos'**
  String get salaConvidar;

  /// No description provided for @salaTrocar.
  ///
  /// In pt, this message translates to:
  /// **'Trocar'**
  String get salaTrocar;

  /// No description provided for @salaBuscar.
  ///
  /// In pt, this message translates to:
  /// **'Buscar partida'**
  String get salaBuscar;

  /// No description provided for @salaSair.
  ///
  /// In pt, this message translates to:
  /// **'Sair da sala'**
  String get salaSair;

  /// No description provided for @salaLiderInicia.
  ///
  /// In pt, this message translates to:
  /// **'O líder da sala inicia a fila.'**
  String get salaLiderInicia;

  /// No description provided for @salaEscolherPosicao.
  ///
  /// In pt, this message translates to:
  /// **'Escolher posição'**
  String get salaEscolherPosicao;

  /// No description provided for @salaEscolherSua.
  ///
  /// In pt, this message translates to:
  /// **'Escolher sua posição'**
  String get salaEscolherSua;

  /// No description provided for @salaConvidarCurto.
  ///
  /// In pt, this message translates to:
  /// **'Convidar'**
  String get salaConvidarCurto;

  /// No description provided for @salaLider.
  ///
  /// In pt, this message translates to:
  /// **'Líder da sala'**
  String get salaLider;

  /// No description provided for @salaProcurando.
  ///
  /// In pt, this message translates to:
  /// **'Procurando partida'**
  String get salaProcurando;

  /// No description provided for @salaSairFila.
  ///
  /// In pt, this message translates to:
  /// **'Sair da fila'**
  String get salaSairFila;

  /// No description provided for @salaConvidado.
  ///
  /// In pt, this message translates to:
  /// **'Convidado, esperando resposta'**
  String get salaConvidado;

  /// No description provided for @salaChatFechado.
  ///
  /// In pt, this message translates to:
  /// **'O chat ainda não abriu.'**
  String get salaChatFechado;

  /// No description provided for @salaChatVazio.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma mensagem ainda.'**
  String get salaChatVazio;

  /// No description provided for @salaVoce.
  ///
  /// In pt, this message translates to:
  /// **'Você · {hh}'**
  String salaVoce(String hh);

  /// No description provided for @salaChat.
  ///
  /// In pt, this message translates to:
  /// **'Chat da sala'**
  String get salaChat;

  /// No description provided for @erroConectar.
  ///
  /// In pt, this message translates to:
  /// **'Não consegui conectar. Confira a internet e abra de novo.'**
  String get erroConectar;

  /// No description provided for @erroEmailEmUso.
  ///
  /// In pt, this message translates to:
  /// **'Esse e-mail já tem conta. Toque em Entrar.'**
  String get erroEmailEmUso;

  /// No description provided for @erroEmailInvalido.
  ///
  /// In pt, this message translates to:
  /// **'Esse e-mail não parece certo.'**
  String get erroEmailInvalido;

  /// No description provided for @erroSenhaFraca.
  ///
  /// In pt, this message translates to:
  /// **'A senha precisa de pelo menos 6 letras.'**
  String get erroSenhaFraca;

  /// No description provided for @erroMuitasTentativas.
  ///
  /// In pt, this message translates to:
  /// **'Muitas tentativas. Espere um pouco.'**
  String get erroMuitasTentativas;

  /// No description provided for @erroSemInternet.
  ///
  /// In pt, this message translates to:
  /// **'Sem internet.'**
  String get erroSemInternet;

  /// No description provided for @erroLogin.
  ///
  /// In pt, this message translates to:
  /// **'E-mail ou senha errados.'**
  String get erroLogin;

  /// No description provided for @erroGenerico.
  ///
  /// In pt, this message translates to:
  /// **'Não deu certo. Tente de novo.'**
  String get erroGenerico;

  /// No description provided for @erroGenericoNet.
  ///
  /// In pt, this message translates to:
  /// **'Não deu certo. Confira a internet.'**
  String get erroGenericoNet;

  /// No description provided for @erroPreencher.
  ///
  /// In pt, this message translates to:
  /// **'Preencha o e-mail e a senha.'**
  String get erroPreencher;

  /// No description provided for @erroAbrirConta.
  ///
  /// In pt, this message translates to:
  /// **'Não consegui abrir a conta. Confira a internet.'**
  String get erroAbrirConta;

  /// No description provided for @erroMandar.
  ///
  /// In pt, this message translates to:
  /// **'Não consegui mandar. Confira a internet.'**
  String get erroMandar;

  /// No description provided for @erroPcMudo.
  ///
  /// In pt, this message translates to:
  /// **'O PC não respondeu.'**
  String get erroPcMudo;

  /// No description provided for @fechar.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get fechar;

  /// No description provided for @contaCriarTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Criar conta Ping'**
  String get contaCriarTitulo;

  /// No description provided for @contaEntrarTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Entrar na conta'**
  String get contaEntrarTitulo;

  /// No description provided for @contaCriarTexto.
  ///
  /// In pt, this message translates to:
  /// **'Depois entre com ela na janela do Ping no PC.'**
  String get contaCriarTexto;

  /// No description provided for @contaEntrarTexto.
  ///
  /// In pt, this message translates to:
  /// **'Os PCs da conta aparecem neste celular.'**
  String get contaEntrarTexto;

  /// No description provided for @contaEmail.
  ///
  /// In pt, this message translates to:
  /// **'E-mail'**
  String get contaEmail;

  /// No description provided for @contaSenha6.
  ///
  /// In pt, this message translates to:
  /// **'Senha (6 letras ou mais)'**
  String get contaSenha6;

  /// No description provided for @contaSenha.
  ///
  /// In pt, this message translates to:
  /// **'Senha'**
  String get contaSenha;

  /// No description provided for @contaBotaoCriar.
  ///
  /// In pt, this message translates to:
  /// **'Criar conta'**
  String get contaBotaoCriar;

  /// No description provided for @contaBotaoEntrar.
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get contaBotaoEntrar;

  /// No description provided for @contaJaTenho.
  ///
  /// In pt, this message translates to:
  /// **'Já tenho conta'**
  String get contaJaTenho;

  /// No description provided for @contaCriarNova.
  ///
  /// In pt, this message translates to:
  /// **'Criar conta nova'**
  String get contaCriarNova;

  /// No description provided for @contaTambem.
  ///
  /// In pt, this message translates to:
  /// **'também {contas}'**
  String contaTambem(String contas);

  /// No description provided for @contaAberto.
  ///
  /// In pt, this message translates to:
  /// **'Aberto agora.'**
  String get contaAberto;

  /// No description provided for @contaAbertoResto.
  ///
  /// In pt, this message translates to:
  /// **'Aberto · {resto}'**
  String contaAbertoResto(String resto);

  /// No description provided for @contaToqueAbrir.
  ///
  /// In pt, this message translates to:
  /// **'Toque pra abrir.'**
  String get contaToqueAbrir;

  /// No description provided for @contaTirarQ.
  ///
  /// In pt, this message translates to:
  /// **'Tirar da conta?'**
  String get contaTirarQ;

  /// No description provided for @contaTirarTexto.
  ///
  /// In pt, this message translates to:
  /// **'{nome} sai da lista. Pra voltar, entre na conta de novo na janela do Ping dele.'**
  String contaTirarTexto(String nome);

  /// No description provided for @contaTirar.
  ///
  /// In pt, this message translates to:
  /// **'Tirar'**
  String get contaTirar;

  /// No description provided for @cancelar.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get cancelar;

  /// No description provided for @contaSairQ.
  ///
  /// In pt, this message translates to:
  /// **'Sair da conta?'**
  String get contaSairQ;

  /// No description provided for @contaSairTexto.
  ///
  /// In pt, this message translates to:
  /// **'Este celular para de ver os PCs. Eles continuam na conta: é só entrar de novo.'**
  String get contaSairTexto;

  /// No description provided for @contaSair.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get contaSair;

  /// No description provided for @contaTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Conta Ping'**
  String get contaTitulo;

  /// No description provided for @contaCriarLinha.
  ///
  /// In pt, this message translates to:
  /// **'O vínculo não se perde e junta seus PCs e smurfs.'**
  String get contaCriarLinha;

  /// No description provided for @contaEntrarLinha.
  ///
  /// In pt, this message translates to:
  /// **'Entrar e ver os PCs da conta.'**
  String get contaEntrarLinha;

  /// No description provided for @contaPcsN.
  ///
  /// In pt, this message translates to:
  /// **'{n} PCs nesta conta. Toque pra trocar.'**
  String contaPcsN(int n);

  /// No description provided for @contaQualquerCel.
  ///
  /// In pt, this message translates to:
  /// **'Entre com ela em qualquer celular.'**
  String get contaQualquerCel;

  /// No description provided for @contaTirarSem.
  ///
  /// In pt, this message translates to:
  /// **'Tirar da conta'**
  String get contaTirarSem;

  /// No description provided for @contaOutroPc.
  ///
  /// In pt, this message translates to:
  /// **'Outro PC'**
  String get contaOutroPc;

  /// No description provided for @contaOutroPcTexto.
  ///
  /// In pt, this message translates to:
  /// **'Instale o Ping nele e entre com esta conta.'**
  String get contaOutroPcTexto;

  /// No description provided for @contaSairLinha.
  ///
  /// In pt, this message translates to:
  /// **'Sair da conta'**
  String get contaSairLinha;

  /// No description provided for @contaSairLinhaTexto.
  ///
  /// In pt, this message translates to:
  /// **'Neste celular. Os PCs continuam na conta.'**
  String get contaSairLinhaTexto;

  /// No description provided for @criarTrocarModo.
  ///
  /// In pt, this message translates to:
  /// **'Trocar modo'**
  String get criarTrocarModo;

  /// No description provided for @criarCriarSala.
  ///
  /// In pt, this message translates to:
  /// **'Criar sala'**
  String get criarCriarSala;

  /// No description provided for @criarChamar.
  ///
  /// In pt, this message translates to:
  /// **'Chamar amigos'**
  String get criarChamar;

  /// No description provided for @criarCriando.
  ///
  /// In pt, this message translates to:
  /// **'Criando sala...'**
  String get criarCriando;

  /// No description provided for @criarPronto.
  ///
  /// In pt, this message translates to:
  /// **'Pronto'**
  String get criarPronto;

  /// No description provided for @criarConvidarN.
  ///
  /// In pt, this message translates to:
  /// **'Convidar ({n})'**
  String criarConvidarN(int n);

  /// No description provided for @criarPassoModo.
  ///
  /// In pt, this message translates to:
  /// **'Modo'**
  String get criarPassoModo;

  /// No description provided for @criarPassoAmigos.
  ///
  /// In pt, this message translates to:
  /// **'Amigos'**
  String get criarPassoAmigos;

  /// No description provided for @criarModosAbrir.
  ///
  /// In pt, this message translates to:
  /// **'Os modos aparecem quando o LoL estiver aberto.'**
  String get criarModosAbrir;

  /// No description provided for @criarAtual.
  ///
  /// In pt, this message translates to:
  /// **'Atual'**
  String get criarAtual;

  /// No description provided for @criarNenhumAmigo.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum amigo online no LoL agora.'**
  String get criarNenhumAmigo;

  /// No description provided for @criarOnline.
  ///
  /// In pt, this message translates to:
  /// **'Online agora'**
  String get criarOnline;

  /// No description provided for @criarDesmarcar.
  ///
  /// In pt, this message translates to:
  /// **'Desmarcar'**
  String get criarDesmarcar;

  /// No description provided for @criarMarcarTodos.
  ///
  /// In pt, this message translates to:
  /// **'Marcar todos'**
  String get criarMarcarTodos;

  /// No description provided for @criarTudoParado.
  ///
  /// In pt, this message translates to:
  /// **'Tudo parado'**
  String get criarTudoParado;

  /// No description provided for @criarTudoParadoTexto.
  ///
  /// In pt, this message translates to:
  /// **'Crie uma sala e chame os amigos daqui mesmo.'**
  String get criarTudoParadoTexto;

  /// No description provided for @criarOnline1.
  ///
  /// In pt, this message translates to:
  /// **'{a} está online'**
  String criarOnline1(String a);

  /// No description provided for @criarOnline2.
  ///
  /// In pt, this message translates to:
  /// **'{a} e {b} estão online'**
  String criarOnline2(String a, String b);

  /// No description provided for @criarOnlineN.
  ///
  /// In pt, this message translates to:
  /// **'{a} e mais {n} amigos estão online'**
  String criarOnlineN(String a, int n);

  /// No description provided for @trocaAliado.
  ///
  /// In pt, this message translates to:
  /// **'o aliado'**
  String get trocaAliado;

  /// No description provided for @trocaCom.
  ///
  /// In pt, this message translates to:
  /// **'Trocar com {nome}'**
  String trocaCom(String nome);

  /// No description provided for @trocaAceitar.
  ///
  /// In pt, this message translates to:
  /// **'Ele precisa aceitar.'**
  String get trocaAceitar;

  /// No description provided for @trocaPosicao.
  ///
  /// In pt, this message translates to:
  /// **'Posição'**
  String get trocaPosicao;

  /// No description provided for @trocaPosicaoSem.
  ///
  /// In pt, this message translates to:
  /// **'Vocês trocam de posição'**
  String get trocaPosicaoSem;

  /// No description provided for @trocaVaiPraPos.
  ///
  /// In pt, this message translates to:
  /// **'Você vai pra {ganho}'**
  String trocaVaiPraPos(String ganho);

  /// No description provided for @trocaOrdem.
  ///
  /// In pt, this message translates to:
  /// **'Ordem de pick'**
  String get trocaOrdem;

  /// No description provided for @trocaOrdemSem.
  ///
  /// In pt, this message translates to:
  /// **'Vocês trocam a vez de escolher'**
  String get trocaOrdemSem;

  /// No description provided for @trocaEscolheEm.
  ///
  /// In pt, this message translates to:
  /// **'Você escolhe em {ganho}'**
  String trocaEscolheEm(String ganho);

  /// No description provided for @trocaCampeao.
  ///
  /// In pt, this message translates to:
  /// **'Campeão'**
  String get trocaCampeao;

  /// No description provided for @trocaCampeaoSem.
  ///
  /// In pt, this message translates to:
  /// **'Vocês trocam de campeão'**
  String get trocaCampeaoSem;

  /// No description provided for @trocaFicaCom.
  ///
  /// In pt, this message translates to:
  /// **'Você fica com {ganho}'**
  String trocaFicaCom(String ganho);

  /// No description provided for @trocaUmAliado.
  ///
  /// In pt, this message translates to:
  /// **'Um aliado'**
  String get trocaUmAliado;

  /// No description provided for @trocaPosRec.
  ///
  /// In pt, this message translates to:
  /// **'Troca de posição'**
  String get trocaPosRec;

  /// No description provided for @trocaPosEnv.
  ///
  /// In pt, this message translates to:
  /// **'Posição pedida'**
  String get trocaPosEnv;

  /// No description provided for @trocaOrdemRec.
  ///
  /// In pt, this message translates to:
  /// **'Troca de ordem'**
  String get trocaOrdemRec;

  /// No description provided for @trocaOrdemEnv.
  ///
  /// In pt, this message translates to:
  /// **'Ordem pedida'**
  String get trocaOrdemEnv;

  /// No description provided for @trocaCampRec.
  ///
  /// In pt, this message translates to:
  /// **'Pedido de troca'**
  String get trocaCampRec;

  /// No description provided for @trocaCampEnv.
  ///
  /// In pt, this message translates to:
  /// **'Troca pedida'**
  String get trocaCampEnv;

  /// No description provided for @trocaQuerPos.
  ///
  /// In pt, this message translates to:
  /// **'quer trocar de posição com você'**
  String get trocaQuerPos;

  /// No description provided for @trocaQuerOrdem.
  ///
  /// In pt, this message translates to:
  /// **'quer trocar a ordem de pick com você'**
  String get trocaQuerOrdem;

  /// No description provided for @trocaQuerCamp.
  ///
  /// In pt, this message translates to:
  /// **'quer trocar com você'**
  String get trocaQuerCamp;

  /// No description provided for @trocaRecebida.
  ///
  /// In pt, this message translates to:
  /// **'{nome} {quer}.'**
  String trocaRecebida(String nome, String quer);

  /// No description provided for @trocaRecebidaFica.
  ///
  /// In pt, this message translates to:
  /// **'{nome} {quer}: {fica}.'**
  String trocaRecebidaFica(String nome, String quer, String fica);

  /// No description provided for @trocaEsperando.
  ///
  /// In pt, this message translates to:
  /// **'Esperando {nome} aceitar.'**
  String trocaEsperando(String nome);

  /// No description provided for @trocaEsperandoFica.
  ///
  /// In pt, this message translates to:
  /// **'Esperando {nome} aceitar: {fica}.'**
  String trocaEsperandoFica(String nome, String fica);

  /// No description provided for @recusar.
  ///
  /// In pt, this message translates to:
  /// **'Recusar'**
  String get recusar;

  /// No description provided for @aceitar.
  ///
  /// In pt, this message translates to:
  /// **'Aceitar'**
  String get aceitar;

  /// No description provided for @trocaCancelar.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar pedido'**
  String get trocaCancelar;

  /// No description provided for @bancoTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Banco'**
  String get bancoTitulo;

  /// No description provided for @bancoNo.
  ///
  /// In pt, this message translates to:
  /// **'No banco'**
  String get bancoNo;

  /// No description provided for @bancoToque.
  ///
  /// In pt, this message translates to:
  /// **'Toque pra pegar'**
  String get bancoToque;

  /// No description provided for @bancoPegar.
  ///
  /// In pt, this message translates to:
  /// **'Pegar do banco'**
  String get bancoPegar;

  /// No description provided for @bancoPegarNome.
  ///
  /// In pt, this message translates to:
  /// **'Pegar {nome} do banco'**
  String bancoPegarNome(String nome);

  /// No description provided for @evRoubado.
  ///
  /// In pt, this message translates to:
  /// **'{nome} (roubado)'**
  String evRoubado(String nome);

  /// No description provided for @evPrimeiroAbate.
  ///
  /// In pt, this message translates to:
  /// **'Primeiro abate'**
  String get evPrimeiroAbate;

  /// No description provided for @evDragao.
  ///
  /// In pt, this message translates to:
  /// **'{tipo, select, fire{Dragão Infernal} earth{Dragão da Montanha} water{Dragão do Oceano} air{Dragão das Nuvens} hextech{Dragão Hextec} chemtech{Dragão Quimtec} elder{Dragão Ancião} other{Dragão}}'**
  String evDragao(String tipo);

  /// No description provided for @evArauto.
  ///
  /// In pt, this message translates to:
  /// **'Arauto'**
  String get evArauto;

  /// No description provided for @evBarao.
  ///
  /// In pt, this message translates to:
  /// **'Barão'**
  String get evBarao;

  /// No description provided for @evVastilarvas.
  ///
  /// In pt, this message translates to:
  /// **'Vastilarvas'**
  String get evVastilarvas;

  /// No description provided for @evAtakhan.
  ///
  /// In pt, this message translates to:
  /// **'Atakhan'**
  String get evAtakhan;

  /// No description provided for @evTorre.
  ///
  /// In pt, this message translates to:
  /// **'Torre'**
  String get evTorre;

  /// No description provided for @evInibidor.
  ///
  /// In pt, this message translates to:
  /// **'Inibidor'**
  String get evInibidor;

  /// No description provided for @evAce.
  ///
  /// In pt, this message translates to:
  /// **'Time inteiro abatido'**
  String get evAce;

  /// No description provided for @partidaCarregando.
  ///
  /// In pt, this message translates to:
  /// **'Tela de carregamento'**
  String get partidaCarregando;

  /// No description provided for @partidaCarregandoTexto.
  ///
  /// In pt, this message translates to:
  /// **'A partida começa assim que todo mundo carregar.'**
  String get partidaCarregandoTexto;

  /// No description provided for @partidaTropasCampo.
  ///
  /// In pt, this message translates to:
  /// **'Tropas em campo'**
  String get partidaTropasCampo;

  /// No description provided for @partidaTropasSaem.
  ///
  /// In pt, this message translates to:
  /// **'Tropas saem em {tempo}'**
  String partidaTropasSaem(String tempo);

  /// No description provided for @partidaTropasNao.
  ///
  /// In pt, this message translates to:
  /// **'Tropas ainda não saíram'**
  String get partidaTropasNao;

  /// No description provided for @partidaVolta.
  ///
  /// In pt, this message translates to:
  /// **'Você volta em {tempo}'**
  String partidaVolta(String tempo);

  /// No description provided for @partidaDe.
  ///
  /// In pt, this message translates to:
  /// **'Em partida de {campeao}'**
  String partidaDe(String campeao);

  /// No description provided for @partidaEm.
  ///
  /// In pt, this message translates to:
  /// **'Em partida'**
  String get partidaEm;

  /// No description provided for @partidaSeuTime.
  ///
  /// In pt, this message translates to:
  /// **'Seu time'**
  String get partidaSeuTime;

  /// No description provided for @partidaInimigo.
  ///
  /// In pt, this message translates to:
  /// **'Inimigo'**
  String get partidaInimigo;

  /// No description provided for @eloIron.
  ///
  /// In pt, this message translates to:
  /// **'Ferro'**
  String get eloIron;

  /// No description provided for @eloBronze.
  ///
  /// In pt, this message translates to:
  /// **'Bronze'**
  String get eloBronze;

  /// No description provided for @eloSilver.
  ///
  /// In pt, this message translates to:
  /// **'Prata'**
  String get eloSilver;

  /// No description provided for @eloGold.
  ///
  /// In pt, this message translates to:
  /// **'Ouro'**
  String get eloGold;

  /// No description provided for @eloPlatinum.
  ///
  /// In pt, this message translates to:
  /// **'Platina'**
  String get eloPlatinum;

  /// No description provided for @eloEmerald.
  ///
  /// In pt, this message translates to:
  /// **'Esmeralda'**
  String get eloEmerald;

  /// No description provided for @eloDiamond.
  ///
  /// In pt, this message translates to:
  /// **'Diamante'**
  String get eloDiamond;

  /// No description provided for @eloMaster.
  ///
  /// In pt, this message translates to:
  /// **'Mestre'**
  String get eloMaster;

  /// No description provided for @eloGrandmaster.
  ///
  /// In pt, this message translates to:
  /// **'Grão-Mestre'**
  String get eloGrandmaster;

  /// No description provided for @eloChallenger.
  ///
  /// In pt, this message translates to:
  /// **'Desafiante'**
  String get eloChallenger;

  /// No description provided for @partidaCarregandoTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Carregando'**
  String get partidaCarregandoTitulo;

  /// No description provided for @voce.
  ///
  /// In pt, this message translates to:
  /// **'Você'**
  String get voce;

  /// No description provided for @timeN.
  ///
  /// In pt, this message translates to:
  /// **'Time {n}'**
  String timeN(int n);

  /// No description provided for @arenaBanimentos.
  ///
  /// In pt, this message translates to:
  /// **'Banimentos'**
  String get arenaBanimentos;

  /// No description provided for @arenaJogadores.
  ///
  /// In pt, this message translates to:
  /// **'Jogadores'**
  String get arenaJogadores;

  /// No description provided for @arenaJaBaniram.
  ///
  /// In pt, this message translates to:
  /// **'{feitos}/{total} já baniram'**
  String arenaJaBaniram(int feitos, int total);

  /// No description provided for @arenaJaEscolheram.
  ///
  /// In pt, this message translates to:
  /// **'{feitos}/{total} já escolheram'**
  String arenaJaEscolheram(int feitos, int total);

  /// No description provided for @arenaJogadorN.
  ///
  /// In pt, this message translates to:
  /// **'Jogador {n}'**
  String arenaJogadorN(int n);

  /// No description provided for @arenaBaniu.
  ///
  /// In pt, this message translates to:
  /// **'Baniu {nome}'**
  String arenaBaniu(String nome);

  /// No description provided for @arenaMarcou.
  ///
  /// In pt, this message translates to:
  /// **'Marcou {nome}'**
  String arenaMarcou(String nome);

  /// No description provided for @arenaBanindo.
  ///
  /// In pt, this message translates to:
  /// **'Banindo...'**
  String get arenaBanindo;

  /// No description provided for @arenaNaoBaniu.
  ///
  /// In pt, this message translates to:
  /// **'Não baniu'**
  String get arenaNaoBaniu;

  /// No description provided for @arenaEscondido.
  ///
  /// In pt, this message translates to:
  /// **'Escondido'**
  String get arenaEscondido;

  /// No description provided for @arenaEscolhendo.
  ///
  /// In pt, this message translates to:
  /// **'Escolhendo...'**
  String get arenaEscolhendo;

  /// No description provided for @arenaOutros.
  ///
  /// In pt, this message translates to:
  /// **'Outros jogadores'**
  String get arenaOutros;

  /// No description provided for @fimCedo.
  ///
  /// In pt, this message translates to:
  /// **'Partida encerrada cedo'**
  String get fimCedo;

  /// No description provided for @fimTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Fim de partida'**
  String get fimTitulo;

  /// No description provided for @fimColocacao.
  ///
  /// In pt, this message translates to:
  /// **'Colocação'**
  String get fimColocacao;

  /// No description provided for @fimTempo.
  ///
  /// In pt, this message translates to:
  /// **'Tempo'**
  String get fimTempo;

  /// No description provided for @msgMandarMensagem.
  ///
  /// In pt, this message translates to:
  /// **'Mandar mensagem'**
  String get msgMandarMensagem;

  /// No description provided for @msgMandar.
  ///
  /// In pt, this message translates to:
  /// **'Mandar'**
  String get msgMandar;

  /// No description provided for @msgNovas.
  ///
  /// In pt, this message translates to:
  /// **'Mensagens ({n} novas)'**
  String msgNovas(int n);

  /// No description provided for @msgTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Mensagens'**
  String get msgTitulo;

  /// No description provided for @msgConversas.
  ///
  /// In pt, this message translates to:
  /// **'Conversas'**
  String get msgConversas;

  /// No description provided for @msgVoceDois.
  ///
  /// In pt, this message translates to:
  /// **'Você: {texto}'**
  String msgVoceDois(String texto);

  /// No description provided for @msgLinhaSem.
  ///
  /// In pt, this message translates to:
  /// **'{nome}, {n} mensagens novas'**
  String msgLinhaSem(String nome, int n);

  /// No description provided for @msgPrimeira.
  ///
  /// In pt, this message translates to:
  /// **'Mande a primeira mensagem pra {nome}.'**
  String msgPrimeira(String nome);

  /// No description provided for @msgPara.
  ///
  /// In pt, this message translates to:
  /// **'Mensagem pra {nome}'**
  String msgPara(String nome);

  /// No description provided for @msgOffline.
  ///
  /// In pt, this message translates to:
  /// **'Offline'**
  String get msgOffline;

  /// No description provided for @avisosLigado.
  ///
  /// In pt, this message translates to:
  /// **'Ligado: chega mesmo com o app fechado.'**
  String get avisosLigado;

  /// No description provided for @avisosChega.
  ///
  /// In pt, this message translates to:
  /// **'Chega mesmo com o app fechado.'**
  String get avisosChega;

  /// No description provided for @avisosNegado.
  ///
  /// In pt, this message translates to:
  /// **'Recusado nos ajustes do celular.'**
  String get avisosNegado;

  /// No description provided for @avisosTelaInicio.
  ///
  /// In pt, this message translates to:
  /// **'Adicione o app à tela de início pra ligar.'**
  String get avisosTelaInicio;

  /// No description provided for @avisosConferindo.
  ///
  /// In pt, this message translates to:
  /// **'Conferindo...'**
  String get avisosConferindo;

  /// No description provided for @avisosSemSuporte.
  ///
  /// In pt, this message translates to:
  /// **'Este navegador não recebe avisos.'**
  String get avisosSemSuporte;

  /// No description provided for @avisosAvisar.
  ///
  /// In pt, this message translates to:
  /// **'Avisar neste celular'**
  String get avisosAvisar;

  /// No description provided for @avisosMesmoNoPc.
  ///
  /// In pt, this message translates to:
  /// **'Mesmo com você no PC'**
  String get avisosMesmoNoPc;

  /// No description provided for @avisosMesmoNoPcTexto.
  ///
  /// In pt, this message translates to:
  /// **'Avisa enquanto você está no PC.'**
  String get avisosMesmoNoPcTexto;

  /// No description provided for @avisosOQue.
  ///
  /// In pt, this message translates to:
  /// **'O que avisar'**
  String get avisosOQue;

  /// No description provided for @avisosErroMudar.
  ///
  /// In pt, this message translates to:
  /// **'Não consegui mudar o aviso neste celular.'**
  String get avisosErroMudar;

  /// No description provided for @avisosErroSalvar.
  ///
  /// In pt, this message translates to:
  /// **'Não salvou. Confira a internet.'**
  String get avisosErroSalvar;

  /// No description provided for @runasFaltaPrim.
  ///
  /// In pt, this message translates to:
  /// **'caminho principal'**
  String get runasFaltaPrim;

  /// No description provided for @runasFaltaPedra.
  ///
  /// In pt, this message translates to:
  /// **'pedra fundamental'**
  String get runasFaltaPedra;

  /// No description provided for @runasFaltaRunasPrim.
  ///
  /// In pt, this message translates to:
  /// **'runas da principal'**
  String get runasFaltaRunasPrim;

  /// No description provided for @runasFaltaSec.
  ///
  /// In pt, this message translates to:
  /// **'caminho secundário'**
  String get runasFaltaSec;

  /// No description provided for @runasFaltaRunasSec.
  ///
  /// In pt, this message translates to:
  /// **'2 runas da secundária'**
  String get runasFaltaRunasSec;

  /// No description provided for @runasFaltaFrag.
  ///
  /// In pt, this message translates to:
  /// **'fragmentos'**
  String get runasFaltaFrag;

  /// No description provided for @runasSalvar.
  ///
  /// In pt, this message translates to:
  /// **'Salvar e usar'**
  String get runasSalvar;

  /// No description provided for @runasFalta.
  ///
  /// In pt, this message translates to:
  /// **'Falta: {item}'**
  String runasFalta(String item);

  /// No description provided for @runasSem.
  ///
  /// In pt, this message translates to:
  /// **'Runas: {nome}'**
  String runasSem(String nome);

  /// No description provided for @runasPaginaNovaNome.
  ///
  /// In pt, this message translates to:
  /// **'Página nova'**
  String get runasPaginaNovaNome;

  /// No description provided for @runasTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Runas'**
  String get runasTitulo;

  /// No description provided for @runasNovaPagina.
  ///
  /// In pt, this message translates to:
  /// **'Nova página'**
  String get runasNovaPagina;

  /// No description provided for @runasEditarPagina.
  ///
  /// In pt, this message translates to:
  /// **'Editar página'**
  String get runasEditarPagina;

  /// No description provided for @runasVoltar.
  ///
  /// In pt, this message translates to:
  /// **'Voltar pras páginas'**
  String get runasVoltar;

  /// No description provided for @runasSemPagina.
  ///
  /// In pt, this message translates to:
  /// **'Você ainda não tem página de runas.'**
  String get runasSemPagina;

  /// No description provided for @runasSemEspaco.
  ///
  /// In pt, this message translates to:
  /// **'Sem espaço pra página nova: edite uma das suas.'**
  String get runasSemEspaco;

  /// No description provided for @runasIncompleta.
  ///
  /// In pt, this message translates to:
  /// **'Incompleta'**
  String get runasIncompleta;

  /// No description provided for @runasPaginaSem.
  ///
  /// In pt, this message translates to:
  /// **'{nome}, em uso'**
  String runasPaginaSem(String nome);

  /// No description provided for @runasEmUso.
  ///
  /// In pt, this message translates to:
  /// **'Em uso'**
  String get runasEmUso;

  /// No description provided for @runasPrincipal.
  ///
  /// In pt, this message translates to:
  /// **'Principal'**
  String get runasPrincipal;

  /// No description provided for @runasEscolhaCaminho.
  ///
  /// In pt, this message translates to:
  /// **'Escolha um caminho pra começar.'**
  String get runasEscolhaCaminho;

  /// No description provided for @runasSecundaria.
  ///
  /// In pt, this message translates to:
  /// **'Secundária'**
  String get runasSecundaria;

  /// No description provided for @runasEscolhaPrincipal.
  ///
  /// In pt, this message translates to:
  /// **'Escolha o principal primeiro.'**
  String get runasEscolhaPrincipal;

  /// No description provided for @runasEscolhaSecundario.
  ///
  /// In pt, this message translates to:
  /// **'Escolha o caminho secundário.'**
  String get runasEscolhaSecundario;

  /// No description provided for @runasFragmentos.
  ///
  /// In pt, this message translates to:
  /// **'Fragmentos'**
  String get runasFragmentos;

  /// No description provided for @runasNomePagina.
  ///
  /// In pt, this message translates to:
  /// **'Nome da página'**
  String get runasNomePagina;

  /// No description provided for @runasToque.
  ///
  /// In pt, this message translates to:
  /// **'Toque numa runa pra ver o que ela faz.'**
  String get runasToque;

  /// No description provided for @selChat.
  ///
  /// In pt, this message translates to:
  /// **'Chat da seleção'**
  String get selChat;

  /// No description provided for @selSairQ.
  ///
  /// In pt, this message translates to:
  /// **'Sair da seleção?'**
  String get selSairQ;

  /// No description provided for @selSairTexto.
  ///
  /// In pt, this message translates to:
  /// **'Você sai da partida, como no SAIR do LoL.'**
  String get selSairTexto;

  /// No description provided for @selSair.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get selSair;

  /// No description provided for @selFicar.
  ///
  /// In pt, this message translates to:
  /// **'Ficar'**
  String get selFicar;

  /// No description provided for @selSemChroma.
  ///
  /// In pt, this message translates to:
  /// **'Você não tem chroma desta skin'**
  String get selSemChroma;

  /// No description provided for @selChroma.
  ///
  /// In pt, this message translates to:
  /// **'Chroma'**
  String get selChroma;

  /// No description provided for @selChromaSem.
  ///
  /// In pt, this message translates to:
  /// **'Chroma que você não tem'**
  String get selChromaSem;

  /// No description provided for @selAramCaos.
  ///
  /// In pt, this message translates to:
  /// **'ARAM: Desordem'**
  String get selAramCaos;

  /// No description provided for @selBanimentos.
  ///
  /// In pt, this message translates to:
  /// **'Banimentos'**
  String get selBanimentos;

  /// No description provided for @selEscolhas.
  ///
  /// In pt, this message translates to:
  /// **'Escolhas'**
  String get selEscolhas;

  /// No description provided for @selPlanejamento.
  ///
  /// In pt, this message translates to:
  /// **'Planejamento'**
  String get selPlanejamento;

  /// No description provided for @selFinalizacao.
  ///
  /// In pt, this message translates to:
  /// **'Finalização'**
  String get selFinalizacao;

  /// No description provided for @selComecando.
  ///
  /// In pt, this message translates to:
  /// **'Começando'**
  String get selComecando;

  /// No description provided for @selTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Seleção'**
  String get selTitulo;

  /// No description provided for @selBoaPartida.
  ///
  /// In pt, this message translates to:
  /// **'Boa partida!'**
  String get selBoaPartida;

  /// No description provided for @selEscolhaCarta.
  ///
  /// In pt, this message translates to:
  /// **'Escolha uma carta'**
  String get selEscolhaCarta;

  /// No description provided for @selEscolhaPreparacao.
  ///
  /// In pt, this message translates to:
  /// **'Escolha sua preparação'**
  String get selEscolhaPreparacao;

  /// No description provided for @selSorteando.
  ///
  /// In pt, this message translates to:
  /// **'Sorteando campeões'**
  String get selSorteando;

  /// No description provided for @selSuaVezBanir.
  ///
  /// In pt, this message translates to:
  /// **'Sua vez de banir'**
  String get selSuaVezBanir;

  /// No description provided for @selSuaVezEscolher.
  ///
  /// In pt, this message translates to:
  /// **'Sua vez de escolher'**
  String get selSuaVezEscolher;

  /// No description provided for @selPrepareSe.
  ///
  /// In pt, this message translates to:
  /// **'Prepare-se, os bans já vão abrir'**
  String get selPrepareSe;

  /// No description provided for @selEsperandoBanirem.
  ///
  /// In pt, this message translates to:
  /// **'Esperando os outros banirem'**
  String get selEsperandoBanirem;

  /// No description provided for @selEscolhaSkin.
  ///
  /// In pt, this message translates to:
  /// **'Escolha sua skin'**
  String get selEscolhaSkin;

  /// No description provided for @selEsperandoEscolherem.
  ///
  /// In pt, this message translates to:
  /// **'Esperando os outros escolherem'**
  String get selEsperandoEscolherem;

  /// No description provided for @selDeclare.
  ///
  /// In pt, this message translates to:
  /// **'Declare seu campeão'**
  String get selDeclare;

  /// No description provided for @selEsperandoBans.
  ///
  /// In pt, this message translates to:
  /// **'Esperando os bans'**
  String get selEsperandoBans;

  /// No description provided for @selTodosEscolheram.
  ///
  /// In pt, this message translates to:
  /// **'Todos escolheram'**
  String get selTodosEscolheram;

  /// No description provided for @selVezTime.
  ///
  /// In pt, this message translates to:
  /// **'Vez do seu time'**
  String get selVezTime;

  /// No description provided for @selVezInimigo.
  ///
  /// In pt, this message translates to:
  /// **'Vez do time inimigo'**
  String get selVezInimigo;

  /// No description provided for @selEsperando.
  ///
  /// In pt, this message translates to:
  /// **'Esperando'**
  String get selEsperando;

  /// No description provided for @selBanaCampeao.
  ///
  /// In pt, this message translates to:
  /// **'Bana um campeão!'**
  String get selBanaCampeao;

  /// No description provided for @selEscolhaCampeao.
  ///
  /// In pt, this message translates to:
  /// **'Escolha seu campeão!'**
  String get selEscolhaCampeao;

  /// No description provided for @selEscolhaPreparacaoEx.
  ///
  /// In pt, this message translates to:
  /// **'Escolha sua preparação!'**
  String get selEscolhaPreparacaoEx;

  /// No description provided for @selChatSem.
  ///
  /// In pt, this message translates to:
  /// **'Chat, {n} novas'**
  String selChatSem(int n);

  /// No description provided for @selChatCurto.
  ///
  /// In pt, this message translates to:
  /// **'Chat'**
  String get selChatCurto;

  /// No description provided for @selTimeInimigos.
  ///
  /// In pt, this message translates to:
  /// **'Seu time'**
  String get selTimeInimigos;

  /// No description provided for @selInimigos.
  ///
  /// In pt, this message translates to:
  /// **'Inimigos'**
  String get selInimigos;

  /// No description provided for @selBans.
  ///
  /// In pt, this message translates to:
  /// **'Bans'**
  String get selBans;

  /// No description provided for @selNenhum.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum'**
  String get selNenhum;

  /// No description provided for @selBanPulado.
  ///
  /// In pt, this message translates to:
  /// **'Ban pulado'**
  String get selBanPulado;

  /// No description provided for @selAliado.
  ///
  /// In pt, this message translates to:
  /// **'Aliado'**
  String get selAliado;

  /// No description provided for @selInimigoN.
  ///
  /// In pt, this message translates to:
  /// **'Inimigo {n}'**
  String selInimigoN(int n);

  /// No description provided for @selQuer.
  ///
  /// In pt, this message translates to:
  /// **'Quer {nome}'**
  String selQuer(String nome);

  /// No description provided for @selPedirTroca.
  ///
  /// In pt, this message translates to:
  /// **'Pedir troca com {nome}'**
  String selPedirTroca(String nome);

  /// No description provided for @selBanindo.
  ///
  /// In pt, this message translates to:
  /// **'Banindo'**
  String get selBanindo;

  /// No description provided for @selEscolhendo.
  ///
  /// In pt, this message translates to:
  /// **'Escolhendo'**
  String get selEscolhendo;

  /// No description provided for @selSairSem.
  ///
  /// In pt, this message translates to:
  /// **'Sair da seleção'**
  String get selSairSem;

  /// No description provided for @selSairBotao.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get selSairBotao;

  /// No description provided for @dicaTelaInicio.
  ///
  /// In pt, this message translates to:
  /// **'Dica: adicione à Tela de Início (Compartilhar > Adicionar). Pelo ícone, entre de novo com a sua conta.'**
  String get dicaTelaInicio;

  /// No description provided for @mainConectando.
  ///
  /// In pt, this message translates to:
  /// **'Conectando'**
  String get mainConectando;

  /// No description provided for @mainUmInstante.
  ///
  /// In pt, this message translates to:
  /// **'Só um instante.'**
  String get mainUmInstante;

  /// No description provided for @mainFaltaPc.
  ///
  /// In pt, this message translates to:
  /// **'Falta o PC'**
  String get mainFaltaPc;

  /// No description provided for @mainFaltaPcTexto.
  ///
  /// In pt, this message translates to:
  /// **'No painel do Ping no PC, abra Conta e entre com {conta}. Ele aparece aqui na hora.'**
  String mainFaltaPcTexto(String conta);

  /// No description provided for @mainEstaConta.
  ///
  /// In pt, this message translates to:
  /// **'esta conta'**
  String get mainEstaConta;

  /// No description provided for @mainPcConectado.
  ///
  /// In pt, this message translates to:
  /// **'PC conectado'**
  String get mainPcConectado;

  /// No description provided for @mainPcSemSinal.
  ///
  /// In pt, this message translates to:
  /// **'PC sem sinal'**
  String get mainPcSemSinal;

  /// No description provided for @mainPingCelular.
  ///
  /// In pt, this message translates to:
  /// **'Ping no celular'**
  String get mainPingCelular;

  /// No description provided for @mainEntreTexto.
  ///
  /// In pt, this message translates to:
  /// **'Entre com a mesma conta Ping do painel do PC. Não tem? Crie aqui e entre com ela no PC, em Conta.'**
  String get mainEntreTexto;

  /// No description provided for @mainOutraConta.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com outra conta'**
  String get mainOutraConta;

  /// No description provided for @mainEsperandoPc.
  ///
  /// In pt, this message translates to:
  /// **'Esperando o PC'**
  String get mainEsperandoPc;

  /// No description provided for @mainEsperandoPcTexto.
  ///
  /// In pt, this message translates to:
  /// **'O Ping manda o primeiro sinal em alguns segundos.'**
  String get mainEsperandoPcTexto;

  /// No description provided for @mainPcSemSinalTexto.
  ///
  /// In pt, this message translates to:
  /// **'O PC está desligado, sem internet ou com o Ping fechado.'**
  String get mainPcSemSinalTexto;

  /// No description provided for @mainFechandoLolTexto.
  ///
  /// In pt, this message translates to:
  /// **'O LoL e o Riot Client estão fechando no PC.'**
  String get mainFechandoLolTexto;

  /// No description provided for @mainLolFechado.
  ///
  /// In pt, this message translates to:
  /// **'LoL fechado'**
  String get mainLolFechado;

  /// No description provided for @mainLolFechadoTexto.
  ///
  /// In pt, this message translates to:
  /// **'Abra o LoL no PC pra acompanhar por aqui.'**
  String get mainLolFechadoTexto;

  /// No description provided for @mainAbrirLol.
  ///
  /// In pt, this message translates to:
  /// **'Abrir o LoL'**
  String get mainAbrirLol;

  /// No description provided for @mainEntreFila.
  ///
  /// In pt, this message translates to:
  /// **'Entre na fila no PC e acompanhe por aqui.'**
  String get mainEntreFila;

  /// No description provided for @mainSelecao.
  ///
  /// In pt, this message translates to:
  /// **'Seleção de campeões'**
  String get mainSelecao;

  /// No description provided for @mainSelecaoTexto.
  ///
  /// In pt, this message translates to:
  /// **'Logo dá pra escolher o campeão por aqui.'**
  String get mainSelecaoTexto;

  /// No description provided for @mainPartidaAcabou.
  ///
  /// In pt, this message translates to:
  /// **'A partida acabou.'**
  String get mainPartidaAcabou;

  /// No description provided for @mainEstimado.
  ///
  /// In pt, this message translates to:
  /// **'Estimado {tempo}'**
  String mainEstimado(String tempo);

  /// No description provided for @mainAceita.
  ///
  /// In pt, this message translates to:
  /// **'Partida aceita'**
  String get mainAceita;

  /// No description provided for @mainAceitaTexto.
  ///
  /// In pt, this message translates to:
  /// **'Esperando os outros jogadores.'**
  String get mainAceitaTexto;

  /// No description provided for @mainRecusada.
  ///
  /// In pt, this message translates to:
  /// **'Partida recusada'**
  String get mainRecusada;

  /// No description provided for @mainRecusadaTexto.
  ///
  /// In pt, this message translates to:
  /// **'Você recusou esta partida.'**
  String get mainRecusadaTexto;

  /// No description provided for @maisPartida.
  ///
  /// In pt, this message translates to:
  /// **'Partida encontrada'**
  String get maisPartida;

  /// No description provided for @mainEncontrada.
  ///
  /// In pt, this message translates to:
  /// **'Partida encontrada'**
  String get mainEncontrada;

  /// No description provided for @mainAceitarQ.
  ///
  /// In pt, this message translates to:
  /// **'Aceitar?'**
  String get mainAceitarQ;

  /// No description provided for @mainFecharRiotQ.
  ///
  /// In pt, this message translates to:
  /// **'Fechar o Riot Client?'**
  String get mainFecharRiotQ;

  /// No description provided for @mainFecharLolQ.
  ///
  /// In pt, this message translates to:
  /// **'Fechar o LoL?'**
  String get mainFecharLolQ;

  /// No description provided for @mainFecharRiotTexto.
  ///
  /// In pt, this message translates to:
  /// **'O Riot Client fecha no PC.'**
  String get mainFecharRiotTexto;

  /// No description provided for @mainFecharFilaTexto.
  ///
  /// In pt, this message translates to:
  /// **'Você sai da fila e o LoL fecha no PC, junto com o Riot Client.'**
  String get mainFecharFilaTexto;

  /// No description provided for @mainFecharLolTexto.
  ///
  /// In pt, this message translates to:
  /// **'O LoL fecha no PC, junto com o Riot Client.'**
  String get mainFecharLolTexto;

  /// No description provided for @mainFechar.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get mainFechar;

  /// No description provided for @mainFecharRiot.
  ///
  /// In pt, this message translates to:
  /// **'Fechar o Riot Client'**
  String get mainFecharRiot;

  /// No description provided for @mainFecharLol.
  ///
  /// In pt, this message translates to:
  /// **'Fechar o LoL'**
  String get mainFecharLol;

  /// No description provided for @mainLigarSons.
  ///
  /// In pt, this message translates to:
  /// **'Ligar sons'**
  String get mainLigarSons;

  /// No description provided for @mainDesligarSons.
  ///
  /// In pt, this message translates to:
  /// **'Desligar sons'**
  String get mainDesligarSons;

  /// No description provided for @mainFechandoLol.
  ///
  /// In pt, this message translates to:
  /// **'Fechando o LoL'**
  String get mainFechandoLol;

  /// No description provided for @criarConvidado.
  ///
  /// In pt, this message translates to:
  /// **'Convidado'**
  String get criarConvidado;

  /// No description provided for @runasEditarNome.
  ///
  /// In pt, this message translates to:
  /// **'Editar {nome}'**
  String runasEditarNome(String nome);

  /// No description provided for @selSkinSem.
  ///
  /// In pt, this message translates to:
  /// **'{nome}, você não tem'**
  String selSkinSem(String nome);

  /// No description provided for @runaUma.
  ///
  /// In pt, this message translates to:
  /// **'Runa'**
  String get runaUma;

  /// No description provided for @avisoFilaN.
  ///
  /// In pt, this message translates to:
  /// **'Entrou na fila'**
  String get avisoFilaN;

  /// No description provided for @avisoFilaT.
  ///
  /// In pt, this message translates to:
  /// **'Quando você ou o líder da sala entra na fila.'**
  String get avisoFilaT;

  /// No description provided for @avisoPartidaN.
  ///
  /// In pt, this message translates to:
  /// **'Partida encontrada'**
  String get avisoPartidaN;

  /// No description provided for @avisoPartidaT.
  ///
  /// In pt, this message translates to:
  /// **'Quando a fila acha partida.'**
  String get avisoPartidaT;

  /// No description provided for @avisoVezN.
  ///
  /// In pt, this message translates to:
  /// **'Sua vez'**
  String get avisoVezN;

  /// No description provided for @avisoVezT.
  ///
  /// In pt, this message translates to:
  /// **'Quando chega sua vez de escolher ou banir.'**
  String get avisoVezT;

  /// No description provided for @avisoTrocaN.
  ///
  /// In pt, this message translates to:
  /// **'Pedido de troca'**
  String get avisoTrocaN;

  /// No description provided for @avisoTrocaT.
  ///
  /// In pt, this message translates to:
  /// **'Quando um aliado pede troca na seleção.'**
  String get avisoTrocaT;

  /// No description provided for @avisoConviteN.
  ///
  /// In pt, this message translates to:
  /// **'Convite pra sala'**
  String get avisoConviteN;

  /// No description provided for @avisoConviteT.
  ///
  /// In pt, this message translates to:
  /// **'Quando alguém chama você pra sala.'**
  String get avisoConviteT;

  /// No description provided for @avisoMensagemN.
  ///
  /// In pt, this message translates to:
  /// **'Mensagens'**
  String get avisoMensagemN;

  /// No description provided for @avisoMensagemT.
  ///
  /// In pt, this message translates to:
  /// **'Mensagem de amigo no chat privado ou da sala.'**
  String get avisoMensagemT;

  /// No description provided for @avisoLolProntoN.
  ///
  /// In pt, this message translates to:
  /// **'LoL aberto'**
  String get avisoLolProntoN;

  /// No description provided for @avisoLolProntoT.
  ///
  /// In pt, this message translates to:
  /// **'Quando o LoL que você abriu pelo celular fica pronto.'**
  String get avisoLolProntoT;

  /// No description provided for @avisoFimN.
  ///
  /// In pt, this message translates to:
  /// **'Fim da partida'**
  String get avisoFimN;

  /// No description provided for @avisoFimT.
  ///
  /// In pt, this message translates to:
  /// **'Vitória ou derrota, com o seu placar.'**
  String get avisoFimT;

  /// No description provided for @avisoResumoN.
  ///
  /// In pt, this message translates to:
  /// **'Resumo do dia'**
  String get avisoResumoN;

  /// No description provided for @avisoResumoT.
  ///
  /// In pt, this message translates to:
  /// **'Quando você fecha o LoL.'**
  String get avisoResumoT;
}

class _TxtDelegate extends LocalizationsDelegate<Txt> {
  const _TxtDelegate();

  @override
  Future<Txt> load(Locale locale) {
    return SynchronousFuture<Txt>(lookupTxt(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_TxtDelegate old) => false;
}

Txt lookupTxt(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return TxtEn();
    case 'es':
      return TxtEs();
    case 'pt':
      return TxtPt();
  }

  throw FlutterError(
    'Txt.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
