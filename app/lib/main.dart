import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'atualizacao.dart';
import 'conexao.dart';
import 'navegador.dart';
import 'push.dart';
import 'som.dart';
import 'tema.dart';
import 'textura.dart';

part 'sala.dart';
part 'criar_sala.dart';
part 'escolha.dart';
part 'runas.dart';
part 'selecao.dart';
part 'arena.dart';
part 'troca.dart';
part 'cartas.dart';
part 'feiticos.dart';
part 'posicao.dart';
part 'abertura.dart';
part 'mensagens.dart';
part 'avisos.dart';
part 'escolher_tema.dart';
part 'partida.dart';
part 'fim.dart';
part 'navegacao.dart';
part 'conta.dart';

const _firebase = FirebaseOptions(
  apiKey: 'AIzaSyABdomDfEhtp3W-LE9SeRLq7f1iiK8JOns',
  appId: '1:1094921770436:web:83ef390681d99c01734091',
  messagingSenderId: '1094921770436',
  projectId: 'ping-celular',
  authDomain: 'ping-celular.firebaseapp.com',
  databaseURL: 'https://ping-celular-default-rtdb.firebaseio.com',
  storageBucket: 'ping-celular.firebasestorage.app',
);

/// Teste local: `--dart-define=EMU=true` usa os emuladores do Firebase.
const _emu = bool.fromEnvironment('EMU');

Future<void> main() async {
  Navegador.lerLink();
  usePathUrlStrategy(); // sem #/ no link
  WidgetsFlutterBinding.ensureInitialized();
  await Temas.carregar();
  // modo vitrine (`?vitrine=<tela>`): dados de mentira, nada de Firebase
  if (ConexaoVitrine.doLink != null) return runApp(const PingApp());
  await Firebase.initializeApp(options: _firebase);
  if (_emu) {
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9412);
    FirebaseDatabase.instance.useDatabaseEmulator('127.0.0.1', 9411);
  }
  runApp(const PingApp());
}

class PingApp extends StatelessWidget {
  const PingApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Temas.mudou,
    builder: (_, _) => MaterialApp(
      title: 'Ping',
      debugShowCheckedModeBanner: false,
      theme: tema(),
      builder: (context, child) =>
          AvisoVersaoNova(child: child ?? const SizedBox.shrink()),
      home: const Inicio(),
    ),
  );
}

Duration _dur(BuildContext c, int ms) => MediaQuery.disableAnimationsOf(c)
    ? Duration.zero
    : Duration(milliseconds: ms);

