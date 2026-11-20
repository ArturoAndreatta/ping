part of 'main.dart';

/// Nome de cada etapa da abertura do LoL que o PC acompanha (processos e a API do client respondendo).
String _nomeEtapa(Txt t, String? etapa) => switch (etapa) {
  'riot' => t.aberturaRiot,
  'league' => t.aberturaLeague,
  'ux' => t.aberturaUx,
  'pronto' => t.aberturaPronto,
  _ => t.aberturaTitulo,
};

/// Onde a abertura está agora, calculado com as etapas que o PC mandou (`abertura` no estado): cada etapa tem
/// o tempo que costuma levar neste PC e a hora em que aconteceu, quando já aconteceu.
class _Progresso {
  _Progresso(Map ab, int agora) {
    final etapas = ((ab['etapas'] as List?) ?? const [])
        .whereType<List>()
        .where((e) => e.length == 2 && e[1] is num)
        .toList();
    final feitas = (ab['feitas'] as Map?) ?? const {};
    chave = etapas.where((e) => feitas[e[0]] is num).map((e) => e[0]).join(',');
    final total = etapas.fold<num>(0, (s, e) => s + (e[1] as num));
    var anterior = (ab['inicio'] as num?)?.toInt() ?? agora;
    var acumulado = 0.0;
    for (var i = 0; i < etapas.length; i++) {
      final nome = etapas[i][0] as String;
      final espera = (etapas[i][1] as num).toDouble();
      final quando = feitas[nome];
      if (quando is num) {
        acumulado += espera;
        anterior = quando.toInt();
        continue;
      }
      // etapa em andamento (fracao: onde a barra começa quando o app abre no meio da abertura)
      final x = math.max(0, agora - anterior) / espera;
      final f = x <= 1 ? 0.9 * x : 0.9 + 0.09 * (1 - math.exp(-(x - 1) * 1.2));
      fracao = total > 0 ? (acumulado + espera * f) / total : 0;
      etapa = nome;
      // Riot Client aberto do zero e a etapa do LoL demorando: quase sempre é ele esperando o login
      login = nome == 'league' && x > 1.5 && etapas.any((e) => e[0] == 'riot');
      final depois = etapas
          .skip(i + 1)
          .fold<num>(0, (s, e) => s + (e[1] as num));
      falta = math.max(0, espera - (agora - anterior)) + depois;
      // pra barra recomeçar a conta ao entrar nesta etapa: ela inteira mais as que vêm depois
      resta = espera + depois;
      return;
    }
    fracao = 1;
  }

  double fracao = 0;
  String chave = '';
  num resta = 0;
  String etapa = 'pronto';
  bool login = false;
  num falta = 0;
}

/// Abertura que passou disso já não vale (PC que caiu no meio, dado velho): fica só o losango.
const _aberturaVence = 200000;

/// "Abrindo o LoL" com barra de carregamento. Sem as etapas (PC com versão antiga ou o LoL já estava
/// abrindo quando você tocou), fica só o losango pulsando. [abriu]: o LoL acabou de abrir e a barra
/// completa até 100% antes da tela seguinte.
class _Abrindo extends StatelessWidget {
  const _Abrindo({required this.con, this.abriu});
  final Conexao con;
  final Map? abriu;

  @override
  Widget build(BuildContext context) {
    final ab = abriu ?? con.estado['abertura'];
    final inicio = ab is Map ? ab['inicio'] : null;
    if (ab is! Map ||
        inicio is! num ||
        con.agora.millisecondsSinceEpoch - inicio > _aberturaVence) {
      return _Mensagem(
        icone: _Pulso(),
        titulo: context.txt.aberturaTitulo,
        texto: context.txt.aberturaLogin,
      );
    }
    // a cada segundo: a etapa demorando muito (login no Riot Client) troca o texto sem o PC mandar nada
    return Relogio(
      builder: (_) {
        final p = _Progresso(ab, con.agora.millisecondsSinceEpoch);
        return _Mensagem(
          icone: const _Pulso(),
          titulo: context.txt.aberturaTitulo,
          texto: abriu != null
              ? context.txt.aberturaPronto2
              : p.login
              ? context.txt.aberturaLogin
              : _nomeEtapa(context.txt, p.etapa),
          extra: _BarraAbertura(con: con, ab: ab, completo: abriu != null),
        );
      },
    );
  }
}

