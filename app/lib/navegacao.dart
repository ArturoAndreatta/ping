part of 'main.dart';

/// Abas do app. Ao vivo é o app de sempre (segue a fase do LoL); as outras são o que o painel do PC tem.
enum Aba {
  aoVivo('Ao vivo', Icons.sensors_rounded),
  hoje('Hoje', Icons.query_stats_rounded),
  mais('Mais', Icons.more_horiz_rounded);

  const Aba(this.nome, this.icone);
  final String nome;
  final IconData icone;
}

/// Fases em que o que acontece no LoL pede o celular na aba Ao vivo.
const _fasesAoVivo = {
  'Matchmaking',
  'ReadyCheck',
  'ChampSelect',
  'GameStart',
  'InProgress',
  'Reconnect',
};

/// Selo no ícone da aba: algo pede atenção lá (cor) e se pulsa.
({Color cor, bool pulsar})? _seloDa(Aba aba, Conexao con) {
  if (!con.pcOnline || con.estado.isEmpty) return null;
  switch (aba) {
    case Aba.aoVivo:
      if (_fasesAoVivo.contains(con.fase)) return (cor: Cor.teal, pulsar: true);
      if (con.fase == 'Lobby') return (cor: Cor.ouro, pulsar: false);
      return null;
    case Aba.mais:
    case Aba.hoje:
      return null;
  }
}

// ---------------- barra ----------------

/// Abas com a cara do client: fio dourado que desliza até a aba (estica com a velocidade, como se fosse
/// puxado), luz saindo dele e o ícone acendendo. Em pé é a barra de baixo; deitado vira abas no meio do
/// topo (um trilho na lateral comia a largura junto com o recuo do notch). Tudo anda por uma mola só
/// ([_pos]) pintada numa camada própria.
class _BarraAbas extends StatefulWidget {
  const _BarraAbas({
    super.key,
    required this.atual,
    required this.aoTrocar,
    required this.con,
    required this.seg,
    required this.abas,
    this.noTopo = false,
  });
  final Aba atual;

  /// Abas na ordem da barra.
  final List<Aba> abas;
  final ValueChanged<Aba> aoTrocar;
  final Conexao con;
  final ({double topo, double base, double esq, double dir}) seg;

  /// Deitado: abas no topo, sem fundo próprio, com o fio embaixo da aba.
  final bool noTopo;

  // perto da barra nativa do iPhone (49): 62 mais a área segura inteira ficava com 96 no iPhone 13
  static const altura = 52.0;

  /// Abas no topo (deitado): altura e largura de cada uma.
  static const alturaTopo = 40.0;
  static const larguraTopo = 92.0;

  /// A barrinha do iPhone (home indicator) fica nos últimos ~13px da área segura: a barra entra nela
  /// em vez de empilhar os 34px inteiros embaixo.
  static double baseDe(double base) => base > 0 ? math.max(8, base - 16) : 0;

  @override
  State<_BarraAbas> createState() => _BarraAbasState();
}

class _BarraAbasState extends State<_BarraAbas>
    with SingleTickerProviderStateMixin {
  late final _pos = AnimationController.unbounded(
    vsync: this,
    value: _lugar(widget).toDouble(),
  );

  /// Posição da aba atual na barra.
  static int _lugar(_BarraAbas w) => math.max(0, w.abas.indexOf(w.atual));

  // mola um pouco viva: passa de leve e assenta (crítico seria ~39 de amortecimento)
  static const _mola = SpringDescription(mass: 1, stiffness: 420, damping: 34);

  @override
  void didUpdateWidget(_BarraAbas antigo) {
    super.didUpdateWidget(antigo);
    final alvo = _lugar(widget).toDouble();
    if (_lugar(antigo) == alvo && antigo.abas.length == widget.abas.length) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _pos.value = alvo;
      return;
    }
    // parte da velocidade de agora: tocar outra aba no meio do caminho não dá tranco
    _pos.animateWith(SpringSimulation(_mola, _pos.value, alvo, _pos.velocity));
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topo = widget.noTopo;
    final itens = [
      for (final (i, a) in widget.abas.indexed)
        Expanded(
          child: _ItemAba(
            aba: a,
            indice: i,
            pos: _pos,
            noTopo: topo,
            selo: _seloDa(a, widget.con),
            aoTocar: () => widget.aoTrocar(a),
            ativa: a == widget.atual,
          ),
        ),
    ];
    final pintura = CustomPaint(
      painter: _FioPintor(_pos, widget.abas.length, noTopo: topo),
      child: topo
          ? SizedBox(
              width: _BarraAbas.larguraTopo * itens.length,
              height: _BarraAbas.alturaTopo,
              child: Row(children: itens),
            )
          : Padding(
              padding: const EdgeInsets.only(bottom: 4),
              // ícone e nome no meio da barra inteira (com a faixa da barrinha do iPhone): só 4px de
              // respiro embaixo, que a barrinha fica abaixo do nome
              child: SizedBox(
                height:
                    _BarraAbas.altura + _BarraAbas.baseDe(widget.seg.base) - 4,
                child: Row(children: itens),
              ),
            ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Abas',
      child: RepaintBoundary(
        child: topo
            ? pintura
            // a pintura cobre também a área da barrinha do iPhone (a luz desce até a borda)
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Cor.painel.withValues(alpha: 0.94), Cor.fundo],
                  ),
                  boxShadow: [BoxShadow(color: Cor.sombra, blurRadius: 24)],
                ),
                child: pintura,
              ),
      ),
    );
  }
}