class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  final nav = Navegador();
  late final con = ConexaoVitrine.doLink != null
      ? ConexaoVitrine(nav, ConexaoVitrine.doLink!)
      : Conexao(nav);
  StreamSubscription? _resp;
  bool _destravou = false;
  bool _avisou = false;
  String? _ultimoAviso;
  String _ultimaVez = '';
  String? _ultimaTroca;
  final _sons = _SonsDoEstado();

  /// Aba aberta e pra que lado foi a última troca (a página nova entra por esse lado).
  Aba _aba = Aba.aoVivo;
  int _direcao = 1;
  String? _faseVista;
  int _rodadaAba = -1;

  /// Abas desenhadas escondidas enquanto a abertura do `index.html` está na frente: a primeira vez que cada
  /// aba aparece pesa (código que o navegador ainda não otimizou, shaders, letras, ícones) e a entrada dela
  /// rodava a 25 quadros por segundo. Desenhada uma vez antes, a primeira troca já sai lisa.
  List<Aba>? _aquecer;
  Future<void>? _aquecimento;

  /// Tempo pra rodar as entradas das abas (320ms + o maior atraso) com folga.
  static const _tempoAquecer = Duration(milliseconds: 650);

  Future<void> _aquecerAbas(List<Aba> abas) {
    if (abas.isEmpty || MediaQuery.disableAnimationsOf(context)) {
      return Future.value();
    }
    _aquecer = abas;
    return Future.delayed(_tempoAquecer, () {
      if (mounted) setState(() => _aquecer = null);
    });
  }

  void _trocarAba(Aba nova) {
    if (nova == _aba) return;
    setState(() {
      _direcao = nova.index > _aba.index ? 1 : -1;
      _aba = nova;
    });
  }

  /// Partida encontrada ou seleção começando puxam pra aba Ao vivo, de onde estiver (uma vez, na troca de
  /// fase: depois dá pra sair de novo). Na vitrine, a tela pedida diz a aba.
  void _abaPelaFase() {
    final c = con;
    if (c is ConexaoVitrine && c.rodada != _rodadaAba) {
      _rodadaAba = c.rodada;
      final nova = switch (c.tela) {
        'hoje' => Aba.hoje,
        'mais' || 'avisos' || 'temas' => Aba.mais,
        _ => Aba.aoVivo,
      };
      if (nova != _aba) {
        _direcao = nova.index > _aba.index ? 1 : -1;
        _aba = nova;
      }
    }
    final fase = con.estado.isEmpty ? null : con.fase;
    if (fase != _faseVista && (fase == 'ReadyCheck' || fase == 'ChampSelect')) {
      if (_aba != Aba.aoVivo) _direcao = -1;
      _aba = Aba.aoVivo;
    }
    _faseVista = fase;
  }

  @override
  void initState() {
    super.initState();
    con.addListener(_mudou);
    // deu certo, a própria tela mostra: só avisa quando dá errado
    _resp = con.respostas.stream.listen((r) {
      if (!r.ok) {
        som.tocar('erro');
        _aviso(r.msg, erro: true);
      }
    });
    con.iniciar();
    som.iniciar();
    _Lidas.eu.carregar();
    WakelockPlus.enable().catchError((_) {});
  }

  // Ícones baixados e decodificados assim que o PC manda a lista (campeões da grade, avatares dos amigos,
  // feitiços): quando a grade ou a folha abrem já estão na memória e não pipocam no meio da animação.
  // Só olha de novo quando a lista muda (a Conexao mantém a mesma instância do que não mudou).
  Object? _amigosVistos, _feitVistos, _gradeVista;
  final _jaCarregadas = <String>{};

  void _preCarregar(Object? sel) {
    final urls = <String>[];
    final amigos = con.estado['amigos'];
    if (!identical(amigos, _amigosVistos)) {
      _amigosVistos = amigos;
      for (final a in amigos is List ? amigos : const []) {
        final i = a is Map ? (a['icone'] as num?)?.toInt() ?? 0 : 0;
        if (i > 0) urls.add(_icone(i));
      }
    }
    final feit = con.estado['feiticos'];
    if (!identical(feit, _feitVistos)) {
      _feitVistos = feit;
      for (final f in _listaFeiticos(con)) {
        final u = _iconeFeitico(con, (f['id'] as num?)?.toInt() ?? 0);
        if (u.isNotEmpty) urls.add(u);
      }
    }
    final pick = sel is Map ? sel['pickaveis'] : null;
    final ban = sel is Map ? sel['baniveis'] : null;
    final chave =
        '${pick is List ? pick.length : 0}|${ban is List ? ban.length : 0}';
    if (chave != _gradeVista) {
      _gradeVista = chave;
      for (final l in [pick, ban]) {
        for (final id in l is List ? l : const []) {
          if (id is num && id > 0) urls.add(_iconeCampeao(id.toInt()));
        }
      }
    }
    // teto: lista gigante vinda do PC não vira milhares de downloads (são ~170 campeões)
    final novas = urls.where(_jaCarregadas.add).take(400).toList();
    if (novas.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final u in novas) {
        precacheImage(
          NetworkImage(
            u,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          ),
          context,
          onError: (_, _) {},
        );
      }
    });
  }

  void _mudou() {
    if (!mounted) return;
    // erro com o PC já aberto: só avisa
    if (con.vinculo == Vinculo.ok && con.erro != null && !_avisou) {
      _avisou = true;
      _aviso(con.erro!, erro: true);
    }
    // partida encontrada: toca e vibra uma vez por partida
    final p = con.estado['partida'];
    final chave = p is Map && p['resposta'] == 'None' ? '${p['inicio']}' : null;
    // sua vez na selecao (banir ou escolher): toca e vibra quando comeca
    final sel = con.estado['selecao'];
    final vez = con.fase == 'ChampSelect' && sel is Map
        ? '${sel['minha_vez'] ?? ''}'
        : '';
    if (vez.isNotEmpty && vez != _ultimaVez) {
      nav.avisar(vez == 'ban' ? 'vez_ban' : 'vez_pick');
    }
    _ultimaVez = vez;
    // aliado pediu troca (campeão, posição ou ordem): toca o aviso do client e vibra
    final troca = con.fase == 'ChampSelect' && sel is Map
        ? _trocaPendente(sel)
        : null;
    final recebida = troca != null && troca.troca['estado'] == 'RECEIVED'
        ? '${troca.tipo}-${troca.troca['cell']}'
        : null;
    if (recebida != null && recebida != _ultimaTroca) {
      nav.avisar('troca_recebida');
    }
    _ultimaTroca = recebida;
    if (con.fase == 'ReadyCheck' && chave != null && chave != _ultimoAviso) {
      _ultimoAviso = chave;
      nav.avisar('partida');
    }
    _sons.ouvir(con);
    // avisos no celular: regrava a inscrição ao abrir e quando muda de conta ou de PC
    if (con.vinculo == Vinculo.ok) Avisos.eu(con).conferir();
    _abaPelaFase();
    _preCarregar(sel);
    _abrirFolhaVitrine();
    setState(() {});
  }

  /// Modo vitrine: telas que são uma folha (runas, feitiços, mensagens, criar sala) abrem ela sozinhas.
  int _folhaVitrine = -1;
  void _abrirFolhaVitrine() {
    final c = con;
    if (c is! ConexaoVitrine || _folhaVitrine == c.rodada || !c.pronto) return;
    // trocou de tela: a folha da tela anterior fecha
    if (_folhaVitrine >= 0) Navigator.of(context).popUntil((r) => r.isFirst);
    _folhaVitrine = c.rodada;
    final folha = c.folha;
    if (folha == null || c.estado.isEmpty) return;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      switch (folha) {
        case 'runas':
          _abrirRunas(context, con);
        case 'feiticos':
          _abrirFeiticos(context, con);
        case 'mensagens':
          _abrirMensagens(context, con);
        case 'criar_sala':
          _abrirSala(context, con);
      }
    });
  }

  void _aviso(String msg, {bool erro = false}) {
    if (!mounted || msg.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Losango(cor: erro ? Cor.vermelho : Cor.teal, tamanho: 8),
              const SizedBox(width: 12),
              Expanded(child: Text(msg)),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// O iPhone só libera som e tela acesa depois de um toque: o primeiro toque em qualquer lugar destrava,
  /// sem tela de "toque pra começar". A tela acesa também é pedida ao abrir (o Android aceita sem toque).
  Future<void>? _fontes;

  void _liberar() {
    if (_destravou) return;
    _destravou = true;
    nav.liberarSom();
    WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    _resp?.cancel();
    con.removeListener(_mudou);
    con.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // depois do quadro já com a tela certa: a abertura do index.html sai por cima dela
    // e com as fontes já baixadas (no máximo 1,5s): senão o texto troca de fonte e se rearruma logo
    // depois que a abertura some
    if (con.pronto) {
      // a abertura espera também as outras abas serem desenhadas uma vez por baixo dela
      _aquecimento ??= con.vinculo == Vinculo.ok
          ? _aquecerAbas([
              for (final a in Aba.values)
                if (a != _aba) a,
            ])
          : Future.value();
      _fontes ??= Future.wait([esperarFontes(), _aquecimento!]);
      _fontes!.then(
        (_) => WidgetsBinding.instance.addPostFrameCallback(
          (_) => nav.tirarAbertura(),
        ),
      );
    }
    // SafeArea não serve na web (o engine não repassa a área segura): o relógio e o home indicator vêm do CSS
    final seg = nav.areaSegura();
    final deitado = _deitado(context);
    final telaCheia = _telaCheia;
    // na sala (também na fila com sala): tela própria, sem rolagem
    final salaCheia =
        !telaCheia &&
        con.vinculo == Vinculo.ok &&
        con.estado.isNotEmpty &&
        con.pcOnline &&
        (con.fase == 'Lobby' || con.fase == 'Matchmaking') &&
        con.estado['sala'] is Map;
    // tela de carregamento do jogo: os 10 jogadores ocupam a tela toda, sem rolar
    // fim de partida: vitória ou derrota na tela toda
    final fim = !telaCheia && con.vinculo == Vinculo.ok && con.pcOnline
        ? _fimDe(con)
        : null;
    final carregaCheia =
        !telaCheia &&
        fim == null &&
        con.vinculo == Vinculo.ok &&
        con.pcOnline &&
        _emCarregamento(con);
    // seleção, tela de carregamento e fim de partida tomam a tela: sem barra, sempre na aba Ao vivo
    final imersiva = telaCheia || fim != null || carregaCheia;
    const abas = Aba.values;
    final aba = imersiva ? Aba.aoVivo : _aba;
    final comBarra = con.vinculo == Vinculo.ok && !imersiva;
    // em pé, barra embaixo; deitado, as abas vão no meio do topo (trilho na lateral comia a largura)
    final barra = _BarraAnimada(
      barra: comBarra && !deitado
          ? _BarraAbas(
              key: const ValueKey('barra'),
              atual: aba,
              aoTrocar: _trocarAba,
              con: con,
              seg: seg,
              abas: abas,
            )
          : null,
    );
    final abasNoTopo = comBarra && deitado
        ? _BarraAbas(
            key: const ValueKey('abas-topo'),
            atual: aba,
            aoTrocar: _trocarAba,
            con: con,
            seg: seg,
            abas: abas,
            noTopo: true,
          )
        : null;
    // deitado o iPhone recua os dois lados por causa do notch (47 cada): o conteúdo já tem margem própria,
    // então entra um pouco no recuo, sem chegar no recorte da câmera
    double lado(double s) => deitado ? math.max(0, s - 16) : s;
    final coluna = Column(
      children: [
        // deitado na seleção, a altura é toda da seleção
        // sem animar a altura: refazia o layout da seleção inteira a cada quadro junto
        // com o fade dela. O topo some na hora (a seleção entra por cima) e volta em fade
        AnimatedSwitcher(
          duration: _dur(context, 220),
          switchInCurve: curvaSaida,
          layoutBuilder: (atual, _) => atual ?? const SizedBox.shrink(),
          child: telaCheia && deitado
              ? const SizedBox(
                  key: ValueKey('sem-topo'),
                  width: double.infinity,
                )
              : _Topo(key: const ValueKey('topo'), con: con, abas: abasNoTopo),
        ),
        Expanded(
          child: _TrocaAbas(
            aba: aba,
            direcao: _direcao,
            child: switch (aba) {
              // deitado, a área da barrinha do iPhone fica fora do corpo: Ao vivo guarda o respiro, as
              // abas que rolam passam por baixo dela (nada cortado numa faixa)
              Aba.aoVivo => Padding(
                padding: EdgeInsets.only(
                  bottom: comBarra && deitado ? seg.base : 0,
                ),
                child: _aoVivo(
                  telaCheia: telaCheia,
                  fim: fim,
                  carregaCheia: carregaCheia,
                  salaCheia: salaCheia,
                  deitado: deitado,
                  seg: seg,
                ),
              ),
              Aba.hoje => _AbaHoje(con: con, base: deitado ? seg.base : 0),
              Aba.mais => _AbaMais(con: con, base: deitado ? seg.base : 0),
            },
          ),
        ),
        if (nav.ehIphone && !nav.instalado && !deitado)
          const _Rodape(
            'Dica: adicione à Tela de Início (Compartilhar > Adicionar). Pelo ícone, entre de novo com a sua conta.',
          ),
        if (!deitado) barra,
      ],
    );
    return Listener(
      onPointerDown: (_) => _liberar(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        body: _ComAquecimento(
          abas: _aquecer,
          aba: (a) => switch (a) {
            Aba.hoje => _AbaHoje(con: con, base: deitado ? seg.base : 0),
            Aba.mais => _AbaMais(con: con, base: deitado ? seg.base : 0),
            Aba.aoVivo => const SizedBox.shrink(),
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -1.1),
                radius: 1.3,
                colors: [
                  Cor.ouro.withValues(alpha: 0.12),
                  Cor.fundo.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Stack(
              children: [
                const Positioned.fill(child: TexturaFundo()),
                Padding(
                  // a barra vai até a borda e cuida da área segura dela (barrinha do iPhone)
                  padding: EdgeInsets.only(
                    top: seg.topo,
                    bottom: telaCheia || comBarra ? 0 : seg.base,
                    left: lado(seg.esq),
                    right: lado(seg.dir),
                  ),
                  child: coluna,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Aba Ao vivo: o app de sempre, que segue a fase do LoL.
  Widget _aoVivo({
    required bool telaCheia,
    required Map? fim,
    required bool carregaCheia,
    required bool salaCheia,
    required bool deitado,
    required ({double topo, double base, double esq, double dir}) seg,
  }) => AnimatedSwitcher(
    duration: _dur(context, 380),
    switchInCurve: curvaSaida,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
    child: telaCheia
        ? Padding(
            key: const ValueKey('selecao'),
            padding: EdgeInsets.fromLTRB(
              16,
              deitado ? 12 : 4,
              16,
              // botão colado no fim da tela, só acima da barrinha do iPhone
              seg.base > 0 ? math.max(6, seg.base - 14) : 12,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: deitado ? 1100 : 560),
                child: _Selecao(con: con, sel: con.estado['selecao'] as Map),
              ),
            ),
          )
        : fim != null
        ? KeyedSubtree(
            key: ValueKey('fim-${fim['resultado']}'),
            child: _Fim(fim: fim),
          )
        : carregaCheia
        ? Padding(
            key: const ValueKey('carregamento'),
            padding: EdgeInsets.fromLTRB(
              deitado ? 12 : 14,
              deitado ? 0 : 4,
              deitado ? 12 : 14,
              12,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: deitado ? 1100 : 520),
                child: _Carregamento(con: con),
              ),
            ),
          )
        : salaCheia
        ? Padding(
            key: const ValueKey('sala'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: deitado ? 1000 : 520),
                child: deitado ? _SalaDeitada(con: con) : _SalaEmPe(con: con),
              ),
            ),
          )
        : KeyedSubtree(key: const ValueKey('rolar'), child: _rolar(deitado)),
  );

  /// Seleção de campeões ocupa a tela toda (grade e quadro preenchem a altura); o resto rola no meio.
  bool get _telaCheia =>
      con.vinculo == Vinculo.ok &&
      con.estado.isNotEmpty &&
      con.pcOnline &&
      con.fase == 'ChampSelect' &&
      con.estado['selecao'] is Map;

  Widget _rolar(bool deitado) {
    // deitado na sala (ou na fila com sala), sala e chat vão lado a lado
    final largo =
        deitado &&
        (con.fase == 'Lobby' || con.fase == 'Matchmaking') &&
        con.estado['sala'] is Map;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          // deitado, os cartões ficam lado a lado por dentro: precisam de mais largura
          constraints: BoxConstraints(
            maxWidth: largo ? 920 : (deitado ? 760 : 440),
          ),
          child: AnimatedSwitcher(
            duration: _dur(context, 380),
            switchInCurve: curvaSaida,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(a),
                // cartão com sombra grande numa camada própria: a escala só move a camada pronta,
                // não redesenha o blur a cada quadro
                child: RepaintBoundary(child: c),
              ),
            ),
            child: _conteudo(),
          ),
        ),
      ),
    );
  }

  Widget _conteudo() {
    switch (con.vinculo) {
      case Vinculo.carregando:
        return const _Mensagem(
          key: ValueKey(Vinculo.carregando),
          icone: _Pulso(),
          titulo: 'Conectando',
          texto: 'Só um instante.',
        );
      case Vinculo.sem:
      case Vinculo.erro:
        return _Entrar(key: const ValueKey('entrar'), con: con);
      case Vinculo.semPc:
        return _Mensagem(
          key: const ValueKey('sem-pc'),
          icone: Icon(
            Icons.desktop_windows_outlined,
            color: Cor.ouro,
            size: 40,
          ),
          titulo: 'Falta o PC',
          texto:
              'No painel do Ping no PC, abra Conta e entre com ${con.email ?? 'esta conta'}. Ele aparece aqui na hora.',
          extra: _BotaoSairConta(con: con),
        );
      case Vinculo.ok:
        return _Estado(key: ValueKey(_chaveEstado()), con: con);
    }
  }

  String _chaveEstado() {
    if (con.estado.isEmpty) return 'esperando';
    if (!con.pcOnline) return 'offline';
    // mesma chave da barra de abertura: ela completa sem trocar de tela
    if (con.abriu != null) return 'Fechado--abrindo';
    final p = con.estado['partida'];
    final abrindo = con.estado['abrindo'] == true
        ? '-abrindo'
        : con.estado['fechando'] == true
        ? '-fechando'
        : '';
    return '${con.fase}-${p is Map ? p['resposta'] : ''}$abrindo';
  }
}

