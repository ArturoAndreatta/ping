part of 'main.dart';

String _iconeCampeao(int id) =>
    'https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-icons/$id.png';

/// Nome do campeão pelo id. O Firebase devolve como lista um mapa de chaves "1", "2", "3"... quando a
/// maioria é número em sequência (com a lista inteira de campeões acontece): aceita os dois formatos.
String _nomeCampeao(Object? nomes, int id) {
  if (nomes is Map) return '${nomes['$id'] ?? ''}';
  if (nomes is List && id >= 0 && id < nomes.length) {
    return '${nomes[id] ?? ''}';
  }
  return '';
}

/// Ícone da posição (o dourado do client). Chave = `assignedPosition` da seleção.
NetworkImage _fontePosicao(String pos) => NetworkImage(
  'https://raw.communitydragon.org/latest/plugins/rcp-fe-lol-clash/global/default/assets/images/position-selector/positions/icon-position-$pos.png',
  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
);

/// Filas de ARAM (normal, Ponte do Açougueiro, Clash e Desordem): campeão sorteado, sem draft.
const _filasAram = {100, 450, 720, 2400};

const _posSelecao = {
  'top': 'Topo',
  'jungle': 'Selva',
  'middle': 'Meio',
  'bottom': 'Atirador',
  'utility': 'Suporte',
};

/// Celular deitado (ou tablet): sobra largura e falta altura, então a tela vira duas colunas.
bool _deitado(BuildContext c) {
  final s = MediaQuery.sizeOf(c);
  return s.width > s.height && s.width >= 560;
}

/// Seleção de campeões, uma coisa por vez: na sua vez a tela é a grade pra escolher/banir (os times viram
/// uma faixa de ícones em cima); fora dela, o quadro dos times como no client. O chat fica num botão.
/// Deitado: times à esquerda e, à direita, a grade na sua vez ou o chat fora dela.
class _Selecao extends StatefulWidget {
  const _Selecao({required this.con, required this.sel});
  final Conexao con;
  final Map sel;

  @override
  State<_Selecao> createState() => _SelecaoState();
}