/// Fio da borda, a luz da aba e o fio dourado com o losango no meio. Embaixo da tela tudo sai da borda de
/// cima da barra; no topo, da borda de baixo das abas (subindo).
class _FioPintor extends CustomPainter {
  _FioPintor(this.pos, this.n, {required this.noTopo}) : super(repaint: pos);
  final AnimationController pos;
  final int n;
  final bool noTopo;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / n;
    final c = (pos.value + 0.5) * slot;
    // linha de onde tudo sai: em cima da barra de baixo, embaixo das abas do topo
    final y = noTopo ? size.height : 0.0;

    if (!noTopo) {
      // fio fino da borda, sumindo nas pontas
      final borda = Rect.fromLTWH(0, 0, size.width, 1);
      canvas.drawRect(
        borda,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Cor.linha2.withValues(alpha: 0.0),
              Cor.linha2,
              Cor.ouroEscuro.withValues(alpha: 0.4),
              Cor.linha2,
              Cor.linha2.withValues(alpha: 0.0),
            ],
          ).createShader(borda),
      );
    }

    // luz da aba ativa: elipse que vai do fio até o outro lado (na barra de baixo, até a área da
    // barrinha do iPhone), achatada com escala no canvas pra a largura não seguir a altura
    final largo = slot * (noTopo ? 0.5 : 0.6); // meia largura da luz
    final fundo = size.height * 1.05; // até onde ela chega
    canvas
      ..save()
      ..translate(c, y)
      ..scale(1, (noTopo ? -1 : 1) * fundo / largo);
    canvas.drawRect(
      Rect.fromLTWH(-largo, 0, largo * 2, largo),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Cor.ouro.withValues(alpha: 0.18),
            Cor.ouro.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: largo)),
    );
    canvas.restore();

    // fio dourado: estica com a velocidade e volta quando assenta
    final estica = (pos.velocity.abs() * (noTopo ? 7 : 9)).clamp(
      0.0,
      noTopo ? 26.0 : 34.0,
    );
    final meio = (noTopo ? 14 : 17) + estica;
    final fio = Rect.fromLTWH(c - meio, noTopo ? y - 2 : 0, meio * 2, 2);
    canvas.drawRect(
      fio.inflate(1.5),
      Paint()
        ..color = Cor.ouro.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRect(
      fio,
      Paint()
        ..shader = LinearGradient(
          colors: [Cor.ouroEscuro, Cor.ouroClaro, Cor.ouroEscuro],
        ).createShader(fio),
    );

    // losango preso no meio do fio
    canvas
      ..save()
      ..translate(c, noTopo ? y - 1 : 1)
      ..rotate(math.pi / 4);
    canvas.drawRect(
      const Rect.fromLTWH(-3, -3, 6, 6),
      Paint()..color = Cor.ouroClaro,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FioPintor old) =>
      old.pos != pos || old.n != n || old.noTopo != noTopo;
}

class _ItemAba extends StatefulWidget {
  const _ItemAba({
    required this.aba,
    required this.indice,
    required this.pos,
    required this.noTopo,
    required this.selo,
    required this.aoTocar,
    required this.ativa,
  });
  final Aba aba;

