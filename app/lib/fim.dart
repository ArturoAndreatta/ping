part of 'main.dart';

/// Fim de partida: o PC manda `fim` assim que o nexus cai (evento GameEnd da API do jogo) e segue mandando
/// até o client sair do fim de partida (números do `eog-stats-block`). Tela cheia com vitória, derrota ou
/// remake, a arte da sua skin ao fundo e seus números.

const _fasesFim = {'WaitingForStats', 'PreEndOfGame', 'EndOfGame'};

Map? _fimDe(Conexao con) {
  // Fechado também: o client cai por uns segundos logo que a partida acaba e o PC segura o resultado
  if (!_fasesJogo.contains(con.fase) &&
      !_fasesFim.contains(con.fase) &&
      con.fase != 'Fechado') {
    return null;
  }
  final f = con.estado['fim'];
  return f is Map && f['resultado'] is String ? f : null;
}

/// Cores e textos de cada resultado.
typedef _Tom = ({
  String titulo,
  Color cor,
  Color claro,
  Color brilho,
  String som,
});

_Tom _tomDe(String resultado) => switch (resultado) {
  'vitoria' => (
    titulo: 'VITÓRIA',
    cor: Cor.ouro,
    claro: Cor.ouroClaro,
    brilho: const Color(0xFFFFE9B0),
    som: 'vitoria',
  ),
  'derrota' => (
    titulo: 'DERROTA',
    cor: Cor.vermelho,
    claro: const Color(0xFFF4C6CC),
    brilho: const Color(0xFFFF8A9A),
    som: 'derrota',
  ),
  _ => (
    titulo: 'REMAKE',
    cor: Cor.teal,
    claro: const Color(0xFFCDF7F2),
    brilho: const Color(0xFF8FF3EA),
    som: 'remake',
  ),
};

/// Duração da entrada inteira (título, emblema, números). Os tempos de cada parte são frações dela.
const _entradaMs = 2600;

/// Volta completa dos raios e ciclo das faíscas. Os períodos das faíscas dividem este tempo, então a volta
/// do `repeat` não dá pulo.
const _cicloS = 24.0;

class _Fim extends StatefulWidget {
  const _Fim({required this.fim});
  final Map fim;

  @override
  State<_Fim> createState() => _FimState();
}