class _SelecaoState extends State<_Selecao> {
  final Set<String> _lidas = {};
  bool _chatAberto = false;
  bool _posicoesCarregadas = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // os 5 ícones de posição antes de aparecer: senão o slot pisca quando chega a imagem
    if (_posicoesCarregadas) return;
    _posicoesCarregadas = true;
    for (final p in _posSelecao.keys) {
      precacheImage(_fontePosicao(p), context, onError: (_, _) {});
    }
  }

  List<Map> _msgs(Map sel) =>
      ((sel['chat'] as List?) ?? const []).cast<Map>().toList();

  bool _conta(Map m) => m['eu'] != true && m['tipo'] != 'aviso';

  void _marcarLidas(Map sel) =>
      _lidas.addAll([for (final m in _msgs(sel)) '${m['id']}']);

  Future<void> _abrirChat() async {
    som.tocar('abrir');
    setState(() => _chatAberto = true);
    var fechou = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xB3000000),
      constraints: const BoxConstraints(maxWidth: 560),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : AnimationStyle(
              duration: const Duration(milliseconds: 340),
              reverseDuration: const Duration(milliseconds: 240),
              curve: _curvaFolha,
              reverseCurve: _curvaFolha.flipped,
            ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          12 +
              MediaQuery.viewInsetsOf(ctx).bottom +
              widget.con.nav.areaSegura().base,
        ),
        child: ListenableBuilder(
          listenable: widget.con,
          builder: (ctx, _) {
            final s = widget.con.estado['selecao'];
            if (s is! Map || widget.con.fase != 'ChampSelect') {
              // a seleção acabou com o chat aberto: fecha sozinho
              if (!fechou) {
                fechou = true;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => Navigator.of(ctx).maybePop(),
                );
              }
              return const SizedBox.shrink();
            }
            _marcarLidas(s);
            return _ChatSala(
              con: widget.con,
              sala: s,
              titulo: 'CHAT DA SELEÇÃO',
            );
          },
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _chatAberto = false;
        _marcarLidas(widget.sel);
      });
    }
  }

  /// SAIR do client (personalizada): pergunta antes, sair sem querer tira da partida.
  Future<void> _sair() async {
    final sim = await confirmar(
      context,
      titulo: 'Sair da seleção?',
      texto: 'Você sai da partida, como no SAIR do LoL.',
      sim: 'Sair',
      nao: 'Ficar',
    );
    if (sim) widget.con.enviar('sair_selecao');
  }

  /// Seleção da Arena: 18 jogadores num quadro só. Em pé, a faixa de miniaturas em cima na sua vez e nas
  /// skins; deitado, o quadro à esquerda e a grade, as skins ou o chat à direita.
  Widget _montarArena({
    required Map sel,
    required bool deitado,
    required Widget cabecalho,
    required Widget Function(Widget) trocar,
    required bool escolhendo,
    required bool comSkins,
    required bool chatNaTela,
    required int naoLidas,
    required Widget grade,
    required bool podeSair,
  }) {
    // feitiço da Arena: o par é fixo (Fuga + Flash), o botão só inverte D e F
    final feiticos = _temFeiticos(widget.con, sel)
        ? _BotaoFeiticos(con: widget.con, sel: sel)
        : null;
    if (deitado) {
      final quadro = _QuadroArena(sel: sel, colunas: 2);
      final Widget meio = escolhendo
          ? Row(
              key: const ValueKey('grade'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 370, child: quadro),
                const SizedBox(width: 14),
                Expanded(child: grade),
              ],
            )
          : comSkins
          ? Row(
              key: const ValueKey('skins'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 370, child: quadro),
                const SizedBox(width: 14),
                Expanded(
                  child: _Skins(con: widget.con, sel: sel),
                ),
              ],
            )
          : Row(
              key: const ValueKey('quadro'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 370, child: quadro),
                const SizedBox(width: 14),
                Expanded(
                  child: _ChatSala(
                    con: widget.con,
                    sala: sel,
                    titulo: 'CHAT DA SELEÇÃO',
                    encher: true,
                  ),
                ),
              ],
            );
      return Column(
        children: [
          _CabecalhoSelecao(
            con: widget.con,
            sel: sel,
            naoLidas: naoLidas,
            aoChat: null,
            centro: true,
          ),
          const SizedBox(height: 8),
          Expanded(child: trocar(meio)),
          if (podeSair || feiticos != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 370,
                child: Row(
                  children: [
                    ?feiticos,
                    if (feiticos != null && podeSair) const SizedBox(width: 8),
                    if (podeSair)
                      Expanded(
                        child: _BotaoSair(
                          con: widget.con,
                          aoTocar: _sair,
                          largo: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    }
    final botoes = Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          ?feiticos,
          const Spacer(),
          if (!chatNaTela) _BotaoChat(naoLidas: naoLidas, aoTocar: _abrirChat),
        ],
      ),
    );
    return Column(
      children: [
        cabecalho,
        const SizedBox(height: 16),
        Expanded(
          child: trocar(
            escolhendo
                ? Column(
                    key: const ValueKey('grade'),
                    children: [
                      _FaixaArena(sel: sel),
                      botoes,
                      const SizedBox(height: 10),
                      Expanded(child: grade),
                    ],
                  )
                : comSkins
                ? Column(
                    key: const ValueKey('skins'),
                    children: [
                      _FaixaArena(sel: sel),
                      botoes,
                      const SizedBox(height: 10),
                      Expanded(
                        child: _Skins(con: widget.con, sel: sel),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('quadro'),
                    children: [
                      Expanded(child: _QuadroArena(sel: sel, colunas: 2)),
                      botoes,
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.sel;
    final deitado = _deitado(context);
    // sua vez, ou ainda vai escolher: a grade fica pra você já marcar quem pretende jogar (como no client)
    // Arena: sem intenção no planejamento, a grade só abre na sua vez de banir ou escolher
    final arena = _ehArena(sel);
    final escolhendo =
        '${sel['minha_vez'] ?? ''}'.isNotEmpty ||
        (!arena &&
            sel['pick_pendente'] == true &&
            (sel['fase'] == 'PLANNING' || sel['fase'] == 'BAN_PICK'));
    // campeão travado: o meio vira o carrossel de skins
    final comSkins = !escolhendo && _temSkins(widget.con, sel);
    // deitado e fora da sua vez, o chat já está na tela: conta como lido
    final cartas = _temCartas(sel);
    final chatNaTela =
        deitado && !escolhendo && !cartas && !_temSkins(widget.con, sel);
    if (chatNaTela || _chatAberto) _marcarLidas(sel);
    final naoLidas = _msgs(
      sel,
    ).where((m) => _conta(m) && !_lidas.contains('${m['id']}')).length;

    final cabecalho = _CabecalhoSelecao(
      con: widget.con,
      sel: sel,
      naoLidas: naoLidas,
      aoChat: null,
      aoSair: sel['pode_sair'] == true ? _sair : null,
      preparo: false,
    );
    // em pé: feitiços e runas à esquerda, chat à direita, logo abaixo dos campeões
    final feiticosEmPe = _temFeiticos(widget.con, sel);
    final runasEmPe = _temRunas(widget.con);
    final botoesEmPe = feiticosEmPe || runasEmPe || !chatNaTela
        ? Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                if (feiticosEmPe) _BotaoFeiticos(con: widget.con, sel: sel),
                if (feiticosEmPe && runasEmPe) const SizedBox(width: 8),
                if (runasEmPe) _BotaoRunas(con: widget.con),
                const Spacer(),
                if (!chatNaTela)
                  _BotaoChat(naoLidas: naoLidas, aoTocar: _abrirChat),
              ],
            ),
          )
        : const SizedBox.shrink();
    final grade = _Escolha(
      key: ValueKey('escolha-${sel['minha_vez']}'),
      con: widget.con,
      sel: sel,
    );
    final quadro = _Quadro(con: widget.con, sel: sel, compacto: false);

    Widget trocar(Widget filho) => AnimatedSwitcher(
      duration: _dur(context, 320),
      switchInCurve: curvaSaida,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(a),
          child: c,
        ),
      ),
      layoutBuilder: (atual, antigos) =>
          Stack(alignment: Alignment.topCenter, children: [...antigos, ?atual]),
      child: filho,
    );

    final podeSair = sel['pode_sair'] == true;
    if (arena) {
      return _montarArena(
        sel: sel,
        deitado: deitado,
        cabecalho: cabecalho,
        trocar: trocar,
        escolhendo: escolhendo,
        comSkins: comSkins,
        chatNaTela: chatNaTela,
        naoLidas: naoLidas,
        grade: grade,
        podeSair: podeSair,
      );
    }
    // banco da ARAM numa linha (em cima dos times em pé, ou no meio da tela deitada): o quadro tem o dele
    final temBanco = ((sel['banco'] as List?) ?? const []).isNotEmpty;
    final faixaBanco = AnimatedSize(
      duration: _dur(context, 280),
      curve: curvaSaida,
      alignment: Alignment.topCenter,
      child: temBanco
          ? Padding(
              padding: deitado
                  ? const EdgeInsets.only(top: 10)
                  : const EdgeInsets.only(bottom: 12),
              child: _Banco(
                con: widget.con,
                sel: sel,
                tamanho: 36,
                faixa: true,
              ),
            )
          : const SizedBox(width: double.infinity),
    );

    if (deitado) {
      // como o client: seu time à esquerda, inimigos à direita, no meio o tempo e a grade
      // laterais estreitas: a grade no meio é o que mais precisa de espaço
      final lado = (MediaQuery.sizeOf(context).width * 0.19).clamp(
        140.0,
        210.0,
      );
      final runas = _temRunas(widget.con);
      final feiticos = _temFeiticos(widget.con, sel);
      final botoesLado = [
        if (!chatNaTela) _BotaoChat(naoLidas: naoLidas, aoTocar: _abrirChat),
        if (feiticos) _BotaoFeiticos(con: widget.con, sel: sel),
      ];
      // chat (46) e os dois feitiços (46 + 6 + 46) com o espaço; runas ao lado só se sobrar 120
      final linhaBotoes =
          (chatNaTela ? 0 : 46) +
          (feiticos ? 98 : 0) +
          (!chatNaTela && feiticos ? 8 : 0);
      final runasAoLado = runas && lado >= linhaBotoes + 120;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: lado,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LadoTime(con: widget.con, sel: sel, aliado: true),
                ),
                if (botoesLado.isNotEmpty || runas) ...[
                  const SizedBox(height: 8),
                  if (runasAoLado)
                    Row(
                      children: [
                        for (final b in botoesLado) ...[
                          b,
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: _BotaoRunas(con: widget.con, largo: true),
                        ),
                      ],
                    )
                  else ...[
                    // lateral estreita: o que não cabe desce pra linha de baixo
                    if (botoesLado.isNotEmpty)
                      Wrap(spacing: 8, runSpacing: 8, children: botoesLado),
                    if (runas) ...[
                      if (botoesLado.isNotEmpty) const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: _BotaoRunas(con: widget.con, largo: true),
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                _CabecalhoSelecao(
                  con: widget.con,
                  sel: sel,
                  naoLidas: naoLidas,
                  aoChat: null,
                  centro: true,
                ),
                _AvisoTroca(con: widget.con, sel: sel, espaco: 8),
                faixaBanco,
                const SizedBox(height: 8),
                Expanded(
                  child: trocar(
                    cartas
                        ? _Cartas(
                            key: const ValueKey('cartas'),
                            con: widget.con,
                            sel: sel,
                          )
                        : escolhendo
                        ? KeyedSubtree(
                            key: const ValueKey('grade'),
                            child: grade,
                          )
                        : comSkins
                        ? _Skins(
                            key: const ValueKey('skins'),
                            con: widget.con,
                            sel: sel,
                          )
                        : _ChatSala(
                            key: const ValueKey('chat'),
                            con: widget.con,
                            sala: sel,
                            titulo: 'CHAT DA SELEÇÃO',
                            encher: true,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: lado,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _LadoTime(con: widget.con, sel: sel, aliado: false),
                ),
                if (podeSair) ...[
                  const SizedBox(height: 8),
                  _BotaoSair(con: widget.con, aoTocar: _sair, largo: true),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        cabecalho,
        _AvisoTroca(con: widget.con, sel: sel),
        const SizedBox(height: 16),
        Expanded(
          child: trocar(
            cartas
                ? Column(
                    key: const ValueKey('cartas'),
                    children: [
                      Expanded(
                        child: _Cartas(con: widget.con, sel: sel),
                      ),
                      botoesEmPe,
                    ],
                  )
                : escolhendo
                ? Column(
                    key: const ValueKey('grade'),
                    children: [
                      _TimesEmPe(con: widget.con, sel: sel),
                      botoesEmPe,
                      const SizedBox(height: 10),
                      Expanded(child: grade),
                    ],
                  )
                : comSkins
                ? Column(
                    key: const ValueKey('skins'),
                    children: [
                      faixaBanco,
                      _TimesEmPe(con: widget.con, sel: sel),
                      botoesEmPe,
                      const SizedBox(height: 10),
                      Expanded(
                        child: _Skins(con: widget.con, sel: sel),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    key: const ValueKey('quadro'),
                    child: Column(children: [quadro, botoesEmPe]),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Tem carrossel pra mostrar: o PC mandou as skins do campeão que você travou.
bool _temSkins(Conexao con, Map sel) {
  final sk = con.estado['skins'];
  final cid = (sel['skins_de'] as num?)?.toInt() ?? 0;
  return cid > 0 &&
      sk is Map &&
      (sk['campeao'] as num?)?.toInt() == cid &&
      ((sk['lista'] as List?) ?? const []).isNotEmpty;
}

/// Arte do client (`/lol-game-data/assets/ASSETS/...`) no CommunityDragon (mesmo caminho, em minúsculas).
/// Sem caminho, o ícone do campeão.
String _arte(Object? caminho, int campeao) {
  final c = '${caminho ?? ''}';
  if (c.isEmpty) return _iconeCampeao(campeao);
  // já pronta (vitrine): só do CommunityDragon, endereço de outro site viraria rastreador
  if (c.startsWith('https://raw.communitydragon.org/') ||
      c.startsWith('https://cdn.communitydragon.org/')) {
    return c;
  }
  if (c.startsWith('http')) return _iconeCampeao(campeao);
  return 'https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/'
      '${c.replaceFirst('/lol-game-data/assets/', '').toLowerCase()}';
}

/// Carrossel de skins depois de travar, como o "Escolha sua preparação!" do client: a arte grande da skin,
/// os chromas embaixo e a fileira de miniaturas. As que você não tem ficam com cadeado (só dá pra ver).
class _Skins extends StatefulWidget {
  const _Skins({super.key, required this.con, required this.sel});
  final Conexao con;
  final Map sel;

  @override
  State<_Skins> createState() => _SkinsState();
}

class _SkinsState extends State<_Skins> {
  int?
  _vendo; // skin aberta na arte grande (pode ser uma que você não tem, só pra ver)
  int? _escolhida; // tocada aqui e ainda não confirmada pelo PC
  final _rolagem = ScrollController();

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  void _escolher(int id, {int? pai}) {
    som.tocar(pai == null ? 'skin' : 'chroma');
    setState(() => _escolhida = id);
    // chroma: primeiro a skin dona dele, depois a cor (o client faz assim)
    final atual = (widget.sel['skin'] as num?)?.toInt() ?? 0;
    if (pai != null && pai != atual) {
      widget.con.enviar('skin', {'skin': pai});
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted && _escolhida == id) {
          widget.con.enviar('skin', {'skin': id});
        }
      });
    } else {
      widget.con.enviar('skin', {'skin': id});
    }
  }

  @override
  Widget build(BuildContext context) {
    // saindo pelo AnimatedSwitcher (ao girar a tela) depois que as skins sumiram: não quebra
    final sk = widget.con.estado['skins'];
    if (sk is! Map || sk['campeao'] is! num) return const SizedBox.shrink();
    final cid = (sk['campeao'] as num).toInt();
    final lista = ((sk['lista'] as List?) ?? const []).cast<Map>();
    if (lista.isEmpty) return const SizedBox.shrink();
    final doPc = (widget.sel['skin'] as num?)?.toInt() ?? 0;
    if (_escolhida == doPc) _escolhida = null;
    final atual = _escolhida ?? doPc;
    int idDe(Map m) => (m['id'] as num).toInt();
    List<Map> chromasDe(Map m) =>
        ((m['chromas'] as List?) ?? const []).cast<Map>();
    // skin dona do que está escolhido (o escolhido pode ser um chroma)
    final dona = lista.firstWhere(
      (x) => idDe(x) == atual || chromasDe(x).any((c) => idDe(c) == atual),
      orElse: () => lista.first,
    );
    final vendo = lista.firstWhere(
      (x) => idDe(x) == (_vendo ?? idDe(dona)),
      orElse: () => dona,
    );
    final vendoId = idDe(vendo);
    final temVendo = vendo['tem'] == true;
    final chromas = chromasDe(vendo);
    final deitado = _deitado(context);
    final mini = deitado ? 54.0 : 62.0;

    return Column(
      children: [
        // arte grande
        Expanded(
          child: ClipRRect(
            borderRadius: Raio.r2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Cor.ouroEscuro),
                borderRadius: Raio.r2,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: _dur(context, 280),
                    // a imagem ocupa o quadro todo: em pé corta as laterais, deitado corta em cima e embaixo
                    layoutBuilder: (atual, antigos) => Stack(
                      fit: StackFit.expand,
                      children: [...antigos, ?atual],
                    ),
                    child: Image.network(
                      _arte(vendo['arte'], cid),
                      key: ValueKey(vendoId),
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.4),
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                      errorBuilder: (_, _, _) => ColoredBox(color: Cor.painel2),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.55, 1],
                        colors: [Color(0x00010A13), Color(0xE6010A13)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!temVendo) ...[
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: Cor.apagado,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: _dur(context, 220),
                            child: Text(
                              '${vendo['nome']}',
                              key: ValueKey(vendoId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                                color: temVendo ? Cor.ouroClaro : Cor.apagado,
                                shadows: const [
                                  Shadow(color: Colors.black, blurRadius: 6),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // chromas da skin aberta
        AnimatedSize(
          duration: _dur(context, 240),
          curve: curvaSaida,
          child: chromas.isEmpty || !temVendo
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _Chroma(
                            cor: null,
                            escolhido: atual == vendoId,
                            tem: true,
                            aoTocar: () => _escolher(vendoId),
                          ),
                          for (final c in chromas)
                            _Chroma(
                              cor: _cor('${c['cor'] ?? ''}'),
                              escolhido: atual == idDe(c),
                              tem: c['tem'] == true,
                              aoTocar: () => _escolher(idDe(c), pai: vendoId),
                            ),
                        ],
                      ),
                      if (!chromas.any((c) => c['tem'] == true))
                        Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Você não tem chroma desta skin',
                            style: TextStyle(fontSize: 12, color: Cor.apagado),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 10),
        // miniaturas
        SizedBox(
          height: mini + 4,
          child: ListView.separated(
            controller: _rolagem,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            itemCount: lista.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final x = lista[i];
              final id = idDe(x);
              final tem = x['tem'] == true;
              final escolhida = identical(x, dona);
              final aberta = id == vendoId;
              return Semantics(
                button: true,
                selected: escolhida,
                label: '${x['nome']}${tem ? '' : ', você não tem'}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    if (tem && !escolhida) _escolher(id);
                    // arte grande carregada antes de trocar: o crossfade não passa por um quadro vazio
                    // (espera no máximo meio segundo, depois troca assim mesmo)
                    try {
                      await precacheImage(
                        NetworkImage(
                          _arte(x['arte'], cid),
                          webHtmlElementStrategy:
                              WebHtmlElementStrategy.fallback,
                        ),
                        context,
                      ).timeout(const Duration(milliseconds: 500));
                    } catch (_) {}
                    if (mounted) setState(() => _vendo = id);
                  },
                  child: AnimatedContainer(
                    duration: _dur(context, 200),
                    curve: curvaSaida,
                    width: mini,
                    height: mini,
                    decoration: BoxDecoration(
                      borderRadius: Raio.r1,
                      border: Border.all(
                        color: escolhida
                            ? Cor.ouro
                            : (aberta ? Cor.ouroEscuro : Cor.linha2),
                        width: escolhida ? 2 : 1,
                      ),
                      boxShadow: escolhida
                          ? [
                              BoxShadow(
                                color: Cor.ouro.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ]
                          : const [],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // apagada pelo próprio Image: sem camada de Opacity por miniatura
                        Image.network(
                          _arte(x['mini'], cid),
                          fit: BoxFit.cover,
                          opacity: tem
                              ? null
                              : const AlwaysStoppedAnimation(.4),
                          webHtmlElementStrategy:
                              WebHtmlElementStrategy.fallback,
                          errorBuilder: (_, _, _) =>
                              ColoredBox(color: Cor.painel2),
                        ),
                        if (!tem)
                          Center(
                            child: Icon(
                              Icons.lock_outline,
                              size: 18,
                              color: Cor.ouroClaro,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

Color? _cor(String hex) {
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? null : Color(v);
}

/// Bolinha de chroma (losango, como o resto do app). Sem cor = a skin sem chroma.
class _Chroma extends StatelessWidget {
  const _Chroma({
    required this.cor,
    required this.escolhido,
    required this.tem,
    required this.aoTocar,
  });
  final Color? cor;
  final bool escolhido;
  final bool tem;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: escolhido,
    label: tem ? 'Chroma' : 'Chroma que você não tem',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tem && !escolhido ? aoTocar : null,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: math.pi / 4,
              child: AnimatedContainer(
                duration: _dur(context, 200),
                width: escolhido ? 20 : 16,
                height: escolhido ? 20 : 16,
                decoration: BoxDecoration(
                  color: (cor ?? Cor.painel2).withValues(alpha: tem ? 1 : 0.3),
                  border: Border.all(
                    color: escolhido ? Cor.ouroClaro : Cor.linha2,
                    width: escolhido ? 2 : 1,
                  ),
                ),
              ),
            ),
            // cadeado no que você não tem, como as miniaturas
            if (!tem)
              Icon(
                Icons.lock_outline,
                size: 12,
                color: Cor.ouroClaro,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
          ],
        ),
      ),
    ),
  );
}

/// Bloco mais leve que o Cartao (sem sombra grande nem respiro de tela inteira).
class _Painel extends StatelessWidget {
  const _Painel({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Cor.painel,
      borderRadius: Raio.r2,
      border: Border.all(color: Cor.linha2),
    ),
    child: child,
  );
}

/// Fase, o que está acontecendo em uma linha, o tempo e a barra que esvazia. Botão do chat ao lado.
class _CabecalhoSelecao extends StatefulWidget {
  const _CabecalhoSelecao({
    required this.con,
    required this.sel,
    required this.naoLidas,
    required this.aoChat,
    this.aoSair,
    this.centro = false,
    this.preparo = true,
  });
  final Conexao con;
  final Map sel;
  final int naoLidas;
  final VoidCallback? aoChat;
  final VoidCallback? aoSair;

  /// Deitado: chamada e tempo centralizados, como no topo da seleção do client.
  final bool centro;

  /// Mostra feitiços e runas no cabeçalho. Em pé eles ficam embaixo dos campeões.
  final bool preparo;

  @override
  State<_CabecalhoSelecao> createState() => _CabecalhoSelecaoState();
}

class _CabecalhoSelecaoState extends State<_CabecalhoSelecao> {
  int? _prazoVisto;
  int _total = 1;
  int?
  _tique; // último segundo que fez tique (os 5 últimos da sua vez, como no client)

  @override
  Widget build(BuildContext context) {
    final sel = widget.sel;
    final con = widget.con;
    final fase = '${sel['fase'] ?? ''}';
    final vez = '${sel['minha_vez'] ?? ''}';
    final meu = ((sel['meu'] as List?) ?? const []).cast<Map>();
    final deles = ((sel['deles'] as List?) ?? const []).cast<Map>();
    final algumBan = [...meu, ...deles].any((m) => m['vez'] == 'ban');
    // em personalizada o ban já abre no planejamento: na sua vez o título segue a ação
    // ARAM: o client sorteia o campeão, não tem draft (Finalização e Todos escolheram não fazem sentido)
    final fila = (sel['fila'] as num?)?.toInt() ?? 0;
    final aram =
        _filasAram.contains(fila) ||
        ((sel['banco'] as List?) ?? const []).isNotEmpty;
    final titulo = switch (fase) {
      _ when aram && fila == 2400 => 'ARAM: Desordem',
      _ when aram => 'ARAM',
      _ when vez == 'ban' => 'Banimentos',
      _ when vez == 'pick' => 'Escolhas',
      'PLANNING' => 'Planejamento',
      'BAN_PICK' => algumBan ? 'Banimentos' : 'Escolhas',
      'FINALIZATION' => 'Finalização',
      'GAME_STARTING' => 'Começando',
      _ => 'Seleção',
    };
    // Arena: todo mundo bana e escolhe ao mesmo tempo, sem "vez do time"
    final arena = sel['arena'] == true;
    final vezAliado = meu.any((m) => '${m['vez'] ?? ''}'.isNotEmpty);
    final vezInimigo = deles.any((m) => '${m['vez'] ?? ''}'.isNotEmpty);
    final suaVez = vez.isNotEmpty;
    final banindo = vez == 'ban';
    final linha = switch (fase) {
      'GAME_STARTING' when aram => 'Boa partida!',
      _ when aram && _temCartas(sel) => 'Escolha uma carta',
      _ when aram && _temSkins(con, sel) => 'Escolha sua preparação',
      _ when aram => 'Sorteando campeões',
      _ when vez == 'ban' => 'Sua vez de banir',
      _ when vez == 'pick' => 'Sua vez de escolher',
      'PLANNING' when arena => 'Prepare-se, os bans já vão abrir',
      'BAN_PICK' when arena && algumBan => 'Esperando os outros banirem',
      'BAN_PICK' when arena && _temSkins(con, sel) => 'Escolha sua skin',
      'BAN_PICK' when arena => 'Esperando os outros escolherem',
      'PLANNING' when sel['pick_pendente'] == true => 'Declare seu campeão',
      'PLANNING' => 'Esperando os bans',
      'FINALIZATION' => 'Todos escolheram',
      'GAME_STARTING' => 'Boa partida!',
      _ when vezAliado => 'Vez do seu time',
      _ when vezInimigo => 'Vez do time inimigo',
      _ => 'Esperando',
    };
    final prazo = (sel['prazo'] as num?)?.toInt();
    final comTempo = prazo != null && sel['infinito'] != true;
    final duracao = (sel['duracao'] as num?)?.toInt() ?? 0;
    if (duracao > 0) {
      _total = duracao; // duração da fase que o client informa
    } else if (comTempo &&
        (_prazoVisto == null || (prazo - _prazoVisto!).abs() > 1500)) {
      // PC sem a duração (versão antiga): o que faltava quando o prazo apareceu. Só recomeça com prazo
      // novo de verdade (outra fase ou ação); o PC antigo mexia uns ms no prazo a cada envio
      _prazoVisto = prazo;
      _total = math.max(1, prazo - con.agora.millisecondsSinceEpoch);
    }
    Widget numero(double tamanho) => Relogio(
      intervalo: const Duration(milliseconds: 250),
      builder: (_) {
        final falta = math.max(
          0,
          ((prazo! - con.agora.millisecondsSinceEpoch) / 1000).ceil(),
        );
        if (suaVez && falta > 0 && falta <= 5 && falta != _tique) {
          _tique = falta;
          som.tocar('tique');
        }
        return Text(
          '$falta',
          style: fonteTitulo(
            tamanho,
            cor: falta <= 5 && suaVez ? Cor.vermelho : Cor.ouroClaro,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        );
      },
    );
    Widget barra({bool centro = false}) => SizedBox(
      height: 3,
      child: comTempo
          ? _BarraPrazo(
              prazo: prazo,
              total: _total,
              agora: () => con.agora.millisecondsSinceEpoch,
              centro: centro,
              cor: suaVez ? Cor.ouro : Cor.ouroEscuro,
              corFim: suaVez ? Cor.vermelho : Cor.ouroEscuro,
              gradiente: banindo
                  ? const LinearGradient(
                      colors: [Cor.vermelho, Color(0xFFFF7A45)],
                    )
                  : null,
            )
          : null,
    );

    if (widget.centro) {
      final chamada = switch (fase) {
        _ when vez == 'ban' => 'Bana um campeão!',
        _ when vez == 'pick' => 'Escolha seu campeão!',
        'PLANNING' when sel['pick_pendente'] == true && !arena =>
          'Declare seu campeão',
        _ when _temCartas(sel) => 'Escolha seu campeão!',
        _ when _temSkins(con, sel) => 'Escolha sua preparação!',
        _ => linha,
      };
      return AnimatedContainer(
        duration: _dur(context, 350),
        curve: curvaSaida,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        decoration: BoxDecoration(
          // sua vez de banir: faixa vermelha atrás da chamada, como o topo do client
          borderRadius: Raio.r2,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF6A1424).withValues(alpha: banindo ? 0.85 : 0),
              const Color(0xFF6A1424).withValues(alpha: 0),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: AnimatedSwitcher(
                    duration: _dur(context, 250),
                    // tela estreita: a chamada diminui um pouco em vez de cortar a palavra
                    child: FittedBox(
                      key: ValueKey(chamada),
                      fit: BoxFit.scaleDown,
                      child: Text(
                        chamada.toUpperCase(),
                        maxLines: 1,
                        style: fonteTitulo(
                          17,
                          cor: suaVez ? Cor.ouroClaro : Cor.texto,
                        ),
                      ),
                    ),
                  ),
                ),
                if (comTempo) ...[const SizedBox(width: 16), numero(26)],
              ],
            ),
            const SizedBox(height: 4),
            FractionallySizedBox(widthFactor: 0.6, child: barra(centro: true)),
          ],
        ),
      );
    }

    final corVez = banindo
        ? Cor.vermelho.withValues(alpha: 0.75)
        : (suaVez ? Cor.ouro : Cor.linha2);
    return AnimatedContainer(
      duration: _dur(context, 300),
      curve: curvaSaida,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
      decoration: BoxDecoration(
        // sua vez de banir: vermelho, como o topo do client nessa hora
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: banindo
              ? const [Color(0xFF3D0F18), Color(0xFF16090D)]
              : suaVez
              ? const [Color(0xFF15140F), Color(0xFF15140F)]
              : [Cor.painel, Cor.painel],
        ),
        borderRadius: Raio.r2,
        border: Border.all(color: corVez),
        boxShadow: suaVez
            ? [
                BoxShadow(
                  color: (banindo ? Cor.vermelho : Cor.ouro).withValues(
                    alpha: banindo ? 0.28 : 0.18,
                  ),
                  blurRadius: 20,
                ),
              ]
            : const [],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final feiticos = widget.preparo && _temFeiticos(con, widget.sel);
          final runas = widget.preparo && _temRunas(con);
          final botoes = [
            if (feiticos) _BotaoFeiticos(con: con, sel: widget.sel),
            if (runas) _BotaoRunas(con: con),
            if (widget.aoChat != null)
              _BotaoChat(naoLidas: widget.naoLidas, aoTocar: widget.aoChat!),
            if (widget.aoSair != null)
              _BotaoSair(con: con, aoTocar: widget.aoSair!),
          ];
          // celular estreito: os botões descem pra uma linha só deles, senão o título e a frase cortavam
          final duasLinhas =
              c.maxWidth -
                  (botoes.length + (feiticos ? 1 : 0)) * 54 -
                  (comTempo ? 44 : 0) <
              170;
          final textos = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: _dur(context, 250),
                child: Text(
                  titulo.toUpperCase(),
                  key: ValueKey(titulo),
                  style: fonteTitulo(13, cor: Cor.apagado),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: _dur(context, 250),
                child: Row(
                  key: ValueKey(linha),
                  children: [
                    if (suaVez) ...[
                      Losango(
                        cor: banindo ? Cor.vermelho : Cor.ouro,
                        tamanho: 8,
                        pulsar: true,
                      ),
                      const SizedBox(width: 9),
                    ],
                    Flexible(
                      child: Text(
                        linha,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: suaVez ? Cor.ouroClaro : Cor.texto,
                          fontWeight: FontWeight.w600,
                          fontSize: 16.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          // preparação (feitiços, runas) à esquerda; chat e sair à direita
          final preparo =
              botoes.length -
              (widget.aoChat != null ? 1 : 0) -
              (widget.aoSair != null ? 1 : 0);
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: textos),
                  if (comTempo) numero(30),
                  if (!duasLinhas)
                    for (final (i, b) in botoes.indexed) ...[
                      SizedBox(width: i == 0 ? 12 : 8),
                      b,
                    ],
                ],
              ),
              if (duasLinhas && botoes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final (i, b) in botoes.indexed) ...[
                      if (i == preparo && i > 0)
                        const Spacer()
                      else if (i > 0)
                        const SizedBox(width: 8),
                      b,
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // tempo da fase: barra fina que esvazia
              barra(),
            ],
          );
        },
      ),
    );
  }
}

class _BotaoChat extends StatelessWidget {
  const _BotaoChat({required this.naoLidas, required this.aoTocar});
  final int naoLidas;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: naoLidas > 0 ? 'Chat, $naoLidas novas' : 'Chat',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: Raio.r1,
                  color: Cor.painel2,
                  border: Border.all(
                    color: naoLidas > 0 ? Cor.ouro : Cor.linha2,
                  ),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: Cor.ouroClaro,
                ),
              ),
            ),
            Positioned(
              right: -6,
              top: -6,
              child: AnimatedScale(
                scale: naoLidas > 0 ? 1 : 0,
                duration: _dur(context, 220),
                curve: curvaSaida,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  height: 19,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Cor.ouro,
                    borderRadius: Raio.r1,
                  ),
                  child: Text(
                    naoLidas > 9 ? '9+' : '$naoLidas',
                    style: TextStyle(
                      color: Cor.fundo,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Em pé, na sua vez e nas skins: os dois times em coluna, como nas laterais do client, com os bans em cima
/// de cada time. Retratos e bans maiores que numa faixa só; a grade fica mais baixa.
class _TimesEmPe extends StatelessWidget {
  const _TimesEmPe({required this.sel, this.con});
  final Map sel;
  final Conexao? con;

  @override
  Widget build(BuildContext context) {
    final bans = (sel['bans'] as Map?) ?? const {};
    final temBans =
        ((bans['meu'] as List?) ?? const []).isNotEmpty ||
        ((bans['deles'] as List?) ?? const []).isNotEmpty;
    final doisTimes = ((sel['deles'] as List?) ?? const []).isNotEmpty;
    // 5 linhas de ~44px, o título e a fileira de bans; tela baixa encolhe as linhas
    final alto = MediaQuery.sizeOf(context).height;
    final altura = ((temBans ? 300.0 : 268.0)).clamp(0.0, alto * 0.4);
    return AnimatedContainer(
      duration: _dur(context, 250),
      curve: curvaSaida,
      height: altura,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _LadoTime(con: con, sel: sel, aliado: true, ban: 26),
          ),
          if (doisTimes) ...[
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Cor.linha,
            ),
            Expanded(
              child: _LadoTime(con: con, sel: sel, aliado: false, ban: 26),
            ),
          ],
        ],
      ),
    );
  }
}

/// Quadro da seleção como no client: seu time à esquerda, inimigos à direita, bans em cima.
class _Quadro extends StatelessWidget {
  const _Quadro({required this.sel, required this.compacto, this.con});
  final Map sel;
  final bool compacto;
  final Conexao? con;

  @override
  Widget build(BuildContext context) {
    String nome(int id) => _nomeCampeao(sel['nomes'], id);
    final meu = ((sel['meu'] as List?) ?? const []).cast<Map>();
    final deles = ((sel['deles'] as List?) ?? const []).cast<Map>();
    final bans = (sel['bans'] as Map?) ?? const {};
    final banMeu = ((bans['meu'] as List?) ?? const []).cast<num>();
    final banDeles = ((bans['deles'] as List?) ?? const []).cast<num>();
    final banco = ((sel['banco'] as List?) ?? const []).cast<num>();
    final doisTimes = deles.isNotEmpty;

    Widget coluna(List<Map> ms, {required bool aliado}) => Column(
      crossAxisAlignment: aliado
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          aliado ? 'SEU TIME' : 'INIMIGOS',
          style: fonteTitulo(12, cor: aliado ? Cor.ouro : Cor.vermelho),
        ),
        const SizedBox(height: 6),
        for (final (i, m) in ms.indexed)
          _Entrada(
            // key no _Entrada: senão quem está embaixo repete a entrada quando a lista muda
            key: ValueKey('${aliado ? 'meu' : 'deles'}-${m['cell']}'),
            chave: '${aliado ? 'meu' : 'deles'}-${m['cell']}',
            atraso: i * 40,
            child: _Slot(
              m: m,
              nome: nome,
              aliado: aliado,
              n: i + 1,
              compacto: compacto,
              aoTrocar: aliado ? _pedirTroca(context, con, sel, m) : null,
              enviando: con?.esperando('troca-${m['cell']}') ?? false,
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banMeu.isNotEmpty || banDeles.isNotEmpty) ...[
          _Painel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _LinhaBans(ids: banMeu, nome: nome),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('BANS', style: fonteTitulo(11, cor: Cor.apagado)),
                ),
                Expanded(
                  child: _LinhaBans(ids: banDeles, nome: nome, fim: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (banco.isNotEmpty) ...[
          _Painel(
            child: _Banco(con: con, sel: sel),
          ),
          const SizedBox(height: 10),
        ],
        _Painel(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
          child: doisTimes
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: coluna(meu, aliado: true)),
                    const SizedBox(width: 8),
                    Expanded(child: coluna(deles, aliado: false)),
                  ],
                )
              : coluna(meu, aliado: true),
        ),
      ],
    );
  }
}

class _LinhaBans extends StatelessWidget {
  const _LinhaBans({required this.ids, required this.nome, this.fim = false});
  final List<num> ids;
  final String Function(int) nome;
  final bool fim;

  @override
  Widget build(BuildContext context) => ids.isEmpty
      ? Align(
          alignment: fim ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            'Nenhum',
            style: TextStyle(color: Cor.apagado, fontSize: 12.5),
          ),
        )
      : Wrap(
          alignment: fim ? WrapAlignment.end : WrapAlignment.start,
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final id in ids)
              Tooltip(
                message: id > 0 ? nome(id.toInt()) : 'Ban pulado',
                child: _IconeCamp(id: id.toInt(), tamanho: 26, banido: true),
              ),
          ],
        );
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.m,
    required this.nome,
    required this.aliado,
    this.n = 0,
    this.compacto = false,
    this.aoTrocar,
    this.enviando = false,
  });
  final Map m;
  final String Function(int) nome;
  final bool aliado;
  final int n;
  final bool compacto;

  /// Tocar pede troca com esse aliado (campeão, posição ou ordem; só quando dá).
  final VoidCallback? aoTrocar;

  /// O pedido de troca foi pro PC e ainda não voltou.
  final bool enviando;

  @override
  Widget build(BuildContext context) {
    final cid = (m['campeao'] as num?)?.toInt() ?? 0;
    final intencao = (m['intencao'] as num?)?.toInt() ?? 0;
    final travado = m['travado'] == true;
    final vez = '${m['vez'] ?? ''}';
    final eu = m['eu'] == true;
    final pos = _posSelecao['${m['pos'] ?? ''}'] ?? '';
    final jogador = aliado
        ? (eu
              ? 'Você'
              : '${m['nome'] ?? ''}'.isEmpty
              ? 'Aliado'
              : '${m['nome']}')
        : (pos.isNotEmpty ? pos : 'Inimigo $n');
    final String campeao;
    if (cid > 0) {
      campeao = nome(cid);
    } else if (intencao > 0) {
      campeao = 'Quer ${nome(intencao)}';
    } else if (vez == 'pick') {
      campeao = 'Escolhendo...';
    } else if (vez == 'ban') {
      campeao = 'Banindo...';
    } else {
      campeao = aliado ? pos : '';
    }
    final icone = _IconeCamp(
      id: cid > 0 ? cid : intencao,
      tamanho: compacto ? 36 : 42,
      fraco: cid == 0 || !travado,
      destaque: eu,
      corBorda: vez.isNotEmpty ? Cor.ouro : null,
    );
    final textos = Expanded(
      child: Column(
        crossAxisAlignment: aliado
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Text(
            jogador,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: eu ? Cor.ouroClaro : Cor.texto,
            ),
          ),
          if (campeao.isNotEmpty)
            Text(
              campeao,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: aliado ? TextAlign.start : TextAlign.end,
              style: TextStyle(
                color: travado ? Cor.texto : Cor.apagado,
                fontSize: 12.5,
                fontStyle: cid > 0 && !travado || intencao > 0 && cid == 0
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
        ],
      ),
    );
    final troca = _seloDe(m, livre: aoTrocar != null);
    final comSelo = _IconePosicao.noRetrato(
      icone,
      m,
      aliado: aliado,
      troca: troca.isNotEmpty && !eu
          ? _SeloTroca(estado: troca, enviando: enviando)
          : null,
    );
    return _Tocavel(
      rotulo: 'Pedir troca com $jogador',
      aoTocar: aoTrocar,
      child: AnimatedContainer(
        duration: _dur(context, 300),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: Raio.r1,
          color: vez.isNotEmpty || troca == 'RECEIVED'
              ? Cor.ouro.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: aliado
              ? [comSelo, const SizedBox(width: 11), textos]
              : [textos, const SizedBox(width: 11), comSelo],
        ),
      ),
    );
  }
}

/// SAIR da seleção (só quando o client mostra o botão). Gira enquanto o PC não responde.
class _BotaoSair extends StatelessWidget {
  const _BotaoSair({
    required this.con,
    required this.aoTocar,
    this.largo = false,
  });
  final Conexao con;
  final VoidCallback aoTocar;

  /// Deitado: botão com texto, como o SAIR do client. Em pé: só o ícone, ao lado do chat.
  final bool largo;

  @override
  Widget build(BuildContext context) {
    final girando = con.esperando('sair_selecao');
    return Semantics(
      button: true,
      label: 'Sair da seleção',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: girando ? null : aoTocar,
        child: AnimatedContainer(
          duration: _dur(context, 200),
          width: largo ? double.infinity : 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: Raio.r1,
            color: Cor.painel2,
            border: Border.all(color: largo ? Cor.ouroEscuro : Cor.linha2),
          ),
          child: AnimatedSwitcher(
            duration: _dur(context, 200),
            child: girando
                ? SizedBox(
                    key: ValueKey('girando'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Cor.ouroClaro,
                    ),
                  )
                : largo
                ? Text(
                    'SAIR',
                    key: ValueKey('texto'),
                    style: TextStyle(
                      color: Cor.ouroClaro,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                      fontSize: 14,
                    ),
                  )
                : Icon(
                    Icons.logout_rounded,
                    key: ValueKey('icone'),
                    size: 20,
                    color: Cor.ouroClaro,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Deitado: um time numa coluna, como nas laterais do client. Bans do time em cima.
class _LadoTime extends StatelessWidget {
  const _LadoTime({
    required this.sel,
    required this.aliado,
    this.ban = 20,
    this.con,
  });
  final Map sel;
  final bool aliado;
  final Conexao? con;

  /// Lado do ícone de cada ban.
  final double ban;

  @override
  Widget build(BuildContext context) {
    String nome(int id) => _nomeCampeao(sel['nomes'], id);
    final ms = ((sel[aliado ? 'meu' : 'deles'] as List?) ?? const [])
        .cast<Map>();
    final bans =
        (((sel['bans'] as Map?) ?? const {})[aliado ? 'meu' : 'deles']
                    as List? ??
                const [])
            .cast<num>();
    return Column(
      crossAxisAlignment: aliado
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          aliado ? 'SEU TIME' : 'INIMIGOS',
          style: fonteTitulo(11, cor: aliado ? Cor.ouro : Cor.vermelho),
        ),
        if (bans.isNotEmpty) ...[
          const SizedBox(height: 5),
          Wrap(
            alignment: aliado ? WrapAlignment.start : WrapAlignment.end,
            spacing: 3,
            runSpacing: 3,
            children: [
              for (final id in bans)
                _IconeCamp(id: id.toInt(), tamanho: ban, banido: true),
            ],
          ),
        ],
        const SizedBox(height: 4),
        // sempre 5 lugares: time menor não estica os retratos
        for (var i = 0; i < 5; i++)
          Expanded(
            child: i < ms.length
                ? _Entrada(
                    chave: '${aliado ? 'meu' : 'deles'}-${ms[i]['cell']}',
                    atraso: i * 40,
                    child: _SlotLado(
                      m: ms[i],
                      nome: nome,
                      aliado: aliado,
                      n: i + 1,
                      aoTrocar: aliado
                          ? _pedirTroca(context, con, sel, ms[i])
                          : null,
                      enviando:
                          con?.esperando('troca-${ms[i]['cell']}') ?? false,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}

class _SlotLado extends StatelessWidget {
  const _SlotLado({
    required this.m,
    required this.nome,
    required this.aliado,
    required this.n,
    this.aoTrocar,
    this.enviando = false,
  });
  final Map m;
  final String Function(int) nome;
  final bool aliado;
  final int n;
  final VoidCallback? aoTrocar;
  final bool enviando;

  @override
  Widget build(BuildContext context) {
    final cid = (m['campeao'] as num?)?.toInt() ?? 0;
    final intencao = (m['intencao'] as num?)?.toInt() ?? 0;
    final travado = m['travado'] == true;
    final vez = '${m['vez'] ?? ''}';
    final eu = m['eu'] == true;
    final pos = _posSelecao['${m['pos'] ?? ''}'] ?? '';
    final jogador = aliado
        ? (eu
              ? 'Você'
              : '${m['nome'] ?? ''}'.isEmpty
              ? 'Aliado'
              : '${m['nome']}')
        : 'Inimigo $n';
    final estado = vez == 'ban'
        ? 'Banindo'
        : vez == 'pick'
        ? 'Escolhendo'
        : pos;
    final camp = cid > 0 ? nome(cid) : (intencao > 0 ? nome(intencao) : '');
    final alinhar = aliado ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    return LayoutBuilder(
      builder: (_, c) {
        final lado = math.min(46.0, c.maxHeight - 8);
        final retrato = AnimatedContainer(
          duration: _dur(context, 250),
          width: lado,
          height: lado,
          // anel por fora com um respiro, como no client: a imagem não cobre mais o contorno
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Cor.fundo,
            border: Border.all(
              color: vez.isNotEmpty || eu
                  ? Cor.ouro
                  : (aliado ? Cor.linha2 : Cor.vermelho.withValues(alpha: .5)),
              width: vez.isNotEmpty ? 2 : 1.2,
            ),
          ),
          child: ClipOval(
            child: AnimatedOpacity(
              opacity: cid > 0 && travado ? 1 : (cid + intencao > 0 ? .5 : 1),
              duration: _dur(context, 250),
              child: cid + intencao > 0
                  // zoom leve: o ícone tem moldura escura nos cantos que aparecia no círculo
                  ? Transform.scale(
                      scale: 1.14,
                      child: Image.network(
                        _iconeCampeao(cid > 0 ? cid : intencao),
                        key: ValueKey(cid > 0 ? cid : intencao),
                        fit: BoxFit.cover,
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: Cor.painel2),
                      ),
                    )
                  : ColoredBox(
                      color: Cor.painel2,
                      child: Center(
                        child: Losango(cor: Cor.linha2, tamanho: 7),
                      ),
                    ),
            ),
          ),
        );
        final estiloNome = TextStyle(
          fontSize: 13,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: camp.isNotEmpty ? 0.3 : 0,
          fontStyle: cid == 0 && intencao > 0
              ? FontStyle.italic
              : FontStyle.normal,
          color: eu ? Cor.ouroClaro : Cor.texto,
        );
        final textoNome = camp.isNotEmpty ? camp.toUpperCase() : jogador;
        // largura que sobra pro texto: linha menos o padding, o fio da vez, o retrato e o respiro
        // (fio da vez dos dois lados, transparente quando não é a vez, e 2px de folga)
        final largura = c.maxWidth - 12 - 6 - lado - 11 - 2;
        final umaLinha =
            (TextPainter(
              text: TextSpan(
                text: textoNome,
                style: DefaultTextStyle.of(context).style.merge(estiloNome),
              ),
              maxLines: 1,
              textDirection: TextDirection.ltr,
              textScaler: MediaQuery.textScalerOf(context),
            )..layout()).width <=
            largura;
        // nome comprido (Nunu e Willump, Aurelion Sol) vai em 2 linhas. Sem altura pra tudo, sai primeiro a
        // posição escrita (o selo no retrato já mostra) e, na vez de alguém, o nome do jogador
        var comEstado = estado.isNotEmpty && c.maxHeight >= 50;
        var comJogador = camp.isNotEmpty;
        var linhasNome = 1;
        double alto() =>
            (comEstado ? 14 : 0) + (comJogador ? 15 : 0) + linhasNome * 15.0;
        if (!umaLinha) {
          linhasNome = 2;
          if (alto() > c.maxHeight && comEstado && vez.isEmpty) {
            comEstado = false;
          }
          if (alto() > c.maxHeight && comJogador && vez.isNotEmpty) {
            comJogador = false;
          }
          if (alto() > c.maxHeight) {
            linhasNome = 1;
          }
        }
        final textos = Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: alinhar,
            children: [
              if (comEstado)
                Text(
                  estado,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: vez.isNotEmpty ? Cor.ouro : Cor.apagado,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                textoNome,
                maxLines: linhasNome,
                overflow: TextOverflow.ellipsis,
                textAlign: aliado ? TextAlign.start : TextAlign.end,
                style: estiloNome,
              ),
              if (comJogador)
                Text(
                  jogador,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: eu ? Cor.ouro : Cor.apagado,
                  ),
                ),
            ],
          ),
        );
        // vez de alguém: fio dourado do lado de fora, como no client
        final troca = _seloDe(m, livre: aoTrocar != null);
        final comSelo = _IconePosicao.noRetrato(
          retrato,
          m,
          aliado: aliado,
          troca: troca.isNotEmpty && !eu
              ? _SeloTroca(estado: troca, enviando: enviando)
              : null,
        );
        final linha = AnimatedContainer(
          duration: _dur(context, 300),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            gradient: vez.isNotEmpty
                ? LinearGradient(
                    begin: aliado
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    end: aliado ? Alignment.centerRight : Alignment.centerLeft,
                    colors: [
                      Cor.ouro.withValues(alpha: 0.16),
                      Cor.ouro.withValues(alpha: 0),
                    ],
                  )
                : null,
            border: Border(
              left: BorderSide(
                color: aliado && vez.isNotEmpty ? Cor.ouro : Colors.transparent,
                width: 3,
              ),
              right: BorderSide(
                color: !aliado && vez.isNotEmpty
                    ? Cor.ouro
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: aliado
                ? [comSelo, const SizedBox(width: 11), textos]
                : [textos, const SizedBox(width: 11), comSelo],
          ),
        );
        return _Tocavel(
          rotulo: 'Pedir troca com $jogador',
          aoTocar: aoTrocar,
          child: linha,
        );
      },
    );
  }
}

/// Ícone da posição do jogador, num selo no retrato. Sem posição (ARAM, blind) não aparece.
class _IconePosicao extends StatelessWidget {
  const _IconePosicao({required this.pos, required this.nome});
  final String pos;
  final String nome;

  /// Retrato com a posição num selo no canto de baixo (do lado do texto): o ícone ao lado do retrato
  /// tirava largura do nome do campeão, que cortava.
  /// [troca]: selo de troca com o aliado, no canto de cima.
  static Widget noRetrato(
    Widget retrato,
    Map m, {
    required bool aliado,
    Widget? troca,
  }) {
    final pos = '${m['pos'] ?? ''}';
    final nome = _posSelecao[pos];
    if (nome == null && troca == null) return retrato;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        retrato,
        if (troca != null) Positioned(top: -5, right: -7, child: troca),
        if (nome != null)
          Positioned(
            bottom: -3,
            right: aliado ? -5 : null,
            left: aliado ? null : -5,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Cor.fundo,
                border: Border.all(color: Cor.linha2),
              ),
              child: _IconePosicao(pos: pos, nome: nome),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: nome,
      child: Image(
        image: _fontePosicao(pos),
        width: 12,
        height: 12,
        filterQuality: FilterQuality.medium,
        // entra suave se a imagem ainda não estava no cache
        frameBuilder: (_, filho, quadro, sincrono) => sincrono
            ? filho
            : AnimatedOpacity(
                opacity: quadro == null ? 0 : 1,
                duration: _dur(context, 250),
                child: filho,
              ),
        errorBuilder: (_, _, _) => const SizedBox(width: 12, height: 12),
      ),
    );
  }
}

class _IconeCamp extends StatelessWidget {
  const _IconeCamp({
    required this.id,
    required this.tamanho,
    this.fraco = false,
    this.banido = false,
    this.destaque = false,
    this.corBorda,
  });
  final int id;
  final double tamanho;
  final bool fraco;
  final bool banido;
  final bool destaque;
  final Color? corBorda;

  @override
  Widget build(BuildContext context) {
    // banido em cinza pelo próprio Image (sem ColorFiltered: uma camada a mais por campeão)
    final Widget img = id > 0
        ? Image.network(
            _iconeCampeao(id),
            key: ValueKey('$id-$banido'),
            fit: BoxFit.cover,
            color: banido ? Colors.grey : null,
            colorBlendMode: banido ? BlendMode.saturation : null,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            errorBuilder: (_, _, _) => ColoredBox(color: Cor.painel2),
          )
        : ColoredBox(
            color: Cor.painel2,
            child: Center(child: Losango(cor: Cor.linha2, tamanho: 8)),
          );
    return AnimatedContainer(
      duration: _dur(context, 250),
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        borderRadius: Raio.r1,
        border: Border.all(
          color:
              corBorda ??
              (destaque
                  ? Cor.ouro
                  : (banido
                        ? Cor.vermelho.withValues(alpha: 0.6)
                        : Cor.linha2)),
          width: destaque || corBorda == Cor.ouro ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: fraco ? 0.45 : 1,
            duration: _dur(context, 250),
            child: AnimatedSwitcher(duration: _dur(context, 250), child: img),
          ),
          if (banido) CustomPaint(painter: _Risco()),
        ],
      ),
    );
  }
}

/// Risco vermelho em diagonal no campeão banido.
class _Risco extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawLine(
    Offset(size.width, 0),
    Offset(0, size.height),
    Paint()
      ..color = Cor.vermelho
      ..strokeWidth = 2,
  );

  @override
  bool shouldRepaint(_Risco old) => false;
}

/// Barra do tempo da vez: anda a cada quadro, liso, só pintando um retângulo na própria camada
/// (antes um Relogio de 250ms com AnimatedFractionallySizedBox refazia o layout a seleção toda).
class _BarraPrazo extends StatefulWidget {
  const _BarraPrazo({
    required this.prazo,
    required this.total,
    required this.agora,
    required this.centro,
    required this.cor,
    required this.corFim,
    this.gradiente,
  });
  final int prazo;
  final int total;
  final int Function() agora;
  final bool centro; // no meio, esvazia das pontas pro centro (igual no client)
  final Color cor;
  final Color corFim; // nos últimos 20%
  final Gradient? gradiente;

  @override
  State<_BarraPrazo> createState() => _BarraPrazoState();
}

class _BarraPrazoState extends State<_BarraPrazo>
    with SingleTickerProviderStateMixin {
  late final _f = ValueNotifier<double>(_fracao());
  late final _ticker = createTicker((_) {
    final f = _fracao();
    if (f != _f.value) _f.value = f;
  })..start();

  double _fracao() =>
      ((widget.prazo - widget.agora()) / widget.total).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _ticker;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: _PintaPrazo(
        _f,
        widget.centro,
        widget.cor,
        widget.corFim,
        widget.gradiente,
      ),
    ),
  );
}

class _PintaPrazo extends CustomPainter {
  _PintaPrazo(this.f, this.centro, this.cor, this.corFim, this.gradiente)
    : super(repaint: f);
  final ValueNotifier<double> f;
  final bool centro;
  final Color cor;
  final Color corFim;
  final Gradient? gradiente;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * f.value;
    if (w <= 0) return;
    final r = Rect.fromLTWH(
      centro ? (size.width - w) / 2 : 0,
      0,
      w,
      size.height,
    );
    final p = Paint();
    if (gradiente != null) {
      p.shader = gradiente!.createShader(r);
    } else {
      p.color = f.value < 0.2 ? corFim : cor;
    }
    canvas.drawRect(r, p);
  }

  @override
  bool shouldRepaint(_PintaPrazo o) =>
      o.f != f ||
      o.centro != centro ||
      o.cor != cor ||
      o.corFim != corFim ||
      o.gradiente != gradiente;
}