  /// Lugar na barra.
  final int indice;
  final Animation<double> pos;
  final bool noTopo;
  final ({Color cor, bool pulsar})? selo;
  final VoidCallback aoTocar;
  final bool ativa;

  @override
  State<_ItemAba> createState() => _ItemAbaState();
}

class _ItemAbaState extends State<_ItemAba> {
  bool _apertado = false;

  void _apertar(bool v) {
    if (v != _apertado) setState(() => _apertado = v);
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.indice;
    final selo = widget.selo;
    final topo = widget.noTopo;
    return Semantics(
      button: true,
      selected: widget.ativa,
      label: widget.aba.nome,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _apertar(true),
        onTapCancel: () => _apertar(false),
        onTapUp: (_) => _apertar(false),
        onTap: () {
          if (!widget.ativa) som.tocar('clique');
          widget.aoTocar();
        },
        child: ExcludeSemantics(
          child: AnimatedScale(
            scale: _apertado ? 0.9 : 1,
            duration: _dur(context, 140),
            curve: curvaSaida,
            child: AnimatedBuilder(
              animation: widget.pos,
              builder: (context, _) {
                // 1 na aba ativa, 0 longe dela: cor, subida e escala acompanham a mola
                final t = (1 - (widget.pos.value - i).abs()).clamp(0.0, 1.0);
                final corIcone = Color.lerp(Cor.apagado, Cor.ouroClaro, t)!;
                final corNome = Color.lerp(Cor.apagado, Cor.ouro, t)!;
                final icone = Transform.translate(
                  offset: Offset(0, topo ? 0 : -2.5 * t),
                  child: Transform.scale(
                    scale: 1 + 0.1 * t,
                    child: SizedBox(
                      width: topo ? 26 : 34,
                      height: topo ? 22 : 24,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            widget.aba.icone,
                            size: topo ? 19 : 22,
                            color: corIcone,
                          ),
                          Positioned(
                            right: topo ? -2 : 1,
                            top: topo ? -1 : 1,
                            child: AnimatedSwitcher(
                              duration: _dur(context, 220),
                              transitionBuilder: (c, a) =>
                                  ScaleTransition(scale: a, child: c),
                              child: selo == null
                                  ? const SizedBox.shrink()
                                  : Losango(
                                      key: ValueKey(selo.cor),
                                      cor: selo.cor,
                                      tamanho: 7,
                                      pulsar: selo.pulsar,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                final nome = Text(
                  widget.aba.nome.toUpperCase(),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: topo ? 11 : 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: topo ? 1.4 : 1.3,
                    color: corNome,
                  ),
                );
                // no topo ícone e nome lado a lado (a altura é pouca); embaixo, um em cima do outro
                return topo
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [icone, const SizedBox(width: 6), nome],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [icone, const SizedBox(height: 2), nome],
                      );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A barra de baixo entra deslizando e, quando sai (seleção, tela de carregamento, fim de partida),
/// desliza pra fora por cima do conteúdo, sem roubar altura dele no meio da animação.
class _BarraAnimada extends StatelessWidget {
  const _BarraAnimada({required this.barra});
  final Widget? barra;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: _dur(context, 340),
    switchInCurve: curvaSaida,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (c, a) => SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(a),
      child: c,
    ),
    layoutBuilder: (atual, antes) => Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        for (final b in antes)
          Positioned(left: 0, right: 0, bottom: 0, child: b),
        ?atual,
      ],
    ),
    child:
        barra ??
        const SizedBox(
          key: ValueKey('sem-barra'),
          width: double.infinity,
          height: 0,
        ),
  );
}

/// Troca de aba: a nova entra do lado da aba tocada e a velha sai pro outro, as duas em fade cruzado
/// (a velha some na primeira metade, a nova aparece na segunda: nunca as duas cheias ao mesmo tempo).
class _TrocaAbas extends StatelessWidget {
  const _TrocaAbas({
    required this.aba,
    required this.direcao,
    required this.child,
  });
  final Aba aba;

  /// 1 = foi pra uma aba à direita, -1 = pra trás.
  final int direcao;
  final Widget child;

  static final _entra = CurveTween(
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );
  static final _sai = CurveTween(curve: const Interval(0.5, 1));

  @override
  Widget build(BuildContext context) {
    // deitado a tela é larga: o passo é menor pra andar a mesma distância
    final passo = _deitado(context) ? 0.035 : 0.06;
    return AnimatedSwitcher(
      duration: _dur(context, 300),
      switchInCurve: curvaSaida,
      switchOutCurve: Curves.easeIn,
      // o AnimatedSwitcher refaz a transição de quem está saindo quando este builder muda (é uma função
      // nova a cada build): a velha sai pro lado certo mesmo tendo entrado pelo outro
      transitionBuilder: (c, a) {
        final entrando = c.key == ValueKey(aba);
        return FadeTransition(
          opacity: a.drive(entrando ? _entra : _sai),
          child: SlideTransition(
            position: a.drive(
              Tween(
                begin: Offset((entrando ? direcao : -direcao) * passo, 0),
                end: Offset.zero,
              ),
            ),
            child: RepaintBoundary(child: c),
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(aba), child: child),
    );
  }
}

/// Desenha as abas de [abas] por baixo do app, cobertas pelo fundo, sem toque nem leitor de tela. Elas
/// rodam a entrada inteira uma vez: o navegador otimiza o código, o CanvasKit monta os shaders e as letras
/// e os ícones baixam. Sai sozinho quando [abas] volta a ser null.
class _ComAquecimento extends StatelessWidget {
  const _ComAquecimento({
    required this.abas,
    required this.aba,
    required this.child,
  });
  final List<Aba>? abas;
  final Widget Function(Aba) aba;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lista = abas;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (lista != null)
          for (final a in lista)
            Positioned.fill(
              key: ValueKey('aquecer-$a'),
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: ExcludeFocus(child: RepaintBoundary(child: aba(a))),
                ),
              ),
            ),
        // o fundo cobre o que está aquecendo (mesma cor do Scaffold)
        if (lista != null) ColoredBox(color: Cor.fundo),
        KeyedSubtree(key: const ValueKey('app'), child: child),
      ],
    );
  }
}
// ---------------- aba Hoje ----------------

const _diasSemana = [
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
  'Domingo',
];
const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// Dia do resumo: vira às 5h, como no PC (partida de madrugada conta pro dia anterior).
String _diaDoResumo() {
  final d = DateTime.now().subtract(const Duration(hours: 5));
  return '${_diasSemana[d.weekday - 1]}, ${d.day} de ${_meses[d.month - 1]}';
}

/// Tempo jogando: "45" minutos ou "2:01" horas (o título em Cinzel só tem maiúscula, "2h01" virava "2H01").
(String, String) _tempoJogando(int minutos) => minutos < 60
    ? ('$minutos', 'Minutos')
    : (
        '${minutos ~/ 60}:${(minutos % 60).toString().padLeft(2, '0')}',
        'Horas',
      );

class _AbaHoje extends StatelessWidget {
  const _AbaHoje({required this.con, this.base = 0});
  final Conexao con;
  final double base;

  @override
  Widget build(BuildContext context) {
    final h = con.estado['hoje'];
    final r = h is Map ? h['resumo'] : null;
    final jogos = h is Map ? ((h['jogos'] as List?) ?? const []) : const [];
    final nomes = h is Map ? h['nomes'] : null;
    final deitado = _deitado(context);
    if (r is! Map) {
      return _Rolavel(
        base: base,
        largura: 440,
        child: _Mensagem(
          icone: const Icone(Icons.query_stats_rounded),
          titulo: 'Nenhuma partida hoje',
          texto: jogos.isEmpty
              ? 'Jogue uma partida e o resumo do dia aparece aqui.'
              : 'Só remakes até agora.',
        ),
      );
    }
    final resumo = _ResumoHoje(r: r);
    final lista = _PartidasHoje(
      jogos: jogos.whereType<Map>().toList(),
      nomes: nomes,
    );
    return _Rolavel(
      base: base,
      largura: deitado ? 900 : 520,
      child: deitado
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: resumo),
                const SizedBox(width: 14),
                Expanded(child: lista),
              ],
            )
          : Column(children: [resumo, const SizedBox(height: 14), lista]),
    );
  }
}

