part of 'main.dart';

/// Arte do campeão centralizada (a splash com ele no meio): numa carta em pé corta só as laterais.
/// O `v1/champion-splashes` do raw saiu do CommunityDragon (404): a CDN acha a splash pelo id e libera CORS.
String _arteCarta(int id) =>
    'https://cdn.communitydragon.org/latest/champion/$id/splash-art/centered';

/// Tem cartas pra escolher (ARAM Desordem, começo da seleção, você ainda não escolheu).
bool _temCartas(Map sel) => ((sel['cartas'] as List?) ?? const []).isNotEmpty;

/// Cartas do começo da ARAM Desordem, como no client: 2 ou 3 campeões lado a lado (com 3, a última é a carta
/// da sorte). Tocar escolhe, como clicar na carta. Elas entram uma depois da outra com o som do client.
class _Cartas extends StatefulWidget {
  const _Cartas({super.key, required this.con, required this.sel});
  final Conexao con;
  final Map sel;

  @override
  State<_Cartas> createState() => _CartasState();
}

class _CartasState extends State<_Cartas> with SingleTickerProviderStateMixin {
  late final _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  // uma curva por carta, criada uma vez (no build prenderia listener a cada redesenho)
  final _curvas = <CurvedAnimation>[];
  int? _escolhida; // tocada aqui, esperando o PC
  Timer? _desfaz;
  bool _comecou = false;

  List<int> get _ids => [
    for (final c in (widget.sel['cartas'] as List?) ?? const [])
      if (c is num) c.toInt(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_comecou) return;
    _comecou = true;
    final n = _ids.length;
    for (var i = 0; i < 3; i++) {
      final ini = n <= 1 ? 0.0 : i / n * 0.45;
      _curvas.add(
        CurvedAnimation(
          parent: _entrada,
          curve: Interval(ini, math.min(1, ini + 0.55), curve: curvaSaida),
        ),
      );
    }
    _comecar();
  }