// ---------------- topo ----------------

class _Topo extends StatelessWidget {
  const _Topo({super.key, required this.con, this.abas});
  final Conexao con;

  /// Deitado: as abas no meio, entre o nome e os botões.
  final Widget? abas;

  @override
  Widget build(BuildContext context) {
    final ok = con.vinculo == Vinculo.ok;
    final online = ok && con.pcOnline;
    return Padding(
      // deitado a altura é pouca: o topo encolhe
      padding: _deitado(context)
          ? const EdgeInsets.fromLTRB(20, 8, 20, 2)
          : const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text('PING', style: fonteTitulo(18, cor: Cor.ouroClaro)),
          // abas no meio do que sobra; em tela estreita encolhem em vez de passar por cima dos botões
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedSwitcher(
                  duration: _dur(context, 260),
                  switchInCurve: curvaSaida,
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, -0.3),
                        end: Offset.zero,
                      ).animate(a),
                      child: c,
                    ),
                  ),
                  child: abas ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: _dur(context, 250),
            curve: curvaSaida,
            child: AnimatedSwitcher(
              duration: _dur(context, 200),
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween(begin: 0.7, end: 1.0).animate(a),
                  child: c,
                ),
              ),
              child: online && _BotaoFechar.pode(con)
                  ? _BotaoFechar(con: con)
                  : const SizedBox.shrink(),
            ),
          ),
          AnimatedSize(
            duration: _dur(context, 250),
            curve: curvaSaida,
            child: AnimatedSwitcher(
              duration: _dur(context, 200),
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween(begin: 0.7, end: 1.0).animate(a),
                  child: c,
                ),
              ),
              child: online && _BotaoMensagens.pode(con)
                  ? _BotaoMensagens(con: con)
                  : const SizedBox.shrink(),
            ),
          ),
          const _BotaoMudo(),
          const SizedBox(width: 6),
          AnimatedOpacity(
            opacity: ok ? 1 : 0,
            duration: _dur(context, 300),
            // só o losango; tocar mostra o status num balão
            child: _StatusPc(online: online),
          ),
        ],
      ),
    );
  }
}

