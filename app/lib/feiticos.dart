part of 'main.dart';

/// Feitiços que valem no modo (o PC manda uma vez por seleção) e o seu par atual.
List<Map> _listaFeiticos(Conexao con) =>
    ((con.estado['feiticos'] as List?) ?? const []).whereType<Map>().toList();

List<int> _meusFeiticos(Map sel) => [
  for (final f in (sel['feiticos'] as List?) ?? const [0, 0])
    (f as num?)?.toInt() ?? 0,
];

/// Golpear só aparece pra quem está na selva. Sem posição (blind, treino, personalizada) vale pra todos, e o
/// que já está no seu par fica (dá pra trocar de lado).
const _golpear = 11;

bool _feiticoPermitido(Map sel, int id, List<int> par) {
  if (id != _golpear || par.contains(id)) return true;
  final pos = '${sel['minha_pos'] ?? ''}'.toLowerCase();
  return pos.isEmpty || pos == 'jungle';
}

bool _temFeiticos(Conexao con, Map sel) =>
    _listaFeiticos(con).isNotEmpty &&
    ((sel['feiticos'] as List?) ?? const []).length == 2;

String _iconeFeitico(Conexao con, int id) {
  final f = _listaFeiticos(con).where((f) => f['id'] == id).firstOrNull;
  final c = '${f?['icone'] ?? ''}';
  return c.isEmpty ? '' : _arte(c, 0);
}

Widget _imgFeitico(Conexao con, int id, double lado) {
  final url = id > 0 ? _iconeFeitico(con, id) : '';
  return SizedBox(
    width: lado,
    height: lado,
    child: url.isEmpty
        ? ColoredBox(color: Cor.painel2)
        : Image.network(
            url,
            key: ValueKey(id),
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            errorBuilder: (_, _, _) => ColoredBox(color: Cor.painel2),
          ),
  );
}

/// Botões dos feitiços na seleção: um quadrado pra cada (D e F), como no rodapé do client. Tocar abre a folha
/// já no lado tocado.
class _BotaoFeiticos extends StatelessWidget {
  const _BotaoFeiticos({required this.con, required this.sel});
  final Conexao con;
  final Map sel;

  @override
  Widget build(BuildContext context) {
    final par = _meusFeiticos(sel);
    Widget quad(int slot) => Semantics(
      button: true,
      label: slot == 0 ? 'Feitiço D' : 'Feitiço F',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _abrirFeiticos(context, con, slot: slot),
        child: Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: Raio.r1,
            color: Cor.painel2,
            border: Border.all(color: Cor.linha2),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: Raio.r1,
              border: Border.all(color: Cor.ouroEscuro),
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedSwitcher(
              duration: _dur(context, 220),
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.0).animate(a),
                  child: c,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(par[slot]),
                child: _imgFeitico(con, par[slot], 38),
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [quad(0), const SizedBox(width: 6), quad(1)],
    );
  }
}

Future<void> _abrirFeiticos(
  BuildContext context,
  Conexao con, {
  int slot = 0,
}) async {
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
          final s = con.estado['selecao'];
          if (s is! Map || con.fase != 'ChampSelect' || !_temFeiticos(con, s)) {
            // a seleção acabou com a folha aberta: fecha sozinha
            if (!fechou) {
              fechou = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => Navigator.of(ctx).maybePop(),
              );
            }
            return const SizedBox.shrink();
          }
          return _FolhaFeiticos(con: con, sel: s, slot: slot);
        },
      ),
    ),
  );
  som.tocar('fechar');
}

/// Folha dos feitiços: escolhe o lado (D ou F) e toca no feitiço. Escolher o que está no outro lado inverte os
/// dois, como no client. Depois do D, o F fica marcado.
class _FolhaFeiticos extends StatefulWidget {
  const _FolhaFeiticos({required this.con, required this.sel, this.slot = 0});
  final Conexao con;
  final Map sel;

  /// Lado que abre marcado (o quadrado tocado).
  final int slot;

  @override
  State<_FolhaFeiticos> createState() => _FolhaFeiticosState();
}

class _FolhaFeiticosState extends State<_FolhaFeiticos> {
  late int _slot = widget.slot;

  void _escolher(int id) {
    final par = _meusFeiticos(widget.sel);
    if (par[_slot] == id) return;
    som.tocar('runa');
    widget.con.enviar('feitico', {'slot': _slot, 'feitico': id}, 'feitico');
    if (_slot == 0) setState(() => _slot = 1);
  }

  @override
  Widget build(BuildContext context) {
    final con = widget.con;
    final par = _meusFeiticos(widget.sel);
    final lista = _listaFeiticos(con);
    final grade = [
      for (final f in lista)
        if (_feiticoPermitido(widget.sel, (f['id'] as num).toInt(), par)) f,
    ];
    final enviando = con.esperando('feitico');

    Widget lado(int i) {
      final ativo = _slot == i;
      final nome =
          '${lista.where((f) => f['id'] == par[i]).firstOrNull?['nome'] ?? ''}';
      return Expanded(
        child: _Tocavel(
          rotulo: 'Feitiço ${i == 0 ? 'D' : 'F'}',
          aoTocar: () {
            som.tocar('clique');
            setState(() => _slot = i);
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
                  decoration: BoxDecoration(
                    borderRadius: Raio.r1,
                    border: Border.all(color: Cor.ouroEscuro),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AnimatedSwitcher(
                    duration: _dur(context, 220),
                    child: KeyedSubtree(
                      key: ValueKey(par[i]),
                      child: _imgFeitico(con, par[i], 36),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i == 0 ? 'D' : 'F',
                        style: fonteTitulo(
                          11,
                          cor: ativo ? Cor.ouro : Cor.apagado,
                        ),
                      ),
                      Text(
                        nome.isEmpty ? 'Escolher' : nome,
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
              Text('FEITIÇOS', style: fonteTitulo(14)),
              const Spacer(),
              AnimatedOpacity(
                opacity: enviando ? 1 : 0,
                duration: _dur(context, 180),
                child: Losango(cor: Cor.ouro, tamanho: 7, pulsar: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [lado(0), const SizedBox(width: 8), lado(1)]),
          const SizedBox(height: 14),
          RepaintBoundary(
            child: Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final f in grade)
                  _ItemFeitico(
                    con: con,
                    id: (f['id'] as num).toInt(),
                    nome: '${f['nome'] ?? ''}',
                    usado: par.contains(f['id']),
                    noLado: par[_slot] == f['id'],
                    aoTocar: () => _escolher((f['id'] as num).toInt()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemFeitico extends StatelessWidget {
  const _ItemFeitico({
    required this.con,
    required this.id,
    required this.nome,
    required this.usado,
    required this.noLado,
    required this.aoTocar,
  });
  final Conexao con;
  final int id;
  final String nome;
  final bool usado;
  final bool noLado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 64,
    child: _Tocavel(
      rotulo: nome,
      afundar: 0.92,
      aoTocar: aoTocar,
      child: Column(
        children: [
          AnimatedContainer(
            duration: _dur(context, 200),
            curve: curvaSaida,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: Raio.r1,
              border: Border.all(
                color: noLado
                    ? Cor.ouro
                    : (usado ? Cor.ouroEscuro : Colors.transparent),
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
            child: _imgFeitico(con, id, 44),
          ),
          const SizedBox(height: 4),
          Text(
            nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: usado ? Cor.ouroClaro : Cor.apagado,
            ),
          ),
        ],
      ),
    ),
  );
}
