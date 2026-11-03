part of 'main.dart';

/// Ordem do seletor de posição da sala no client.
const _ordemPosicoes = ['TOP', 'JUNGLE', 'MIDDLE', 'BOTTOM', 'UTILITY', 'FILL'];

/// Ícone dourado da posição (o mesmo do seletor do client), chave em caixa alta da sala.
Widget _imgPosicao(String pos, double lado, {Color? cor}) => Image(
  image: _fontePosicao(pos.toLowerCase()),
  width: lado,
  height: lado,
  color: cor,
  colorBlendMode: cor == null ? null : BlendMode.srcIn,
  filterQuality: FilterQuality.medium,
  errorBuilder: (_, _, _) => SizedBox(width: lado, height: lado),
);

/// Suas duas posições na sala (primeira e segunda). Vazio = ainda não escolheu.
List<String> _minhasPosicoes(Map sala) {
  final l = (sala['minhas_pos'] as List?) ?? const [];
  return [for (var i = 0; i < 2; i++) i < l.length ? '${l[i] ?? ''}' : ''];
}

/// O que dá pra pôr na segunda posição (o PC confere com as regras do client).
List<String> _opcoesSegunda(Map sala) {
  final o = sala['segunda_opcoes'];
  // lista gravada no Firebase pode voltar como mapa {0: ..}
  final l = o is Map ? o.values : (o is List ? o : const []);
  return [
    for (final p in _ordemPosicoes)
      if (l.contains(p)) p,
  ];
}

bool _salaComPosicao(Conexao con) {
  final s = con.estado['sala'];
  return s is Map && s['posicoes'] == true && con.fase == 'Lobby';
}

Future<void> _abrirPosicao(BuildContext context, Conexao con) async {
  // os ícones baixam enquanto a folha sobe (sem esperar)
  for (final p in _ordemPosicoes) {
    precacheImage(_fontePosicao(p.toLowerCase()), context);
  }
  som.tocar('abrir');
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
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + con.nav.areaSegura().base),
      child: ListenableBuilder(
        listenable: con,
        builder: (ctx, _) {
          if (!_salaComPosicao(con)) {
            // saiu da sala (ou a fila começou) com a folha aberta: fecha sozinha
            if (!fechou) {
              fechou = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => Navigator.of(ctx).maybePop(),
              );
            }
            return const SizedBox.shrink();
          }
          return _FolhaPosicao(con: con, sala: con.estado['sala'] as Map);
        },
      ),
    ),
  );
  som.tocar('fechar');
}

/// Folha da posição na sala: escolhe o lado (primeira ou segunda) e toca na posição, como o seletor do
/// client. Escolher a que está no outro lado troca as duas. Depois da primeira, a segunda fica marcada.
class _FolhaPosicao extends StatefulWidget {
  const _FolhaPosicao({required this.con, required this.sala});
  final Conexao con;
  final Map sala;

  @override
  State<_FolhaPosicao> createState() => _FolhaPosicaoState();
}

class _FolhaPosicaoState extends State<_FolhaPosicao> {
  // abre na que falta: primeira escolhida e segunda vazia começa na segunda
  late int _papel =
      _minhasPosicoes(widget.sala)[0].isNotEmpty &&
          _minhasPosicoes(widget.sala)[1].isEmpty &&
          widget.sala['segunda_ok'] == true
      ? 1
      : 0;

  void _escolher(String pos) {
    final atuais = _minhasPosicoes(widget.sala);
    if (atuais[_papel] == pos) return;
    som.tocar('runa');
    widget.con.enviar('posicao', {'papel': _papel, 'pos': pos}, 'posicao');
    // Qualquer na primeira não tem segunda (o client esconde)
    if (_papel == 0 && pos != 'FILL') setState(() => _papel = 1);
  }