/// Losango do status do PC no topo. Tocar mostra o status num balão.
class _StatusPc extends StatefulWidget {
  const _StatusPc({required this.online});
  final bool online;

  @override
  State<_StatusPc> createState() => _StatusPcState();
}

class _StatusPcState extends State<_StatusPc>
    with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  final _elo = LayerLink();
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 140),
  );
  late final _curva = CurvedAnimation(
    parent: _anim,
    curve: curvaSaida,
    reverseCurve: Curves.easeIn,
  );
  Timer? _fechar;

  String get _texto => widget.online ? 'PC conectado' : 'PC sem sinal';
  Color get _cor => widget.online ? Cor.teal : Cor.vermelho;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rapido = MediaQuery.disableAnimationsOf(context);
    _anim.duration = Duration(milliseconds: rapido ? 1 : 180);
    _anim.reverseDuration = Duration(milliseconds: rapido ? 1 : 140);
  }

  void _mostrar() {
    _fechar?.cancel();
    if (_anim.status == AnimationStatus.forward ||
        _anim.status == AnimationStatus.completed) {
      _esconder();
      return;
    }
    _portal.show();
    _anim.forward();
    _fechar = Timer(const Duration(milliseconds: 1800), _esconder);
  }

  void _esconder() {
    _fechar?.cancel();
    if (!_portal.isShowing) return;
    _anim.reverse().whenComplete(() {
      if (mounted && _anim.isDismissed) _portal.hide();
    });
  }

  @override
  void dispose() {
    _fechar?.cancel();
    _curva.dispose();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _elo,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (_) => CompositedTransformFollower(
          link: _elo,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(-2, 2),
          child: Align(
            alignment: Alignment.topRight,
            child: TapRegion(
              onTapOutside: (_) => _esconder(),
              child: FadeTransition(
                opacity: _curva,
                child: ScaleTransition(
                  scale: Tween(begin: 0.85, end: 1.0).animate(_curva),
                  alignment: Alignment.topRight,
                  child: _Balao(texto: _texto, cor: _cor),
                ),
              ),
            ),
          ),
        ),
        child: Semantics(
          button: true,
          label: _texto,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _mostrar,
            child: SizedBox(
              width: 32,
              height: 40,
              child: Center(
                child: Losango(cor: _cor, tamanho: 8, pulsar: widget.online),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Balão do status do PC, com a pontinha apontando pro losango.
class _Balao extends StatelessWidget {
  const _Balao({required this.texto, required this.cor});
  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      // pontinha: losango meio escondido atrás do balão, centrado no losango do topo
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Transform.translate(
          offset: const Offset(0, 5),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: Cor.painel2,
                border: Border.all(color: cor.withValues(alpha: 0.55)),
              ),
            ),
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Cor.painel2,
          borderRadius: Raio.r1,
          border: Border.all(color: cor.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(color: Cor.sombra, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: math.pi / 4,
              child: Container(width: 6, height: 6, color: cor),
            ),
            const SizedBox(width: 8),
            Text(
              texto,
              style: TextStyle(
                color: Cor.texto,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Rodape extends StatelessWidget {
  const _Rodape(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
    child: Text(
      texto,
      textAlign: TextAlign.center,
      style: TextStyle(color: Cor.apagado, fontSize: 12.5),
    ),
  );
}

// ---------------- telas ----------------

/// Sem conta: entrar (ou criar) com a mesma conta Ping do painel do PC.
class _Entrar extends StatelessWidget {
  const _Entrar({super.key, required this.con});
  final Conexao con;

  @override
  Widget build(BuildContext context) {
    final erro = con.erro;
    final info = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: _Joia()),
        const SizedBox(height: 16),
        Text(
          'PING NO CELULAR',
          textAlign: TextAlign.center,
          style: fonteTitulo(17),
        ),
        const SizedBox(height: 8),
        Text(
          'Entre com a mesma conta Ping do painel do PC. Não tem? Crie aqui e entre com ela no PC, em Conta.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Cor.apagado, fontSize: 15, height: 1.35),
        ),
        AnimatedSize(
          duration: _dur(context, 250),
          curve: curvaSaida,
          child: erro == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    erro,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Cor.vermelho, fontSize: 15),
                  ),
                ),
        ),
      ],
    );
    final form = _FormConta(con: con, criar: false, naJanela: false);
    // deitado falta altura: quem é à esquerda, o formulário à direita (como o _Mensagem)
    if (_deitado(context)) {
      return Cartao(
        child: Row(
          children: [
            Expanded(child: info),
            Container(
              width: 1,
              height: 160,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              color: Cor.linha,
            ),
            Expanded(child: form),
          ],
        ),
      );
    }
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          info,
          const SizedBox(height: 18),
          Container(height: 1, color: Cor.linha),
          const SizedBox(height: 18),
          form,
        ],
      ),
    );
  }
}

/// Losango dourado do topo da tela de entrar: entra girando e fica respirando devagar.
class _Joia extends StatefulWidget {
  const _Joia();

  @override
  State<_Joia> createState() => _JoiaState();
}