class _FimState extends State<_Fim> with TickerProviderStateMixin {
  late final _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _entradaMs),
  );
  late final _sempre = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: (_cicloS * 1000) ~/ 1),
  );
  late final _arteCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _comecou = false;

  // criadas uma vez (no build prenderiam listener a cada redesenho)
  late final _tituloEscala = CurvedAnimation(
    parent: _entrada,
    curve: const Interval(0.1, 0.42, curve: curvaSaida),
  );
  late final _tituloOpaco = CurvedAnimation(
    parent: _entrada,
    curve: const Interval(0.1, 0.24, curve: Curves.easeOut),
  );
  late final _raiosOpaco = CurvedAnimation(
    parent: _entrada,
    curve: const Interval(0.28, 0.7, curve: Curves.easeOut),
  );
  late final _flash = TweenSequence([
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 26),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 6,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 30,
    ),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 38),
  ]).animate(_entrada);
  late final _arteOpaco = CurvedAnimation(
    parent: _arteCtrl,
    curve: Curves.easeOut,
  );
  late final _arteEscala = Tween(
    begin: 1.12,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _entrada, curve: curvaSaida));

  late _Tom _tom = _tomDe('${widget.fim['resultado']}');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_comecou) return;
    _comecou = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrada.value = 1;
      _arteCtrl.value = 1;
    } else {
      _entrada.forward();
      _sempre.repeat();
    }
  }

  @override
  void didUpdateWidget(_Fim antigo) {
    super.didUpdateWidget(antigo);
    _tom = _tomDe('${widget.fim['resultado']}');
  }

  @override
  void dispose() {
    _tituloEscala.dispose();
    _tituloOpaco.dispose();
    _raiosOpaco.dispose();
    _arteOpaco.dispose();
    _entrada.dispose();
    _sempre.dispose();
    _arteCtrl.dispose();
    super.dispose();
  }

  /// Entra de baixo, apagado, na sua vez da fila (`i`).
  Widget _surge(int i, Widget filho) {
    final a = CurvedAnimation(
      parent: _entrada,
      curve: Interval(
        math.min(0.46 + i * 0.07, 0.8),
        math.min(0.76 + i * 0.07, 1),
        curve: curvaSaida,
      ),
    );
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(a),
        child: filho,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fim;
    final resultado = '${f['resultado']}';
    final derrota = resultado == 'derrota';
    final cid = f['campeao'] is int ? f['campeao'] as int : 0;
    final arte = cid > 0 && '${f['arte'] ?? ''}'.isNotEmpty
        ? _arte(f['arte'], cid)
        : null;
    final deitado = _deitado(context);

    final fundo = Stack(
      fit: StackFit.expand,
      children: [
        if (arte != null)
          RepaintBoundary(
            child: ScaleTransition(
              scale: _arteEscala,
              child: Image.network(
                arte,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.3),
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                opacity: Tween(
                  begin: 0.0,
                  end: derrota ? 0.2 : 0.38,
                ).animate(_arteOpaco),
                // derrota sem cor: o cinza vai no próprio Image, não num filtro por cima
                color: derrota ? const Color(0xFF808080) : null,
                colorBlendMode: derrota ? BlendMode.saturation : null,
                frameBuilder: (_, filho, quadro, _) {
                  if (quadro != null && _arteCtrl.isDismissed) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _arteCtrl.isDismissed) _arteCtrl.forward();
                    });
                  }
                  return filho;
                },
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Cor.fundo.withValues(alpha: 0.55),
                Cor.fundo.withValues(alpha: 0.2),
                Cor.fundo.withValues(alpha: 0.75),
                Cor.fundo,
              ],
              stops: const [0, 0.35, 0.75, 1],
            ),
          ),
        ),
        // faíscas pela tela toda: douradas subindo na vitória, cinzas caindo na derrota
        RepaintBoundary(
          child: CustomPaint(
            painter: _Faiscas(
              sempre: _sempre,
              entrada: _entrada,
              tom: _tom,
              resultado: resultado,
            ),
          ),
        ),
      ],
    );

    final numeros = _Numeros(fim: f, tom: _tom, surge: _surge);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          fundo,
          LayoutBuilder(
            builder: (context, c) {
              if (deitado) {
                final lado = math.min(c.maxHeight * 0.82, c.maxWidth * 0.42);
                return Row(
                  children: [
                    Expanded(child: Center(child: _emblema(lado, resultado))),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: numeros,
                        ),
                      ),
                    ),
                  ],
                );
              }
              final lado = math.min(c.maxWidth * 0.92, c.maxHeight * 0.5);
              return Column(
                children: [
                  const Spacer(flex: 2),
                  _emblema(lado, resultado),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: numeros,
                  ),
                  const Spacer(flex: 2),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Raios girando, clarão, o emblema se desenhando e o título por cima.
  Widget _emblema(double lado, String resultado) {
    final derrota = resultado == 'derrota';
    final titulo = Text(
      _tom.titulo,
      maxLines: 1,
      softWrap: false,
      style: fonteTitulo(lado * 0.17, cor: _tom.claro).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: lado * 0.018,
        height: 1,
        shadows: [
          Shadow(color: _tom.cor.withValues(alpha: 0.9), blurRadius: 18),
          Shadow(color: _tom.cor.withValues(alpha: 0.5), blurRadius: 42),
        ],
      ),
    );
    return SizedBox.square(
      dimension: lado,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // raios: pintados uma vez, a volta só gira a camada
          Positioned.fill(
            child: RepaintBoundary(
              child: FadeTransition(
                opacity: _raiosOpaco,
                child: RotationTransition(
                  turns: _sempre,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _Raios(cor: _tom.cor, poucos: derrota),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // clarão na hora do impacto do título
          Positioned.fill(
            child: FadeTransition(
              opacity: _flash,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _tom.brilho.withValues(alpha: derrota ? 0.35 : 0.6),
                      _tom.cor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _Emblema(
                  entrada: _entrada,
                  cor: _tom.cor,
                  claro: _tom.claro,
                  quebrado: derrota,
                ),
              ),
            ),
          ),
          SizedBox(
            width: lado * 0.72,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: derrota
                  ? _tituloCaindo(titulo)
                  : _tituloExplodindo(titulo),
            ),
          ),
        ],
      ),
    );
  }

  /// Vitória e remake: o título chega grande e assenta, e um brilho passa por ele.
  Widget _tituloExplodindo(Widget titulo) => FadeTransition(
    opacity: _tituloOpaco,
    child: ScaleTransition(
      scale: Tween(begin: 2.1, end: 1.0).animate(_tituloEscala),
      child: _Brilho(entrada: _entrada, cor: _tom.brilho, child: titulo),
    ),
  );

  /// Derrota: o título cai pesado, treme no impacto e assenta.
  Widget _tituloCaindo(Widget titulo) => FadeTransition(
    opacity: _tituloOpaco,
    child: AnimatedBuilder(
      animation: _entrada,
      builder: (_, filho) {
        final t = _entrada.value;
        final queda = const Interval(
          0.1,
          0.34,
          curve: Curves.easeInCubic,
        ).transform(t);
        // tremida que some: só no instante em que o título bate
        final s = ((t - 0.34) / 0.2).clamp(0.0, 1.0);
        final tremida = t < 0.34
            ? 0.0
            : math.sin(s * math.pi * 6) * 7 * (1 - s);
        return Transform.translate(
          offset: Offset(tremida, -60 * (1 - queda)),
          child: Transform.scale(scale: 1.25 - 0.25 * queda, child: filho),
        );
      },
      child: titulo,
    ),
  );
}