/// Rolagem das abas: largura de leitura no meio e um respiro no fim (o último cartão não cola na barra).
class _Rolavel extends StatelessWidget {
  const _Rolavel({required this.child, this.largura = 520, this.base = 0});
  final Widget child;
  final double largura;

  /// Área segura de baixo (deitado, sem barra embaixo): o conteúdo rola por baixo da barrinha do iPhone
  /// em vez de ser cortado numa faixa preta.
  final double base;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + base),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largura),
        child: child,
      ),
    ),
  );
}

class _ResumoHoje extends StatelessWidget {
  const _ResumoHoje({required this.r});
  final Map r;

  @override
  Widget build(BuildContext context) {
    final n = (r['partidas'] as num?)?.toInt() ?? 0;
    final v = (r['vitorias'] as num?)?.toInt() ?? 0;
    final d = (r['derrotas'] as num?)?.toInt() ?? 0;
    final wr = n > 0 ? (100 * v / n).round() : 0;
    final kda = (r['kda'] as num?)?.toDouble() ?? 0;
    final mvp = r['mvp'];
    final tempo = _tempoJogando((r['minutos'] as num?)?.toInt() ?? 0);
    return _Entrada(
      chave: 'resumo-hoje',
      child: Cartao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HOJE', style: fonteTitulo(14)),
            const SizedBox(height: 2),
            Text(
              _diaDoResumo(),
              style: TextStyle(color: Cor.apagado, fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // número sobe contando ao abrir a aba
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: wr.toDouble()),
                  duration: _dur(context, 900),
                  curve: curvaSaida,
                  builder: (_, x, _) => Text(
                    '${x.round()}%',
                    style: fonteTitulo(44, cor: Cor.ouroClaro),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'WINRATE',
                    style: TextStyle(
                      color: Cor.apagado.withValues(alpha: 0.9),
                      fontSize: 12,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${v}V',
                          style: TextStyle(color: Cor.vitoria),
                        ),
                        const TextSpan(text: '  '),
                        TextSpan(
                          text: '${d}D',
                          style: TextStyle(color: Cor.derrota),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _BarraVD(v: v, d: d),
            const SizedBox(height: 20),
            Row(
              children: [
                _Numero(rotulo: 'Partidas', valor: '$n'),
                _Numero(rotulo: 'KDA', valor: kda.toStringAsFixed(2)),
                _Numero(rotulo: tempo.$2, valor: tempo.$1),
              ],
            ),
            if (mvp is Map) ...[
              const SizedBox(height: 20),
              Container(height: 1, color: Cor.linha),
              const SizedBox(height: 16),
              _Mvp(mvp: mvp),
            ],
          ],
        ),
      ),
    );
  }
}