  /// Artes carregadas antes de entrar (no máximo 700ms): a carta não aparece vazia no meio da animação.
  Future<void> _comecar() async {
    try {
      await Future.wait([
        for (final id in _ids)
          precacheImage(
            NetworkImage(
              _arteCarta(id),
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            ),
            context,
          ),
      ]).timeout(const Duration(milliseconds: 700));
    } catch (_) {}
    if (!mounted) return;
    som.tocar(_ids.length >= 3 ? 'cartas_3' : 'cartas_2');
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrada.value = 1;
    } else {
      _entrada.forward();
    }
  }

  @override
  void dispose() {
    _desfaz?.cancel();
    for (final c in _curvas) {
      c.dispose();
    }
    _entrada.dispose();
    super.dispose();
  }

  void _escolher(int id) {
    som.tocar('carta');
    _desfaz?.cancel();
    _desfaz = null;
    setState(() => _escolhida = id);
    widget.con.enviar('carta', {'campeao': id}, 'carta-$id');
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids;
    final con = widget.con;
    // o PC respondeu e as cartas continuam aqui (ele recusou): a carta volta ao normal e dá pra tocar de
    // novo. Com um respiro, porque no acerto a seleção nova (sem cartas) chega logo depois da resposta
    if (_escolhida != null &&
        !con.esperando('carta-$_escolhida') &&
        _desfaz == null) {
      _desfaz = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _escolhida = null);
      });
    }
    final deitado = _deitado(context);
    return Column(
      children: [
        Text(
          'ESCOLHA SEU CAMPEÃO',
          style: fonteTitulo(deitado ? 13 : 15, cor: Cor.ouroClaro),
        ),
        const SizedBox(height: 4),
        Text(
          'Toque numa carta',
          style: TextStyle(color: Cor.apagado, fontSize: 13),
        ),
        SizedBox(height: deitado ? 10 : 18),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              const vao = 10.0;
              final n = math.max(ids.length, 2);
              // carta em pé (2:3), do tamanho que couber na largura e na altura
              final largura = math.min(
                (c.maxWidth - vao * (n - 1)) / n,
                c.maxHeight / 1.5,
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, id) in ids.indexed) ...[
                    if (i > 0) const SizedBox(width: vao),
                    _EntradaCarta(
                      animacao: _curvas[math.min(i, 2)],
                      child: _Carta(
                        key: ValueKey('carta-$id'),
                        id: id,
                        nome: _nomeCampeao(widget.sel['nomes'], id),
                        largura: largura,
                        sorte: ids.length == 3 && i == 2,
                        escolhida: _escolhida == id,
                        apagada: _escolhida != null && _escolhida != id,
                        esperando: con.esperando('carta-$id'),
                        aoTocar: _escolhida == null && con.ocupado == null
                            ? () => _escolher(id)
                            : null,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Carta subindo e virando de leve ao entrar, como as do client.
class _EntradaCarta extends StatelessWidget {
  const _EntradaCarta({required this.animacao, required this.child});
  final Animation<double> animacao;
  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: FadeTransition(
      opacity: animacao,
      child: AnimatedBuilder(
        animation: animacao,
        child: child,
        builder: (_, c) {
          final t = animacao.value;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..translateByDouble(0, (1 - t) * 40, 0, 1)
              ..rotateY((1 - t) * 0.6)
              ..scaleByDouble(0.9 + 0.1 * t, 0.9 + 0.1 * t, 1, 1),
            child: c,
          );
        },
      ),
    ),
  );
}

class _Carta extends StatelessWidget {
  const _Carta({
    super.key,
    required this.id,
    required this.nome,
    required this.largura,
    required this.sorte,
    required this.escolhida,
    required this.apagada,
    required this.esperando,
    required this.aoTocar,
  });
  final int id;
  final String nome;
  final double largura;
  final bool sorte;
  final bool escolhida;
  final bool apagada;
  final bool esperando;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final corBorda = escolhida
        ? Cor.ouroClaro
        : (sorte ? Cor.ouro : Cor.ouroEscuro);
    return _Tocavel(
      rotulo: nome.isEmpty ? 'Escolher carta' : 'Escolher $nome',
      afundar: 0.96,
      aoTocar: aoTocar,
      child: AnimatedScale(
        scale: escolhida ? 1.04 : (apagada ? 0.96 : 1),
        duration: _dur(context, 260),
        curve: curvaSaida,
        child: AnimatedOpacity(
          opacity: apagada ? 0.4 : 1,
          duration: _dur(context, 260),
          curve: curvaSaida,
          child: AnimatedContainer(
            duration: _dur(context, 260),
            curve: curvaSaida,
            width: largura,
            height: largura * 1.5,
            decoration: BoxDecoration(
              borderRadius: Raio.r2,
              color: Cor.painel2,
              border: Border.all(
                color: corBorda,
                width: escolhida || sorte ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (escolhida || sorte ? Cor.ouro : Colors.black)
                      .withValues(alpha: escolhida ? 0.45 : 0.25),
                  blurRadius: escolhida ? 22 : 12,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  _arteCarta(id),
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.2),
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (_, _, _) => Center(
                    child: _IconeCamp(id: id, tamanho: largura * 0.5),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.5, 1],
                      colors: [Color(0x00010A13), Color(0xF2010A13)],
                    ),
                  ),
                ),
                if (sorte)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE6010A13),
                          borderRadius: Raio.r1,
                          border: Border.all(color: Cor.ouro),
                        ),
                        child: Text('SORTE', style: fonteTitulo(10)),
                      ),
                    ),
                  ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 10,
                  child: Text(
                    nome.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: fonteTitulo(
                      largura < 110 ? 12 : 14,
                      cor: escolhida ? Cor.ouro : Cor.ouroClaro,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedSwitcher(
                      duration: _dur(context, 180),
                      child: esperando
                          ? ColoredBox(
                              key: ValueKey('esperando'),
                              color: Color(0x66010A13),
                              child: Center(
                                child: Losango(
                                  cor: Cor.ouro,
                                  tamanho: 10,
                                  pulsar: true,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('livre')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