/// Brilho que atravessa o título uma vez, logo depois de ele assentar.
class _Brilho extends StatelessWidget {
  const _Brilho({
    required this.entrada,
    required this.cor,
    required this.child,
  });
  final Animation<double> entrada;
  final Color cor;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: entrada,
    builder: (_, filho) {
      final p = const Interval(
        0.4,
        0.68,
        curve: Curves.easeInOut,
      ).transform(entrada.value);
      if (p <= 0 || p >= 1) return filho!;
      final x = -1.6 + 3.2 * p;
      return ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) => LinearGradient(
          begin: Alignment(x - 0.5, -0.4),
          end: Alignment(x + 0.5, 0.4),
          colors: [cor.withValues(alpha: 0), cor, cor.withValues(alpha: 0)],
          stops: const [0.3, 0.5, 0.7],
        ).createShader(r),
        child: filho,
      );
    },
    child: child,
  );
}

/// Campeão, KDA, CS, tempo e placar.
class _Numeros extends StatelessWidget {
  const _Numeros({required this.fim, required this.tom, required this.surge});
  final Map fim;
  final _Tom tom;
  final Widget Function(int, Widget) surge;

  @override
  Widget build(BuildContext context) {
    final f = fim;
    final cid = f['campeao'] is int ? f['campeao'] as int : 0;
    final nome = '${f['nome_campeao'] ?? ''}';
    final fila = '${f['fila'] ?? ''}';
    // Arena tem vários times: não existe placar de dois lados, só a colocação (quando o client traz)
    final arena = f['arena'] == true;
    final placar =
        !arena && f['placar'] is List && (f['placar'] as List).length == 2
        ? f['placar'] as List
        : null;
    final colocacao = f['colocacao'] is int ? f['colocacao'] as int : 0;
    final temKda = f['k'] is int && f['d'] is int && f['a'] is int;
    final remake = f['resultado'] == 'remake';
    var i = 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        surge(
          i++,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (cid > 0) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: Raio.r1,
                    border: Border.all(color: tom.cor.withValues(alpha: 0.7)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    _iconeCampeao(cid),
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (_, _, _) => ColoredBox(color: Cor.painel2),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      remake
                          ? 'Partida encerrada cedo'
                          : (nome.isNotEmpty ? nome : 'Fim de partida'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Cor.texto,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (fila.isNotEmpty)
                      Text(
                        fila,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Cor.apagado, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        surge(
          i++,
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Cor.painel.withValues(alpha: 0.82),
              borderRadius: Raio.r2,
              border: Border.all(color: tom.cor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                if (temKda)
                  _Dado(
                    rotulo: 'KDA',
                    valor: '${f['k']} / ${f['d']} / ${f['a']}',
                  ),
                if (f['cs'] is int) _Dado(rotulo: 'CS', valor: '${f['cs']}'),
                if (arena && colocacao > 0)
                  _Dado(rotulo: 'COLOCAÇÃO', valor: '$colocacaoº'),
                if (f['duracao'] is int)
                  _Dado(rotulo: 'TEMPO', valor: _mmss(f['duracao'] as int)),
              ],
            ),
          ),
        ),
        if (placar != null) ...[
          const SizedBox(height: 14),
          surge(
            i++,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Lado(texto: 'SEU TIME', valor: '${placar[0]}', cor: Cor.teal),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text('x', style: fonteTitulo(16, cor: Cor.apagado)),
                ),
                _Lado(
                  texto: 'INIMIGO',
                  valor: '${placar[1]}',
                  cor: Cor.vermelho,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Dado extends StatelessWidget {
  const _Dado({required this.rotulo, required this.valor});
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          valor,
          maxLines: 1,
          style: TextStyle(
            color: Cor.ouroClaro,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          rotulo,
          style: TextStyle(
            color: Cor.apagado,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
      ],
    ),
  );
}

/// Raios saindo do centro, fixos (quem gira é a camada).
class _Raios extends CustomPainter {
  _Raios({required this.cor, required this.poucos});
  final Color cor;
  final bool poucos;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.75;
    final n = poucos ? 10 : 18;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          cor.withValues(alpha: poucos ? 0.08 : 0.26),
          cor.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2;
      final meia = (i.isEven ? 0.07 : 0.035) * math.pi;
      final p = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - meia) * r, c.dy + math.sin(a - meia) * r)
        ..lineTo(c.dx + math.cos(a + meia) * r, c.dy + math.sin(a + meia) * r)
        ..close();
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(_Raios old) => old.cor != cor || old.poucos != poucos;
}

/// Emblema hextech que se desenha na entrada: anel, marcas, losango e as quatro pedras. Na derrota o anel
/// fica partido.
class _Emblema extends CustomPainter {
  _Emblema({
    required this.entrada,
    required this.cor,
    required this.claro,
    required this.quebrado,
  }) : super(repaint: entrada);
  final Animation<double> entrada;
  final Color cor;
  final Color claro;
  final bool quebrado;

  static double _em(
    double t,
    double a,
    double b, [
    Curve c = Curves.easeInOut,
  ]) => c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final t = entrada.value;
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.4;
    final traco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // anel de fora: corre em volta (partido na derrota, com as pontas se afastando)
    final anel = _em(t, 0, 0.36, curvaSaida);
    if (anel > 0) {
      traco
        ..strokeWidth = 2
        ..color = cor.withValues(alpha: 0.9);
      final rect = Rect.fromCircle(center: c, radius: r);
      if (quebrado) {
        const partes = 7;
        final folga = 0.05 + 0.12 * _em(t, 0.34, 0.6, curvaSaida);
        for (var i = 0; i < partes; i++) {
          final ini = (i / partes + folga / 2) * math.pi * 2 - math.pi / 2;
          final tam = (1 / partes - folga) * math.pi * 2 * anel;
          canvas.drawArc(rect, ini, tam, false, traco);
        }
      } else {
        canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * anel, false, traco);
      }
    }

    // anel de dentro e marcas
    final dentro = _em(t, 0.16, 0.44);
    if (dentro > 0) {
      traco
        ..strokeWidth = 1
        ..color = cor.withValues(alpha: 0.4 * dentro);
      canvas.drawCircle(c, r * 0.88, traco);
      final marca = Paint()
        ..strokeWidth = 1.2
        ..color = cor.withValues(alpha: 0.5 * dentro);
      for (var i = 0; i < 36; i++) {
        final a = i / 36 * math.pi * 2;
        final l = i % 3 == 0 ? 0.06 : 0.03;
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + d * r * 0.9, c + d * r * (0.9 + l), marca);
      }
    }

    // losango atrás do título, traçado do topo
    final los = _em(t, 0.12, 0.46, curvaSaida);
    if (los > 0) {
      final m = r * 0.66;
      final p = Path()
        ..moveTo(c.dx, c.dy - m)
        ..lineTo(c.dx + m * 1.25, c.dy)
        ..lineTo(c.dx, c.dy + m)
        ..lineTo(c.dx - m * 1.25, c.dy)
        ..close();
      final metrica = p.computeMetrics().first;
      traco
        ..strokeWidth = 1.4
        ..color = cor.withValues(alpha: 0.55);
      canvas.drawPath(metrica.extractPath(0, metrica.length * los), traco);
    }

    // quatro pedras no anel, aparecendo uma depois da outra
    for (var i = 0; i < 4; i++) {
      final s = _em(t, 0.3 + i * 0.05, 0.46 + i * 0.05, Curves.easeOutBack);
      if (s <= 0) continue;
      final a = -math.pi / 2 + i * math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      final h = r * 0.07 * s;
      final pedra = Path()
        ..moveTo(p.dx, p.dy - h)
        ..lineTo(p.dx + h, p.dy)
        ..lineTo(p.dx, p.dy + h)
        ..lineTo(p.dx - h, p.dy)
        ..close();
      canvas.drawPath(pedra, Paint()..color = Cor.fundo);
      canvas.drawPath(pedra, Paint()..color = (i.isEven ? claro : cor));
      canvas.drawPath(
        pedra,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Cor.fundo.withValues(alpha: 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_Emblema old) =>
      old.cor != cor || old.quebrado != quebrado || old.claro != claro;
}

/// Faíscas: na vitória um estouro no impacto e brasas douradas subindo sem parar; na derrota cinzas caindo
/// devagar; no remake só umas poucas subindo.
class _Faiscas extends CustomPainter {
  _Faiscas({
    required this.sempre,
    required this.entrada,
    required this.tom,
    required this.resultado,
  }) : super(repaint: Listenable.merge([sempre, entrada]));
  final Animation<double> sempre;
  final Animation<double> entrada;
  final _Tom tom;
  final String resultado;

  static final _estouro = _sortear(28, 3);
  static final _brasas = _sortear(34, 11);

  static List<List<double>> _sortear(int n, int semente) {
    final r = math.Random(semente);
    return [
      for (var i = 0; i < n; i++)
        [r.nextDouble(), r.nextDouble(), r.nextDouble(), r.nextDouble()],
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final vitoria = resultado == 'vitoria';
    final derrota = resultado == 'derrota';
    final ponto = Paint();
    final centro = Offset(
      size.width / 2,
      size.height * (size.width > size.height ? 0.5 : 0.36),
    );

    // estouro: sai do centro no impacto do título (30% da entrada), desacelera e apaga
    if (vitoria) {
      final s = (entrada.value - 0.28) * _entradaMs / 1000;
      if (s > 0 && s < 2.2) {
        final alcance = size.shortestSide * 0.62;
        for (final p in _estouro) {
          final a = p[0] * math.pi * 2;
          final v = 0.45 + p[1] * 0.55;
          final ida = 1 - math.pow(1 - (s / 2.2), 3).toDouble();
          final pos =
              centro +
              Offset(math.cos(a), math.sin(a)) * alcance * v * ida +
              Offset(0, -40 * s * s * p[2]);
          final vida = (1 - s / (1.2 + p[3])).clamp(0.0, 1.0);
          final raio = 1.2 + p[2] * 2.2;
          ponto.color = tom.brilho.withValues(alpha: 0.22 * vida);
          canvas.drawCircle(pos, raio * 3, ponto);
          ponto.color = tom.claro.withValues(alpha: vida);
          canvas.drawCircle(pos, raio, ponto);
        }
      }
    }

    // brasas que não param (aparecem depois do impacto)
    final aparece = ((entrada.value - 0.3) / 0.4).clamp(0.0, 1.0);
    if (aparece <= 0) return;
    final tempo = sempre.value * _cicloS;
    final quantas = derrota ? 26 : (vitoria ? _brasas.length : 12);
    for (var i = 0; i < quantas; i++) {
      final p = _brasas[i];
      final periodo =
          _cicloS /
          (3 + (p[1] * 4).floor()); // divide o ciclo: sem pulo na volta
      final fase = ((tempo / periodo) + p[2]) % 1.0;
      final balanco = math.sin((fase * 2 + p[3]) * math.pi) * 18 * (0.4 + p[0]);
      final x = p[0] * size.width + balanco;
      final y = derrota
          ? -10 +
                fase *
                    (size.height + 20) // cinza caindo
          : size.height + 10 - fase * (size.height * (0.6 + p[3] * 0.5));
      // aparece e some nas pontas do caminho
      final borda = math.sin(fase * math.pi);
      final alfa = borda * aparece * (derrota ? 0.45 : 0.85);
      final raio = derrota ? 1 + p[3] * 1.6 : 0.8 + p[3] * 1.8;
      final cor = derrota
          ? (i % 3 == 0 ? tom.cor : Cor.apagado)
          : (i % 4 == 0 ? tom.claro : tom.cor);
      if (!derrota) {
        ponto.color = cor.withValues(alpha: alfa * 0.2);
        canvas.drawCircle(Offset(x, y), raio * 3, ponto);
      }
      ponto.color = cor.withValues(alpha: alfa);
      canvas.drawCircle(Offset(x, y), raio, ponto);
    }
  }

  @override
  bool shouldRepaint(_Faiscas old) =>
      old.resultado != resultado || old.tom != tom;
}