class _JoiaState extends State<_Joia> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final _respira = CurvedAnimation(parent: _c, curve: Curves.easeInOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _respira.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: _dur(context, 700),
    curve: curvaSaida,
    builder: (_, t, filho) => Opacity(
      opacity: t,
      child: Transform.rotate(angle: (1 - t) * -math.pi / 2, child: filho),
    ),
    child: RepaintBoundary(
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            FadeTransition(
              opacity: Tween(begin: 0.25, end: 0.7).animate(_respira),
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    border: Border.all(color: Cor.ouro, width: 1),
                  ),
                ),
              ),
            ),
            Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Cor.ouro.withValues(alpha: 0.2),
                  border: Border.all(color: Cor.ouro, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Sair da conta na tela de conta sem PC.
class _BotaoSairConta extends StatelessWidget {
  const _BotaoSairConta({required this.con});
  final Conexao con;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: con,
    builder: (context, _) => Botao(
      texto: 'Entrar com outra conta',
      carregando: con.contaOcupada,
      aoTocar: con.sairConta,
    ),
  );
}

class _Mensagem extends StatelessWidget {
  const _Mensagem({
    super.key,
    required this.icone,
    required this.titulo,
    required this.texto,
    this.extra,
  });
  final Widget icone;
  final String titulo;
  final String texto;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    // deitado falta altura: o que é (ícone, título, texto) à esquerda e o que fazer (extra) à direita
    if (_deitado(context)) {
      final info = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icone,
          const SizedBox(height: 14),
          Text(
            titulo.toUpperCase(),
            textAlign: TextAlign.center,
            style: fonteTitulo(18),
          ),
          const SizedBox(height: 8),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(color: Cor.apagado, fontSize: 15, height: 1.3),
          ),
        ],
      );
      return Cartao(
        child: extra == null
            ? info
            : Row(
                children: [
                  Expanded(child: info),
                  Container(
                    width: 1,
                    height: 120,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: Cor.linha,
                  ),
                  Expanded(child: extra!),
                ],
              ),
      );
    }
    return Cartao(
      child: Column(
        children: [
          const SizedBox(height: 8),
          icone,
          const SizedBox(height: 22),
          Text(
            titulo.toUpperCase(),
            textAlign: TextAlign.center,
            style: fonteTitulo(19),
          ),
          const SizedBox(height: 10),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(color: Cor.apagado, fontSize: 16, height: 1.35),
          ),
          if (extra != null) ...[const SizedBox(height: 24), extra!],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Estado extends StatelessWidget {
  const _Estado({super.key, required this.con});
  final Conexao con;

  @override
  Widget build(BuildContext context) {
    final e = con.estado;
    if (e.isEmpty) {
      return const _Mensagem(
        icone: _Pulso(),
        titulo: 'Esperando o PC',
        texto: 'O Ping manda o primeiro sinal em alguns segundos.',
      );
    }
    if (!con.pcOnline) {
      return const _Mensagem(
        icone: Icone(Icons.power_settings_new, cor: Cor.vermelho),
        titulo: 'PC sem sinal',
        texto: 'O PC está desligado, sem internet ou com o Ping fechado.',
      );
    }
    final fila = (e['fila_nome'] as String?) ?? '';
    if (con.abriu case final ab?) return _Abrindo(con: con, abriu: ab);
    if (e['fechando'] == true) {
      return const _Mensagem(
        icone: _Pulso(),
        titulo: 'Fechando o LoL',
        texto: 'O LoL e o Riot Client estão fechando no PC.',
      );
    }
    switch (con.fase) {
      case 'Fechado' when e['abrindo'] == true:
        return _Abrindo(con: con);
      case 'Fechado':
        return _Mensagem(
          icone: const Icone(Icons.videogame_asset_off_outlined),
          titulo: 'LoL fechado',
          texto: 'Abra o LoL no PC pra acompanhar por aqui.',
          extra: Botao(
            texto: 'Abrir o LoL',
            principal: true,
            carregando: con.esperando('abrir_lol'),
            aoTocar: () => con.enviar('abrir_lol'),
          ),
        );
      case 'Lobby' when e['sala'] is Map:
        return _LadoALado(
          _CartaoSala(con: con, sala: e['sala'] as Map),
          _ChatSala(con: con, sala: e['sala'] as Map),
        );
      case 'None':
        return _CartaoCriar(con: con);
      case 'Lobby':
        return _Mensagem(
          icone: const Icone(Icons.groups_2_outlined),
          titulo: con.fase == 'Lobby' ? 'Na sala' : 'Tudo parado',
          texto: 'Entre na fila no PC e acompanhe por aqui.',
        );
      case 'Matchmaking':
        if (e['sala'] is! Map) {
          return _Fila(con: con, fila: fila);
        }
        // em pé com o chat embaixo, a fila fica numa faixa baixa pra caber tudo sem rolar
        return _LadoALado(
          _Fila(con: con, fila: fila, compacta: true),
          _ChatSala(con: con, sala: e['sala'] as Map),
        );
      case 'ReadyCheck':
        return _Encontrada(con: con, fila: fila);
      case 'ChampSelect' when e['selecao'] is Map:
        return _Selecao(con: con, sel: e['selecao'] as Map);
      case 'ChampSelect':
        return const _Mensagem(
          icone: Icone(Icons.shield_outlined),
          titulo: 'Seleção de campeões',
          texto: 'Logo dá pra escolher o campeão por aqui.',
        );
      case 'GameStart':
      case 'InProgress':
      case 'Reconnect':
        return _EmPartida(con: con);
      case 'WaitingForStats':
      case 'PreEndOfGame':
      case 'EndOfGame':
        return const _Mensagem(
          icone: Icone(Icons.flag_outlined),
          titulo: 'Fim de partida',
          texto: 'A partida acabou.',
        );
      default:
        return _Mensagem(
          icone: const _Pulso(),
          titulo: 'Carregando',
          texto: con.fase,
        );
    }
  }
}

/// Um embaixo do outro em pé; deitado, lado a lado (a altura não dá pros dois empilhados).
class _LadoALado extends StatelessWidget {
  const _LadoALado(this.a, this.b);
  final Widget a;
  final Widget b;

  @override
  Widget build(BuildContext context) => _deitado(context)
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 14),
            Expanded(child: b),
          ],
        )
      : Column(children: [a, const SizedBox(height: 14), b]);
}

class _Fila extends StatelessWidget {
  const _Fila({required this.con, required this.fila, this.compacta = false});
  final Conexao con;
  final String fila;