  @override
  Widget build(BuildContext context) {
    final con = widget.con;
    final atuais = _minhasPosicoes(widget.sala);
    final segundaOk = widget.sala['segunda_ok'] == true;
    // sem segunda (Qualquer na primeira, time cheio): volta pra primeira
    final papel = segundaOk ? _papel : 0;
    final opcoes = papel == 0 ? _ordemPosicoes : _opcoesSegunda(widget.sala);
    final enviando = con.esperando('posicao');

    Widget lado(int i) {
      final ativo = papel == i;
      final pos = atuais[i];
      return Expanded(
        child: _Tocavel(
          rotulo: i == 0 ? 'Primeira posição' : 'Segunda posição',
          aoTocar: () {
            som.tocar('clique');
            setState(() => _papel = i);
          },
          child: AnimatedContainer(
            duration: _dur(context, 200),
            curve: curvaSaida,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: Raio.r1,
              color: ativo ? Cor.ouro.withValues(alpha: 0.1) : Cor.painel2,
              border: Border.all(
                color: ativo ? Cor.ouro : Cor.linha2,
                width: ativo ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Cor.fundo,
                    border: Border.all(color: Cor.ouroEscuro),
                  ),
                  child: AnimatedSwitcher(
                    duration: _dur(context, 220),
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.7, end: 1.0).animate(a),
                        child: c,
                      ),
                    ),
                    child: pos.isEmpty
                        ? Losango(
                            key: ValueKey(''),
                            cor: Cor.ouroEscuro,
                            tamanho: 8,
                          )
                        : KeyedSubtree(
                            key: ValueKey(pos),
                            child: _imgPosicao(pos, 22),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i == 0 ? 'PRIMEIRA' : 'SEGUNDA',
                        style: fonteTitulo(
                          11,
                          cor: ativo ? Cor.ouro : Cor.apagado,
                        ),
                      ),
                      Text(
                        pos.isEmpty ? 'Escolher' : (_posicoes[pos] ?? pos),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ativo ? Cor.ouroClaro : Cor.texto,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Cor.painel,
        borderRadius: Raio.r2,
        border: Border.all(color: Cor.linha2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('SUA POSIÇÃO', style: fonteTitulo(14)),
              const Spacer(),
              AnimatedOpacity(
                opacity: enviando ? 1 : 0,
                duration: _dur(context, 180),
                child: Losango(cor: Cor.ouro, tamanho: 7, pulsar: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // a segunda some com Qualquer na primeira ou time cheio, como no client
          AnimatedSwitcher(
            duration: _dur(context, 220),
            child: Row(
              key: ValueKey(segundaOk),
              children: [
                lado(0),
                if (segundaOk) ...[const SizedBox(width: 8), lado(1)],
              ],
            ),
          ),
          const SizedBox(height: 14),
          RepaintBoundary(
            child: Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in opcoes)
                  _ItemPosicao(
                    key: ValueKey(p),
                    pos: p,
                    usado: atuais.contains(p),
                    noLado: atuais[papel] == p,
                    aoTocar: () => _escolher(p),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemPosicao extends StatelessWidget {
  const _ItemPosicao({
    super.key,
    required this.pos,
    required this.usado,
    required this.noLado,
    required this.aoTocar,
  });
  final String pos;
  final bool usado;
  final bool noLado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 74,
    child: _Tocavel(
      rotulo: _posicoes[pos] ?? pos,
      afundar: 0.92,
      aoTocar: aoTocar,
      child: Column(
        children: [
          AnimatedContainer(
            duration: _dur(context, 200),
            curve: curvaSaida,
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: noLado ? Cor.ouro.withValues(alpha: 0.12) : Cor.painel2,
              border: Border.all(
                color: noLado
                    ? Cor.ouro
                    : (usado ? Cor.ouroEscuro : Cor.linha2),
                width: noLado ? 2 : 1,
              ),
              boxShadow: noLado
                  ? [
                      BoxShadow(
                        color: Cor.ouro.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: _imgPosicao(pos, 28),
          ),
          const SizedBox(height: 5),
          Text(
            _posicoes[pos] ?? pos,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: usado ? Cor.ouroClaro : Cor.apagado,
            ),
          ),
        ],
      ),
    ),
  );
}