/// Vitórias e derrotas numa barra só: enche da esquerda ao abrir (escala, sem refazer o layout).
class _BarraVD extends StatelessWidget {
  const _BarraVD({required this.v, required this.d});
  final int v;
  final int d;

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, v + d);
    return ClipRRect(
      borderRadius: Raio.r1,
      child: SizedBox(
        height: 6,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: _dur(context, 900),
          curve: curvaSaida,
          builder: (_, t, c) => Transform.scale(
            scaleX: t,
            alignment: Alignment.centerLeft,
            child: c,
          ),
          child: Row(
            children: [
              if (v > 0)
                Expanded(
                  flex: v * 1000 ~/ total,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(Cor.vitoria, Colors.black, .38)!,
                          Cor.vitoria,
                        ],
                      ),
                    ),
                  ),
                ),
              if (v > 0 && d > 0) const SizedBox(width: 2),
              if (d > 0)
                Expanded(
                  flex: d * 1000 ~/ total,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Cor.derrota,
                          Color.lerp(Cor.derrota, Colors.black, .4)!,
                        ],
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
}

class _Numero extends StatelessWidget {
  const _Numero({required this.rotulo, required this.valor});
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(valor, style: fonteTitulo(20, cor: Cor.ouroClaro)),
        const SizedBox(height: 2),
        Text(
          rotulo.toUpperCase(),
          style: TextStyle(
            color: Cor.apagado,
            fontSize: 11,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _Mvp extends StatelessWidget {
  const _Mvp({required this.mvp});
  final Map mvp;

  @override
  Widget build(BuildContext context) {
    final id = (mvp['id'] as num?)?.toInt() ?? 0;
    final n = (mvp['partidas'] as num?)?.toInt() ?? 0;
    final v = (mvp['vitorias'] as num?)?.toInt() ?? 0;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: Cor.ouro),
            boxShadow: [
              BoxShadow(color: Cor.ouro.withValues(alpha: 0.3), blurRadius: 14),
            ],
          ),
          child: id > 0
              ? Image.network(
                  _iconeCampeao(id),
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(color: Cor.painel2),
                )
              : ColoredBox(color: Cor.painel2),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MVP DO DIA',
                style: TextStyle(
                  color: Cor.ouro,
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${mvp['nome'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Cor.ouroClaro,
                ),
              ),
              Text(
                '$v de $n ${v == 1 ? 'vitória' : 'vitórias'}',
                style: TextStyle(color: Cor.apagado, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PartidasHoje extends StatelessWidget {
  const _PartidasHoje({required this.jogos, required this.nomes});
  final List<Map> jogos;
  final Object? nomes;

  @override
  Widget build(BuildContext context) => _Entrada(
    chave: 'partidas-hoje',
    atraso: 80,
    child: Cartao(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PARTIDAS', style: fonteTitulo(14)),
          const SizedBox(height: 12),
          for (final (i, j) in jogos.indexed)
            _Entrada(
              key: ValueKey('jogo-${j['quando']}'),
              chave: 'jogo-${j['quando']}',
              // em cascata, com teto: lista longa não fica esperando
              atraso: 120 + math.min(i, 8) * 45,
              child: _LinhaPartida(j: j, nomes: nomes),
            ),
        ],
      ),
    ),
  );
}

class _LinhaPartida extends StatelessWidget {
  const _LinhaPartida({required this.j, required this.nomes});
  final Map j;
  final Object? nomes;

  @override
  Widget build(BuildContext context) {
    final id = (j['campeao'] as num?)?.toInt() ?? 0;
    final remake = j['remake'] == true;
    final venceu = j['vitoria'] == true;
    final cor = remake ? Cor.apagado : (venceu ? Cor.vitoria : Cor.derrota);
    final quando = DateTime.fromMillisecondsSinceEpoch(
      (j['quando'] as num?)?.toInt() ?? 0,
    );
    final hora =
        '${quando.hour.toString().padLeft(2, '0')}:${quando.minute.toString().padLeft(2, '0')}';
    final nome = _nomeCampeao(nomes, id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 3, height: 40, color: cor),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            height: 40,
            child: id > 0
                ? Image.network(
                    _iconeCampeao(id),
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    // remake fica cinza pela própria imagem, sem camada de filtro
                    color: remake ? Cor.fundo.withValues(alpha: 0.6) : null,
                    colorBlendMode: remake ? BlendMode.srcATop : null,
                    errorBuilder: (_, _, _) => ColoredBox(color: Cor.painel2),
                  )
                : ColoredBox(color: Cor.painel2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remake ? 'Remake' : (venceu ? 'Vitória' : 'Derrota'),
                  style: TextStyle(
                    color: cor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  nome.isEmpty ? hora : '$nome · $hora',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Cor.apagado, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${j['k']} / ${j['d']} / ${j['a']}',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Cor.texto,
                ),
              ),
              Text(
                '${j['cs']} CS · ${_mmss((j['duracao'] as num?)?.toInt() ?? 0)}',
                style: TextStyle(color: Cor.apagado, fontSize: 12.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------- aba Mais ----------------

class _AbaMais extends StatefulWidget {
  const _AbaMais({required this.con, this.base = 0});
  final Conexao con;
  final double base;

  @override
  State<_AbaMais> createState() => _AbaMaisState();
}

class _AbaMaisState extends State<_AbaMais> {
  /// Avisos no celular aberto por cima da lista.
  bool _avisos = false;

  /// Tema aberto por cima da lista.
  bool _temas = false;
  int _rodada = -1;

  @override
  void initState() {
    super.initState();
    _pelaVitrine();
  }

  @override
  void didUpdateWidget(_AbaMais antigo) {
    super.didUpdateWidget(antigo);
    _pelaVitrine();
  }

  /// Vitrine: as telas `avisos` e `temas` abrem a página; as outras voltam pra lista.
  void _pelaVitrine() {
    final c = widget.con;
    if (c is! ConexaoVitrine || c.rodada == _rodada) return;
    _rodada = c.rodada;
    _avisos = c.tela == 'avisos';
    _temas = c.tela == 'temas';
  }

  void _abrirAvisos(bool v) => setState(() => _avisos = v);
  void _abrirTemas(bool v) => setState(() => _temas = v);

  @override
  Widget build(BuildContext context) {
    // lista e página deslizam uma sobre a outra (entra pela direita, volta pela esquerda)
    return AnimatedSwitcher(
      duration: _dur(context, 300),
      switchInCurve: curvaSaida,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (c, a) {
        final ePagina =
            c.key == const ValueKey('mais-avisos') ||
            c.key == const ValueKey('mais-temas');
        final lado =
            (ePagina ? 1.0 : -1.0) * (_deitado(context) ? 0.035 : 0.06);
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: a.drive(Tween(begin: Offset(lado, 0), end: Offset.zero)),
            child: RepaintBoundary(child: c),
          ),
        );
      },
      child: _temas
          ? _PaginaTemas(
              key: const ValueKey('mais-temas'),
              base: widget.base,
              aoVoltar: () => _abrirTemas(false),
            )
          : _avisos
          ? _PaginaAvisos(
              key: const ValueKey('mais-avisos'),
              con: widget.con,
              base: widget.base,
              aoVoltar: () => _abrirAvisos(false),
            )
          : KeyedSubtree(
              key: const ValueKey('mais-lista'),
              child: _lista(context),
            ),
    );
  }

  Widget _lista(BuildContext context) {
    final con = widget.con;
    final deitado = _deitado(context);
    Widget seta() =>
        Icon(Icons.chevron_right_rounded, color: Cor.apagado, size: 24);
    final cartaoCelular = _Entrada(
      chave: 'mais-celular',
      atraso: 60,
      child: _Grupo(
        titulo: 'Este celular',
        children: [
          ListenableBuilder(
            listenable: Avisos.eu(con),
            builder: (_, _) {
              final av = Avisos.eu(con);
              return _LinhaMais(
                icone: av.ativo
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_rounded,
                titulo: 'Avisos',
                texto: av.ativo
                    ? 'Chegam mesmo com o app fechado.'
                    : 'Partida encontrada, sua vez e mais, no celular.',
                final_: seta(),
                aoTocar: () => _abrirAvisos(true),
              );
            },
          ),
          ListenableBuilder(
            listenable: Temas.mudou,
            builder: (_, _) => _LinhaMais(
              icone: Icons.palette_outlined,
              titulo: 'Tema',
              texto:
                  '${Temas.atual.nome}, ${Temas.claro.value ? 'claro' : 'escuro'}',
              final_: seta(),
              aoTocar: () => _abrirTemas(true),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: som.mudo,
            builder: (_, mudo, _) => _LinhaMais(
              icone: mudo ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              titulo: 'Sons',
              texto: 'Os sons do client quando algo acontece.',
              final_: _Alavanca(
                ligado: !mudo,
                aoMudar: (_) => som.alternarMudo(),
              ),
            ),
          ),
        ],
      ),
    );
    final cartaoConta = _Entrada(
      chave: 'mais-conta',
      atraso: 45,
      child: _GrupoConta(con: con),
    );
    // deitado: a conta à esquerda, este celular à direita
    return _Rolavel(
      base: widget.base,
      largura: deitado ? 900 : 520,
      child: deitado
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cartaoConta),
                const SizedBox(width: 14),
                Expanded(child: cartaoCelular),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cartaoConta,
                const SizedBox(height: 14),
                cartaoCelular,
              ],
            ),
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.children});
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Cartao(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo.toUpperCase(), style: fonteTitulo(13)),
        const SizedBox(height: 6),
        for (final (i, c) in children.indexed) ...[
          if (i > 0) Container(height: 1, color: Cor.linha),
          c,
        ],
      ],
    ),
  );
}

class _LinhaMais extends StatefulWidget {
  const _LinhaMais({
    super.key,
    required this.icone,
    required this.titulo,
    required this.texto,
    required this.final_,
    this.aoTocar,
  });
  final IconData icone;
  final String titulo;
  final String texto;
  final Widget final_;
  final VoidCallback? aoTocar;