  /// Faixa baixa (radar pequeno, título e tempo na mesma linha) pra sobrar altura pro chat.
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final inicio = con.estado['fila_inicio'];
    final estimado = con.estado['fila_estimado'];
    if (compacta && !_deitado(context)) {
      // fila e estimado em linhas separadas, com o tempo ao lado: na mesma linha cortava no celular estreito
      final sub = [
        if (fila.isNotEmpty) fila,
        if (estimado is int && estimado > 0) 'Estimado ${_mmss(estimado)}',
      ];
      return Cartao(
        padding: const EdgeInsets.fromLTRB(16, 14, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _Radar(tamanho: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROCURANDO PARTIDA',
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: fonteTitulo(14),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final t in sub)
                                  Text(
                                    t,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Cor.apagado,
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (inicio is int) ...[
                            const SizedBox(width: 10),
                            Relogio(
                              builder: (_) => Text(
                                _mmss(
                                  con.agora.millisecondsSinceEpoch ~/ 1000 -
                                      inicio ~/ 1000,
                                ),
                                style: fonteTitulo(28, cor: Cor.ouroClaro)
                                    .copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Botao(
              texto: 'Sair da fila',
              carregando: con.esperando('sair_fila'),
              aoTocar: () => con.enviar('sair_fila'),
            ),
          ],
        ),
      );
    }
    return _Mensagem(
      icone: const _Radar(),
      titulo: 'Procurando partida',
      texto: [
        if (fila.isNotEmpty) fila,
        if (estimado is int && estimado > 0) 'estimado ${_mmss(estimado)}',
      ].join('  ·  '),
      extra: Column(
        children: [
          if (inicio is int)
            Relogio(
              builder: (_) => Text(
                _mmss(
                  con.agora.millisecondsSinceEpoch ~/ 1000 - inicio ~/ 1000,
                ),
                style: fonteTitulo(
                  44,
                  cor: Cor.ouroClaro,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          const SizedBox(height: 24),
          Botao(
            texto: 'Sair da fila',
            carregando: con.esperando('sair_fila'),
            aoTocar: () => con.enviar('sair_fila'),
          ),
        ],
      ),
    );
  }
}

class _Encontrada extends StatelessWidget {
  const _Encontrada({required this.con, required this.fila});
  final Conexao con;
  final String fila;

  static const duracao = 10.0; // o ready-check do LoL dura uns 10s

  @override
  Widget build(BuildContext context) {
    final p = con.estado['partida'];
    final resposta = p is Map ? p['resposta'] : 'None';
    final inicio = p is Map ? p['inicio'] : null;
    if (resposta == 'Accepted') {
      return _Mensagem(
        icone: Icone(Icons.check, cor: Cor.teal),
        titulo: 'Partida aceita',
        texto: 'Esperando os outros jogadores.',
      );
    }
    if (resposta == 'Declined') {
      return const _Mensagem(
        icone: Icone(Icons.close, cor: Cor.vermelho),
        titulo: 'Partida recusada',
        texto: 'Você recusou esta partida.',
      );
    }
    return _Mensagem(
      icone: _AnelContagem(
        passou: () => inicio is int
            ? (con.agora.millisecondsSinceEpoch - inicio) / 1000
            : 0.0,
        duracao: duracao.toDouble(),
      ),
      titulo: 'Partida encontrada',
      texto: fila.isEmpty ? 'Aceitar?' : fila,
      extra: Column(
        children: [
          Botao(
            texto: 'Aceitar',
            principal: true,
            grande: true,
            carregando: con.esperando('aceitar'),
            som: 'aceitar',
            aoTocar: () => con.enviar('aceitar'),
          ),
          const SizedBox(height: 12),
          Botao(
            texto: 'Recusar',
            carregando: con.esperando('recusar'),
            aoTocar: () => con.enviar('recusar'),
          ),
        ],
      ),
    );
  }
}

String _mmss(int s) {
  s = math.max(0, s);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

// ---------------- peças ----------------

class Cartao extends StatelessWidget {
  const Cartao({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 24, 22, 22),
  });
  final Widget child;

  /// Deitado sobra pouca altura: os cartões de tela cheia usam um respiro menor.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Cor.painel,
      borderRadius: Raio.r2,
      border: Border.all(color: Cor.linha2),
      boxShadow: [
        BoxShadow(color: Cor.sombra, blurRadius: 40, offset: Offset(0, 14)),
      ],
    ),
    child: child,
  );
}

class Icone extends StatelessWidget {
  const Icone(this.icone, {super.key, this.cor});
  final IconData icone;

  /// Null = o ouro do tema em uso.
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final c = cor ?? Cor.ouro;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: 0.5)),
        color: c.withValues(alpha: 0.06),
      ),
      child: Icon(icone, color: c, size: 28),
    );
  }
}

/// Losango no lugar de bolinha (como no painel e no client).
class Losango extends StatefulWidget {
  const Losango({
    super.key,
    required this.cor,
    this.tamanho = 8,
    this.pulsar = false,
  });
  final Color cor;
  final double tamanho;
  final bool pulsar;

  @override
  State<Losango> createState() => _LosangoState();
}