class _BarraAbertura extends StatefulWidget {
  const _BarraAbertura({
    required this.con,
    required this.ab,
    this.completo = false,
  });
  final Conexao con;
  final Map ab;
  final bool completo;

  @override
  State<_BarraAbertura> createState() => _BarraAberturaState();
}

class _BarraAberturaState extends State<_BarraAbertura>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _valor = ValueNotifier<double>(
    0,
  ); // o que a barra mostra: só anda pra frente, deslizando
  final _brilho = ValueNotifier<double>(0);
  late _Progresso _p;
  Duration _ultimo = Duration.zero;
  // A barra nunca pula: quando uma etapa chega (antes ou depois do esperado), ela recomeça a conta de onde
  // está, com o tempo que ainda falta. Etapa adiantada só deixa a barra mais rápida, atrasada mais lenta.
  double _base = 0; // onde a barra estava no último recomeço
  int _baseEm = 0; // quando foi (hora do servidor)
  num _resta = 1; // ms esperados dali até abrir
  String _chave = '';
  int _falta = 0;
  int _pct = 0;

  @override
  void initState() {
    super.initState();
    final agora = widget.con.agora.millisecondsSinceEpoch;
    _p = _Progresso(widget.ab, agora);
    _chave = _p.chave;
    if (_p.chave.isEmpty) {
      // nenhuma etapa ainda: conta do toque, com o tempo total esperado
      _base = 0;
      _baseEm = (widget.ab['inicio'] as num?)?.toInt() ?? agora;
      _resta = math.max(1, _p.falta + (agora - _baseEm));
    } else {
      // app aberto no meio da abertura: começa onde as etapas dizem e segue com o que falta
      _base = (_p.fracao * 0.99).clamp(0.0, 0.95);
      _baseEm = agora;
      _resta = math.max(500, _p.falta);
    }
    _valor.value = _calcular(agora);
    _pct = (_valor.value * 100).floor();
    _falta = _faltaEm(agora);
    _ticker = createTicker(_quadro)..start();
  }

  // lido fora do quadro: MediaQuery dentro do Ticker consultava o contexto 60 vezes por segundo
  bool _semMov = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _semMov = MediaQuery.disableAnimationsOf(context);
  }

  /// Do recomeço até o tempo esperado anda reto até 95% do que faltava; passou do tempo, continua
  /// chegando perto do fim bem devagar, sem parar e sem chegar lá.
  double _calcular(int agora) {
    final u = math.max(0, agora - _baseEm) / _resta;
    final f = u <= 1 ? 0.95 * u : 0.95 + 0.04 * (1 - math.exp(-(u - 1) * 1.5));
    return _base + (0.99 - _base) * f;
  }

  void _quadro(Duration t) {
    final dt = (t - _ultimo).inMicroseconds / 1e6;
    _ultimo = t;
    final agora = widget.con.agora.millisecondsSinceEpoch;
    _p = _Progresso(widget.ab, agora);
    if (_p.chave != _chave) {
      _chave = _p.chave;
      _base = _valor.value;
      _baseEm = agora;
      _resta = math.max(500, _p.resta);
    }
    if (widget.completo) {
      // abriu: fecha os 100% deslizando
      _valor.value += (1 - _valor.value) * (1 - math.exp(-dt / 0.2));
    } else {
      _valor.value = math.max(_valor.value, _calcular(agora));
    }
    if (!_semMov) {
      _brilho.value = (t.inMilliseconds % 1800) / 1800;
    }
    // 99,5% já conta como 100: a aproximação nunca chega exatamente lá
    final pct = math.min(100, (_valor.value * 100 + 0.5).floor());
    final falta = widget.completo ? _faltaAberto : _faltaEm(agora);
    if (pct != _pct || falta != _falta) {
      setState(() {
        _pct = pct;
        _falta = falta;
      });
    }
  }

  /// O que falta pela conta da barra (a mesma que ela anda), arredondado pra não ficar pulando.
  /// Em segundos; `_faltaLogin`, `0` (quase lá) e `_faltaAberto` são os casos sem número.
  static const _faltaLogin = -1;
  static const _faltaAberto = -2;

  int _faltaEm(int agora) {
    if (_p.login) return _faltaLogin;
    final s = ((_resta - (agora - _baseEm)) / 1000).ceil();
    if (s <= 0) return 0;
    if (s <= 10) return s;
    return (s / 5).ceil() * 5;
  }

  String _textoFalta(Txt t) => switch (_falta) {
    _faltaLogin => t.aberturaEsperandoLogin,
    _faltaAberto => t.aberturaAberto,
    0 => t.aberturaQuaseLa,
    _ => t.aberturaFaltam(_falta),
  };

  @override
  void dispose() {
    _ticker.dispose();
    _valor.dispose();
    _brilho.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final numeros = const TextStyle(
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _dur(context, 420),
      curve: Curves.easeOutCubic,
      builder: (_, t, filho) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: filho,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: SizedBox(
              height: 6,
              width: double.infinity,
              child: CustomPaint(painter: _PintaBarra(_valor, _brilho)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$_pct%',
                style: fonteTitulo(16, cor: Cor.ouroClaro).merge(numeros),
              ),
              const Spacer(),
              Text(
                _textoFalta(context.txt),
                style: TextStyle(
                  color: Cor.apagado,
                  fontSize: 14,
                ).merge(numeros),
              ),
            ],
          ),
          if (widget.ab['estimado'] == true) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.txt.aberturaEstimado,
                style: TextStyle(color: Cor.apagado, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Trilho escuro, preenchimento dourado e um brilho correndo por dentro dele (o carregamento do client).
class _PintaBarra extends CustomPainter {
  _PintaBarra(this.valor, this.brilho)
    : super(repaint: Listenable.merge([valor, brilho]));
  final ValueNotifier<double> valor;
  final ValueNotifier<double> brilho;

  @override
  void paint(Canvas canvas, Size size) {
    final trilho = Offset.zero & size;
    canvas.drawRect(trilho, Paint()..color = Cor.linha);
    final w = size.width * valor.value.clamp(0.0, 1.0);
    if (w <= 0) return;
    final cheio = Rect.fromLTWH(0, 0, w, size.height);
    canvas.drawRect(
      cheio,
      Paint()
        ..shader = LinearGradient(
          colors: [Cor.ouroEscuro, Cor.ouro],
        ).createShader(cheio),
    );
    // brilho de 60px atravessando o preenchimento
    final x = -60 + (w + 60) * brilho.value;
    final luz = Rect.fromLTWH(x, 0, 60, size.height);
    canvas.save();
    canvas.clipRect(cheio);
    canvas.drawRect(
      luz,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Cor.ouroClaro.withValues(alpha: 0),
            Cor.ouroClaro.withValues(alpha: 0.55),
            Cor.ouroClaro.withValues(alpha: 0),
          ],
        ).createShader(luz),
    );
    canvas.restore();
    // ponta acesa, onde o carregamento está agora
    canvas.drawRect(
      Rect.fromLTWH(math.max(0, w - 2), 0, 2, size.height),
      Paint()..color = Cor.ouroClaro,
    );
  }

  @override
  bool shouldRepaint(_PintaBarra old) => false;
}