  @override
  State<_LinhaMais> createState() => _LinhaMaisState();
}

class _LinhaMaisState extends State<_LinhaMais> {
  bool _apertado = false;

  void _apertar(bool v) {
    if (widget.aoTocar != null && v != _apertado) {
      setState(() => _apertado = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conteudo = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: _dur(context, 220),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                scale: Tween(begin: 0.7, end: 1.0).animate(a),
                child: c,
              ),
            ),
            child: Icon(
              widget.icone,
              key: ValueKey(widget.icone),
              color: Cor.ouro,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Cor.ouroClaro,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: _dur(context, 200),
                  layoutBuilder: (atual, antes) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...antes, ?atual],
                  ),
                  child: Text(
                    widget.texto,
                    key: ValueKey(widget.texto),
                    style: TextStyle(
                      color: Cor.apagado,
                      fontSize: 13.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          widget.final_,
        ],
      ),
    );
    if (widget.aoTocar == null) return conteudo;
    return Semantics(
      button: true,
      label: widget.titulo,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _apertar(true),
        onTapCancel: () => _apertar(false),
        onTapUp: (_) => _apertar(false),
        onTap: () {
          som.tocar('clique');
          widget.aoTocar!();
        },
        child: AnimatedScale(
          scale: _apertado ? 0.98 : 1,
          duration: _dur(context, 120),
          curve: curvaSaida,
          child: conteudo,
        ),
      ),
    );
  }
}