class _LosangoState extends State<Losango> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final _brilho = Tween(begin: 0.45, end: 1.0).animate(_c);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sincronizar();
  }

  @override
  void didUpdateWidget(Losango old) {
    super.didUpdateWidget(old);
    _sincronizar();
  }

  void _sincronizar() {
    if (widget.pulsar && !MediaQuery.disableAnimationsOf(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.value = 1;
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  // pulsa sempre (topo, sua vez): camada própria, senão repinta a tela toda a cada quadro
  Widget build(BuildContext context) => RepaintBoundary(
    child: FadeTransition(
      opacity: _brilho,
      child: Transform.rotate(
        angle: math.pi / 4,
        child: AnimatedContainer(
          duration: _dur(context, 300),
          width: widget.tamanho,
          height: widget.tamanho,
          decoration: BoxDecoration(
            color: widget.cor,
            boxShadow: [
              BoxShadow(
                color: widget.cor.withValues(alpha: 0.6),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class Botao extends StatefulWidget {
  const Botao({
    super.key,
    required this.texto,
    required this.aoTocar,
    this.principal = false,
    this.grande = false,
    this.carregando = false,
    this.compacto = false,
    this.pequeno = false,
    this.som,
  });
  final String texto;
  final VoidCallback aoTocar;
  final bool principal;
  final bool grande;

  /// Esperando o PC: gira no lugar do texto e não aceita outro toque.
  final bool carregando;

  /// Do tamanho do texto e mais baixo (rodapé de tela deitada), em vez da largura toda.
  final bool compacto;

  /// Como o compacto, mais baixo ainda e com letra menor (canto de tela deitada sem espaço).
  final bool pequeno;

  /// Som do toque (nome em `web/sons/`). Padrão: o clique dourado no principal, o simples no resto.
  final String? som;

  @override
  State<Botao> createState() => _BotaoState();
}

class _BotaoState extends State<Botao> {
  bool _apertado = false;
  bool _ocupado = false;

  Future<void> _tocar() async {
    if (_ocupado || widget.carregando) return;
    setState(() => _ocupado = true);
    som.tocar(widget.som ?? (widget.principal ? 'ouro' : 'clique'));
    widget.aoTocar();
    await Future.delayed(
      const Duration(milliseconds: 900),
    ); // evita toque duplo
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.principal;
    final curto = widget.compacto || widget.pequeno;
    return Semantics(
      button: true,
      label: widget.texto,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _apertado = true),
        onTapCancel: () => setState(() => _apertado = false),
        onTapUp: (_) => setState(() => _apertado = false),
        onTap: _tocar,
        child: AnimatedScale(
          scale: _apertado ? 0.97 : 1,
          duration: _dur(context, 120),
          curve: curvaSaida,
          child: AnimatedOpacity(
            opacity: _ocupado && !widget.carregando ? 0.6 : 1,
            duration: _dur(context, 150),
            child: Container(
              width: curto ? null : double.infinity,
              height: widget.grande
                  ? 64
                  : (widget.pequeno ? 34 : (widget.compacto ? 42 : 50)),
              padding: curto
                  ? EdgeInsets.symmetric(horizontal: widget.pequeno ? 16 : 26)
                  : null,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: Raio.r1,
                border: Border.all(color: p ? Cor.ouro : Cor.linha2),
                gradient: p
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Cor.marcadoForte, Cor.marcadoFundo],
                      )
                    : null,
                color: p ? null : Cor.painel2,
                boxShadow: p
                    ? [
                        BoxShadow(
                          color: Cor.ouro.withValues(alpha: 0.25),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              child: ExcludeSemantics(
                child: AnimatedSwitcher(
                  duration: _dur(context, 220),
                  switchInCurve: curvaSaida,
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.85, end: 1.0).animate(a),
                      child: c,
                    ),
                  ),
                  child: widget.carregando
                      ? _Carregando(
                          key: const ValueKey('carregando'),
                          cor: p ? Cor.ouroClaro : Cor.texto,
                        )
                      : Text(
                          widget.texto.toUpperCase(),
                          key: const ValueKey('texto'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            letterSpacing: widget.pequeno ? 1.2 : 1.6,
                            fontSize: widget.grande
                                ? 18
                                : (widget.pequeno
                                      ? 11.5
                                      : (widget.compacto ? 13 : 14)),
                            color: p ? Cor.ouroClaro : Cor.texto,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Três losangos acendendo em sequência: esperando o PC responder.
class _Carregando extends StatefulWidget {
  const _Carregando({super.key, required this.cor});
  final Color cor;

  @override
  State<_Carregando> createState() => _CarregandoState();
}

class _CarregandoState extends State<_Carregando>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Builder(
                builder: (_) {
                  // cada losango acende um terço de volta depois do anterior
                  final t = (_c.value - i / 3) % 1.0;
                  final brilho = t < 0.5 ? 1 - t * 2 : 0.0;
                  // transparência na própria cor: sem camada de Opacity a cada quadro
                  return Transform.scale(
                    scale: 0.8 + 0.3 * brilho,
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        color: widget.cor.withValues(
                          alpha: widget.cor.a * (0.3 + 0.7 * brilho),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}

/// Avisa só quando muda o que a tela usa: folha aberta não redesenha a cada gravação do PC (relógio,
/// hover, chat). Compara cada valor por identidade (a [Conexao] mantém a instância do que não mudou).
class Filtro extends ChangeNotifier {
  Filtro(this.con, this.usa) : _visto = usa() {
    con.addListener(_mudou);
  }
  final Conexao con;
  final List<Object?> Function() usa;
  List<Object?> _visto;

  void _mudou() {
    final novo = usa();
    var igual = novo.length == _visto.length;
    for (var i = 0; igual && i < novo.length; i++) {
      final a = novo[i], b = _visto[i];
      igual = identical(a, b) || (a is! Map && a is! List && a == b);
    }
    if (igual) return;
    _visto = novo;
    notifyListeners();
  }

  @override
  void dispose() {
    con.removeListener(_mudou);
    super.dispose();
  }
}

/// Redesenha de tempos em tempos (relógio da fila, contagem da partida).
class Relogio extends StatefulWidget {
  const Relogio({
    super.key,
    required this.builder,
    this.intervalo = const Duration(seconds: 1),
  });
  final WidgetBuilder builder;
  final Duration intervalo;

  @override
  State<Relogio> createState() => _RelogioState();
}

class _RelogioState extends State<Relogio> {
  late Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(widget.intervalo, (_) => setState(() {}));
  }

  @override
  void didUpdateWidget(Relogio antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.intervalo != widget.intervalo) {
      _t.cancel();
      _t = Timer.periodic(widget.intervalo, (_) => setState(() {}));
    }
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  // redesenha sozinho de tempos em tempos: camada própria, o resto da tela não repinta junto
  Widget build(BuildContext context) =>
      RepaintBoundary(child: widget.builder(context));
}

/// Contagem da partida encontrada: o anel esvazia a cada quadro, liso (antes andava em degraus de
/// 100ms), numa camada própria; o número só redesenha quando muda o segundo.
class _AnelContagem extends StatefulWidget {
  const _AnelContagem({required this.passou, required this.duracao});
  final double Function() passou;
  final double duracao;

  @override
  State<_AnelContagem> createState() => _AnelContagemState();
}

class _AnelContagemState extends State<_AnelContagem>
    with SingleTickerProviderStateMixin {
  late final _fracao = ValueNotifier<double>(_calc().$1);
  late final _seg = ValueNotifier<int>(_calc().$2);
  late final _ticker = createTicker((_) {
    final (f, sg) = _calc();
    _fracao.value = f;
    _seg.value = sg;
  });

  (double, int) _calc() {
    final p = widget.passou();
    return (
      (1 - p / widget.duracao).clamp(0.0, 1.0),
      math.max(0, (widget.duracao - p).ceil()),
    );
  }

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fracao.dispose();
    _seg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: _AnelPintor(0, vivo: _fracao),
        child: Center(
          child: ValueListenableBuilder<int>(
            valueListenable: _seg,
            builder: (_, sg, _) =>
                Text('$sg', style: fonteTitulo(40, cor: Cor.ouroClaro)),
          ),
        ),
      ),
    ),
  );
}

class Anel extends StatelessWidget {
  const Anel({super.key, required this.fracao, required this.texto});
  final double fracao;
  final String texto;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    height: 120,
    child: CustomPaint(
      painter: _AnelPintor(fracao),
      child: Center(
        child: Text(texto, style: fonteTitulo(40, cor: Cor.ouroClaro)),
      ),
    ),
  );
}

class _AnelPintor extends CustomPainter {
  _AnelPintor(double fracao, {this.vivo})
    : _fixa = fracao,
      super(repaint: vivo);
  final double _fixa;
  final ValueNotifier<double>? vivo; // anda sozinho, sem rebuild
  double get fracao => vivo?.value ?? _fixa;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Cor.linha2,
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * fracao,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [Cor.ouroEscuro, Cor.ouroClaro],
          transform: GradientRotation(
            -math.pi / 2,
          ), // começa no topo, junto com o arco
        ).createShader(r)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2),
    );
  }

  @override
  bool shouldRepaint(_AnelPintor old) =>
      old.vivo != vivo || old.fracao != fracao;
}

/// Ondas saindo do centro enquanto procura partida.
class _Radar extends StatefulWidget {
  const _Radar({this.tamanho = 96});
  final double tamanho;

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      width: widget.tamanho,
      height: widget.tamanho,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Builder(
                builder: (_) {
                  final t = (_c.value + i / 3) % 1;
                  // transparência na cor da borda: sem camada de Opacity a cada quadro
                  return Transform.scale(
                    scale: 0.35 + t * 0.65,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Cor.ouro.withValues(alpha: (1 - t) * 0.7),
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            Losango(cor: Cor.ouro, tamanho: 14),
          ],
        ),
      ),
    ),
  );
}

class _Pulso extends StatelessWidget {
  const _Pulso();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 64,
    height: 64,
    child: Center(child: Losango(cor: Cor.ouro, tamanho: 14, pulsar: true)),
  );
}

/// Pergunta antes de algo que não dá pra desfazer. Devolve true no sim.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String sim,
  required String nao,
}) async {
  final r = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: Cor.veu,
    transitionDuration: _dur(context, 220),
    transitionBuilder: (_, a, _, c) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(
          begin: 0.94,
          end: 1.0,
        ).animate(CurvedAnimation(parent: a, curve: curvaSaida)),
        child: c,
      ),
    ),
    pageBuilder: (ctx, _, _) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Material(
            type: MaterialType.transparency,
            child: Cartao(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(titulo.toUpperCase(), style: fonteTitulo(16)),
                  const SizedBox(height: 8),
                  Text(
                    texto,
                    style: TextStyle(color: Cor.apagado, fontSize: 14.5),
                  ),
                  const SizedBox(height: 18),
                  Botao(
                    texto: sim,
                    principal: true,
                    aoTocar: () => Navigator.of(ctx).pop(true),
                  ),
                  const SizedBox(height: 8),
                  Botao(
                    texto: nao,
                    aoTocar: () => Navigator.of(ctx).pop(false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return r == true;
}

/// Fecha o LoL e o Riot Client no PC. Some no meio de partida (fechar ali é dodge ou saída da partida).
class _BotaoFechar extends StatelessWidget {
  const _BotaoFechar({required this.con});
  final Conexao con;

  static const _semFechar = {
    'ReadyCheck',
    'ChampSelect',
    'GameStart',
    'InProgress',
    'Reconnect',
  };

  static bool pode(Conexao con) {
    final e = con.estado;
    if (e['fechando'] == true) return false;
    if (con.fase == 'Fechado') return e['riot'] == true && e['abrindo'] != true;
    return !_semFechar.contains(con.fase);
  }

  Future<void> _tocar(BuildContext context) async {
    final soRiot = con.fase == 'Fechado';
    final sim = await confirmar(
      context,
      titulo: soRiot ? 'Fechar o Riot Client?' : 'Fechar o LoL?',
      texto: soRiot
          ? 'O Riot Client fecha no PC.'
          : con.fase == 'Matchmaking'
          ? 'Você sai da fila e o LoL fecha no PC, junto com o Riot Client.'
          : 'O LoL fecha no PC, junto com o Riot Client.',
      sim: 'Fechar',
      nao: 'Cancelar',
    );
    if (sim) con.enviar('fechar_lol');
  }

  @override
  Widget build(BuildContext context) {
    final fechando = con.esperando('fechar_lol');
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: con.fase == 'Fechado'
            ? 'Fechar o Riot Client'
            : 'Fechar o LoL',
        onPressed: fechando ? null : () => _tocar(context),
        icon: AnimatedSwitcher(
          duration: _dur(context, 200),
          child: fechando
              ? SizedBox(
                  key: ValueKey('fechando'),
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Cor.ouro,
                  ),
                )
              : Icon(
                  Icons.power_settings_new_rounded,
                  key: ValueKey('fechar'),
                  size: 20,
                  color: Cor.ouro,
                ),
        ),
      ),
    );
  }
}

/// Liga e desliga os sons (fica salvo no aparelho).
class _BotaoMudo extends StatelessWidget {
  const _BotaoMudo();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: som.mudo,
    builder: (context, mudo, _) => SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: mudo ? 'Ligar sons' : 'Desligar sons',
        onPressed: som.alternarMudo,
        icon: AnimatedSwitcher(
          duration: _dur(context, 200),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 0.7, end: 1.0).animate(a),
              child: c,
            ),
          ),
          child: Icon(
            mudo ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            key: ValueKey(mudo),
            size: 20,
            color: mudo ? Cor.apagado : Cor.ouro,
          ),
        ),
      ),
    ),
  );
}

/// Sons do que acontece no client (não de toque): fila, seleção, resposta da partida, chat novo, quem entra
/// e sai da sala, campeão travado. Compara com o retrato anterior; o primeiro retrato só é guardado (abrir o
/// app no meio da sala não toca nada).
class _SonsDoEstado {
  String? _fase;
  String? _resposta;
  Set<String>? _msgs;
  Set<String>? _dms;
  int? _membros;
  bool? _travei;
  ({bool pendente, String meu})? _troca;
  String? _fim;

  void ouvir(Conexao con) {
    final e = con.estado;
    if (e.isEmpty) return;
    final fase = con.fase;
    final primeira = _fase == null;
    if (!primeira && fase != _fase) {
      if (fase == 'Matchmaking') som.tocar('fila');
      if (fase == 'ChampSelect') som.tocar('selecao');
    }
    _fase = fase;

    // fim de partida: o som do client de vitória, derrota ou remake
    final fim = e['fim'];
    final resultado = fim is Map ? '${fim['resultado']}' : null;
    if (!primeira && resultado != null && resultado != _fim) {
      som.tocar(_tomDe(resultado).som);
    }
    _fim = resultado;

    final p = e['partida'];
    final resp = p is Map ? '${p['resposta']}' : null;
    if (!primeira && resp != _resposta) {
      if (resp == 'Accepted') som.tocar('aceitou');
      if (resp == 'Declined') som.tocar('recusou');
    }
    _resposta = resp;

    final sala = e['sala'];
    final sel = e['selecao'];
    final chat = fase == 'ChampSelect' && sel is Map
        ? sel['chat']
        : (sala is Map ? sala['chat'] : null);
    final msgs = <String>{
      for (final m in (chat as List?) ?? const [])
        if (m is Map && m['eu'] != true && m['tipo'] != 'aviso') '${m['id']}',
    };
    // mensagem de amigo também toca o som do chat
    final dms = <String>{
      for (final c in _conversas(con))
        for (final m in c.msgs)
          if (m['eu'] != true) '${c.puuid}/${m['id']}',
    };
    if ((_msgs != null && msgs.difference(_msgs!).isNotEmpty) ||
        (_dms != null && dms.difference(_dms!).isNotEmpty)) {
      som.tocar('chat');
    }
    _msgs = msgs;
    _dms = dms;

    final n = sala is Map
        ? ((sala['membros'] as List?) ?? const []).length
        : null;
    if (_membros != null && n != null && fase == 'Lobby') {
      if (n > _membros!) som.tocar('entrou');
      if (n < _membros!) som.tocar('saiu');
    }
    _membros = n;

    final eu = sel is Map
        ? ((sel['meu'] as List?) ?? const [])
              .whereType<Map>()
              .where((m) => m['eu'] == true)
              .firstOrNull
        : null;
    final travei = eu?['travado'] == true;
    if (_travei == false && travei) som.tocar('travar');
    _travei = sel is Map ? travei : null;

    // troca com aliado que acabou: aceita (seu campeão, posição ou ordem mudou) ou recusada/cancelada
    final troca = sel is Map
        ? (
            pendente: _trocaPendente(sel) != null,
            meu:
                '${eu?['campeao'] ?? 0}|${eu?['pos'] ?? ''}|${eu?['ordem'] ?? 0}',
          )
        : null;
    final antes = _troca;
    if (antes != null && antes.pendente && troca != null && !troca.pendente) {
      som.tocar(troca.meu != antes.meu ? 'troca_aceita' : 'troca_recusada');
    }
    _troca = troca;
  }
}