/// Liga e desliga com a cara do client: trilho com fio dourado e um losango que corre de um lado pro outro.
class _Alavanca extends StatelessWidget {
  const _Alavanca({
    required this.ligado,
    required this.aoMudar,
    this.carregando = false,
    this.ativo = true,
  });
  final bool ligado;
  final ValueChanged<bool> aoMudar;

  /// Esperando o PC: o losango gira no lugar e não aceita outro toque.
  final bool carregando;
  final bool ativo;

  @override
  Widget build(BuildContext context) {
    final pode = ativo && !carregando;
    return Semantics(
      toggled: ligado,
      enabled: pode,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: pode
            ? () {
                som.tocar(ligado ? 'clique' : 'ouro');
                aoMudar(!ligado);
              }
            : null,
        child: Padding(
          // alvo de toque maior que o desenho
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: ligado ? 1 : 0),
            duration: _dur(context, 260),
            curve: curvaSaida,
            builder: (_, t, _) => AnimatedOpacity(
              opacity: ativo ? 1 : 0.4,
              duration: _dur(context, 200),
              child: Container(
                width: 48,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: Raio.r1,
                  border: Border.all(
                    color: Color.lerp(Cor.linha2, Cor.ouro, t)!,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(Cor.painel2, Cor.marcadoForte, t)!,
                      Color.lerp(Cor.fundo, Cor.marcadoFundo, t)!,
                    ],
                  ),
                  boxShadow: t > 0
                      ? [
                          BoxShadow(
                            color: Cor.ouro.withValues(alpha: 0.22 * t),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Align(
                  alignment: Alignment(t * 2 - 1, 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: carregando
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: Cor.ouro,
                            ),
                          )
                        : Transform.rotate(
                            angle: math.pi / 4 + t * math.pi,
                            child: Container(
                              width: 10,
                              height: 10,
                              color: Color.lerp(Cor.apagado, Cor.ouroClaro, t),
                            ),
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

/// Botão de voltar das páginas que abrem por cima da lista da aba Mais, com o título da página.
class _Voltar extends StatefulWidget {
  const _Voltar({required this.aoTocar, required this.titulo});
  final VoidCallback aoTocar;
  final String titulo;

  @override
  State<_Voltar> createState() => _VoltarState();
}

class _VoltarState extends State<_Voltar> {
  bool _apertado = false;

  void _apertar(bool v) {
    if (v != _apertado) setState(() => _apertado = v);
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Semantics(
        button: true,
        label: 'Voltar',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _apertar(true),
          onTapCancel: () => _apertar(false),
          onTapUp: (_) => _apertar(false),
          onTap: () {
            som.tocar('clique');
            widget.aoTocar();
          },
          child: AnimatedScale(
            scale: _apertado ? 0.9 : 1,
            duration: _dur(context, 120),
            curve: curvaSaida,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: Raio.r1,
                border: Border.all(color: Cor.linha2),
                color: Cor.painel2,
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                color: Cor.ouro,
                size: 24,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 14),
      Text(
        widget.titulo.toUpperCase(),
        style: fonteTitulo(16, cor: Cor.ouroClaro),
      ),
    ],
  );
}
