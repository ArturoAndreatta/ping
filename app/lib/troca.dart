part of 'main.dart';

/// Trocas com aliado, como no client: campeão (`troca`), posição (`pos`) e ordem de pick (`ordem`). Cada uma
/// vem numa lista da seleção (`trocas`, `trocas_pos`, `trocas_ordem`) e no aliado (`troca`, `troca_pos`,
/// `troca_ordem`), e os comandos são `<tipo>_pedir`, `_aceitar`, `_recusar` e `_cancelar`.
const _tiposTroca = ['troca', 'pos', 'ordem'];

String _listaTroca(String tipo) => tipo == 'troca' ? 'trocas' : 'trocas_$tipo';
String _chaveTroca(String tipo) => tipo == 'troca' ? 'troca' : 'troca_$tipo';

/// Troca com aliado em andamento (só uma por vez, de qualquer tipo): a que pediram pra você vem antes da que
/// você pediu.
({String tipo, Map troca})? _trocaPendente(Map sel) {
  for (final estado in const ['RECEIVED', 'SENT']) {
    for (final tipo in _tiposTroca) {
      final t = ((sel[_listaTroca(tipo)] as List?) ?? const [])
          .whereType<Map>()
          .where((t) => t['estado'] == estado)
          .firstOrNull;
      if (t != null) return (tipo: tipo, troca: t);
    }
  }
  return null;
}

/// Estado do selo do aliado juntando os três tipos: pediu pra você, você pediu, dá pra pedir ([livre]: tocar
/// pede mesmo; com outra troca no meio as setas enganariam).
String _seloDe(Map m, {required bool livre}) {
  final estados = [for (final t in _tiposTroca) '${m[_chaveTroca(t)] ?? ''}'];
  for (final e in ['RECEIVED', 'SENT', if (livre) 'AVAILABLE']) {
    if (estados.contains(e)) return e;
  }
  return '';
}

Map? _aliado(Map sel, Object? cell) => ((sel['meu'] as List?) ?? const [])
    .whereType<Map>()
    .where((m) => m['cell'] == cell)
    .firstOrNull;

Map? _euNaSelecao(Map sel) => ((sel['meu'] as List?) ?? const [])
    .whereType<Map>()
    .where((m) => m['eu'] == true)
    .firstOrNull;

String _ordinal(Object? n) => n is num && n > 0 ? '${n.toInt()}º' : '';

/// O que muda pra você em cada tipo de troca com esse aliado (vazio quando não dá pra saber).
String _ganhoTroca(String tipo, Map sel, Map aliado) => switch (tipo) {
  'pos' => _posSelecao['${aliado['pos'] ?? ''}'] ?? '',
  'ordem' => _ordinal(aliado['ordem']),
  _ => _nomeCampeao(sel['nomes'], (aliado['campeao'] as num?)?.toInt() ?? 0),
};

/// Tipos que dá pra pedir com esse aliado agora (o PC já tirou os que a tela do client não deixa).
List<String> _trocasDisponiveis(Map m) => [
  for (final t in _tiposTroca)
    if (m[_chaveTroca(t)] == 'AVAILABLE') t,
];

/// Tocar no aliado pede a troca, como o botão de troca do client. Com mais de um tipo disponível (campeão,
/// posição, ordem) abre a escolha, como a janelinha do client. Nenhuma com outra em andamento.
VoidCallback? _pedirTroca(BuildContext context, Conexao? con, Map sel, Map m) {
  final tipos = _trocasDisponiveis(m);
  if (con == null || tipos.isEmpty || _trocaPendente(sel) != null) {
    return null;
  }
  if (tipos.length == 1) {
    return () => _enviarPedido(con, tipos.first, m['cell']);
  }
  return () => _abrirEscolhaTroca(context, con, m['cell']);
}

void _enviarPedido(Conexao con, String tipo, Object? cell) {
  som.tocar('troca');
  con.enviar('${tipo}_pedir', {'cell': cell as num}, 'troca-$cell');
}

/// Folha "Trocar com fulano": campeão, posição ou ordem de pick. Fecha sozinha se a troca deixar de valer.
Future<void> _abrirEscolhaTroca(
  BuildContext context,
  Conexao con,
  Object? cell,
) async {
  som.tocar('abrir');
  var fechou = false;
  final escolhido = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Cor.veu,
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
        listenable: Filtro(con, () => [con.fase, con.estado['selecao']]),
        builder: (ctx, _) {
          final s = con.estado['selecao'];
          final m = s is Map ? _aliado(s, cell) : null;
          if (s is! Map ||
              m == null ||
              con.fase != 'ChampSelect' ||
              _trocasDisponiveis(m).isEmpty ||
              _trocaPendente(s) != null) {
            // a seleção acabou ou a troca deixou de valer com a folha aberta: fecha sozinha
            if (!fechou) {
              fechou = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => Navigator.of(ctx).maybePop(),
              );
            }
            return const SizedBox.shrink();
          }
          return _FolhaEscolhaTroca(sel: s, aliado: m);
        },
      ),
    ),
  );
  if (escolhido != null) {
    _enviarPedido(con, escolhido, cell);
  } else {
    som.tocar('fechar');
  }
}

class _FolhaEscolhaTroca extends StatelessWidget {
  const _FolhaEscolhaTroca({required this.sel, required this.aliado});
  final Map sel;
  final Map aliado;

  @override
  Widget build(BuildContext context) {
    final nome = '${aliado['nome'] ?? ''}'.isEmpty
        ? 'o aliado'
        : '${aliado['nome']}';
    final tipos = _trocasDisponiveis(aliado);
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
          Text(
            'TROCAR COM ${nome.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: fonteTitulo(14),
          ),
          const SizedBox(height: 4),
          Text(
            'Ele precisa aceitar.',
            style: TextStyle(color: Cor.apagado, fontSize: 13),
          ),
          const SizedBox(height: 14),
          for (final (i, t) in tipos.indexed)
            _Entrada(
              key: ValueKey('escolha-$t'),
              chave: 'escolha-$t',
              atraso: i * 50,
              child: Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                child: _OpcaoTroca(tipo: t, sel: sel, aliado: aliado),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpcaoTroca extends StatelessWidget {
  const _OpcaoTroca({
    required this.tipo,
    required this.sel,
    required this.aliado,
  });
  final String tipo;
  final Map sel;
  final Map aliado;

  @override
  Widget build(BuildContext context) {
    final ganho = _ganhoTroca(tipo, sel, aliado);
    final (titulo, detalhe) = switch (tipo) {
      'pos' => (
        'Posição',
        ganho.isEmpty ? 'Vocês trocam de posição' : 'Você vai pra $ganho',
      ),
      'ordem' => (
        'Ordem de pick',
        ganho.isEmpty
            ? 'Vocês trocam a vez de escolher'
            : 'Você escolhe em $ganho',
      ),
      _ => (
        'Campeão',
        ganho.isEmpty ? 'Vocês trocam de campeão' : 'Você fica com $ganho',
      ),
    };
    return _Tocavel(
      rotulo: '$titulo: $detalhe',
      aoTocar: () => Navigator.of(context).pop(tipo),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: Raio.r1,
          color: Cor.painel2,
          border: Border.all(color: Cor.linha2),
        ),
        child: Row(
          children: [
            _SimboloTroca(tipo: tipo, m: aliado, tamanho: 40, destaque: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo.toUpperCase(), style: fonteTitulo(12)),
                  const SizedBox(height: 2),
                  Text(
                    detalhe,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Cor.texto, fontSize: 13.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.swap_horiz_rounded, color: Cor.ouro, size: 20),
          ],
        ),
      ),
    );
  }
}

/// O que se troca, desenhado: retrato do campeão, ícone da posição ou o lugar na ordem de pick.
class _SimboloTroca extends StatelessWidget {
  const _SimboloTroca({
    required this.tipo,
    required this.m,
    required this.tamanho,
    this.destaque = false,
    this.fraco = false,
  });
  final String tipo;
  final Map? m;
  final double tamanho;
  final bool destaque;
  final bool fraco;

  @override
  Widget build(BuildContext context) {
    if (tipo == 'troca') {
      return _IconeCamp(
        id: (m?['campeao'] as num?)?.toInt() ?? 0,
        tamanho: tamanho,
        destaque: destaque,
        fraco: fraco,
      );
    }
    final pos = '${m?['pos'] ?? ''}';
    final Widget miolo = tipo == 'pos' && _posSelecao.containsKey(pos)
        ? Image(
            image: _fontePosicao(pos),
            width: tamanho * 0.62,
            height: tamanho * 0.62,
            filterQuality: FilterQuality.medium,
            opacity: AlwaysStoppedAnimation(fraco ? 0.55 : 1),
          )
        : Text(
            tipo == 'ordem' ? _ordinal(m?['ordem']) : '?',
            style: fonteTitulo(
              tamanho * 0.36,
              cor: fraco ? Cor.apagado : Cor.ouroClaro,
            ),
          );
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: Raio.r1,
        color: fraco ? Cor.fundo : Cor.painel2,
        border: Border.all(
          color: destaque ? Cor.ouro : Cor.linha2,
          width: destaque ? 1.5 : 1,
        ),
      ),
      child: miolo,
    );
  }
}

/// Aviso no topo da seleção quando tem troca no meio: pediram pra você (Aceitar e Recusar) ou você pediu
/// (esperando, com Cancelar). Entra deslizando e some do mesmo jeito.
class _AvisoTroca extends StatelessWidget {
  const _AvisoTroca({required this.con, required this.sel, this.espaco = 10});
  final Conexao con;
  final Map sel;

  /// Respiro acima do aviso (só quando ele aparece).
  final double espaco;

  @override
  Widget build(BuildContext context) {
    final p = _trocaPendente(sel);
    final m = p == null ? null : _aliado(sel, p.troca['cell']);
    final filho = p == null || m == null
        ? const SizedBox(key: ValueKey('sem-troca'), width: double.infinity)
        : Padding(
            key: ValueKey(
              'troca-${p.tipo}-${p.troca['estado']}-${p.troca['cell']}',
            ),
            padding: EdgeInsets.only(top: espaco),
            child: _CartaoTroca(
              con: con,
              sel: sel,
              tipo: p.tipo,
              troca: p.troca,
              aliado: m,
            ),
          );
    // abre e fecha encolhendo junto com o fade (sem buraco vazio enquanto some)
    return AnimatedSwitcher(
      duration: _dur(context, 300),
      reverseDuration: _dur(context, 220),
      switchInCurve: curvaSaida,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (c, a) => SizeTransition(
        sizeFactor: a,
        axisAlignment: -1,
        child: FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.08),
              end: Offset.zero,
            ).animate(a),
            // o cartão numa camada própria: o fade e o deslize não redesenham ele a cada quadro
            child: RepaintBoundary(child: c),
          ),
        ),
      ),
      layoutBuilder: (atual, antigos) =>
          Stack(alignment: Alignment.topCenter, children: [...antigos, ?atual]),
      child: filho,
    );
  }
}

class _CartaoTroca extends StatelessWidget {
  const _CartaoTroca({
    required this.con,
    required this.sel,
    required this.tipo,
    required this.troca,
    required this.aliado,
  });
  final Conexao con;
  final Map sel;
  final String tipo;
  final Map troca;
  final Map aliado;

  @override
  Widget build(BuildContext context) {
    final recebida = troca['estado'] == 'RECEIVED';
    final id = (troca['id'] as num).toInt();
    final cell = (troca['cell'] as num).toInt();
    final nome = '${aliado['nome'] ?? ''}'.isEmpty
        ? 'Um aliado'
        : '${aliado['nome']}';
    final ganho = _ganhoTroca(tipo, sel, aliado);
    final (titulo, quer, fica) = switch (tipo) {
      'pos' => (
        recebida ? 'TROCA DE POSIÇÃO' : 'POSIÇÃO PEDIDA',
        'quer trocar de posição com você',
        ganho.isEmpty ? '' : 'você vai pra $ganho',
      ),
      'ordem' => (
        recebida ? 'TROCA DE ORDEM' : 'ORDEM PEDIDA',
        'quer trocar a ordem de pick com você',
        ganho.isEmpty ? '' : 'você escolhe em $ganho',
      ),
      _ => (
        recebida ? 'PEDIDO DE TROCA' : 'TROCA PEDIDA',
        'quer trocar com você',
        ganho.isEmpty ? '' : 'você fica com $ganho',
      ),
    };
    final texto = recebida
        ? '$nome $quer${fica.isEmpty ? '' : ': $fica'}.'
        : 'Esperando $nome aceitar${fica.isEmpty ? '' : ': $fica'}.';
    final dados = {'id': id, 'cell': cell};
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: Raio.r2,
        color: Cor.painel,
        border: Border.all(color: recebida ? Cor.ouro : Cor.linha2),
        boxShadow: recebida
            ? [
                BoxShadow(
                  color: Cor.ouro.withValues(alpha: 0.22),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SimboloTroca(tipo: tipo, m: aliado, tamanho: 44, destaque: true),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: Cor.ouro,
                  size: 20,
                ),
              ),
              _SimboloTroca(
                tipo: tipo,
                m: _euNaSelecao(sel),
                tamanho: 34,
                fraco: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Losango(
                          cor: recebida ? Cor.ouro : Cor.teal,
                          tamanho: 7,
                          pulsar: true,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: fonteTitulo(12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      texto,
                      style: TextStyle(
                        color: Cor.texto,
                        fontSize: 13.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recebida)
            Row(
              children: [
                Expanded(
                  child: Botao(
                    texto: 'Recusar',
                    compacto: true,
                    carregando: con.esperando('${tipo}_recusar'),
                    aoTocar: () => con.enviar('${tipo}_recusar', dados),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Botao(
                    texto: 'Aceitar',
                    principal: true,
                    compacto: true,
                    carregando: con.esperando('${tipo}_aceitar'),
                    aoTocar: () => con.enviar('${tipo}_aceitar', dados),
                  ),
                ),
              ],
            )
          else
            Botao(
              texto: 'Cancelar pedido',
              compacto: true,
              carregando: con.esperando('${tipo}_cancelar'),
              aoTocar: () => con.enviar('${tipo}_cancelar', dados),
            ),
        ],
      ),
    );
  }
}

/// Marca no aliado: dá pra pedir troca (setas), você pediu (losango pulsando) ou ele pediu (setas acesas).
class _SeloTroca extends StatelessWidget {
  const _SeloTroca({required this.estado, this.enviando = false});
  final String estado;
  final bool enviando;

  /// Lado do selo: fica no canto do retrato, sem tirar largura do nome.
  static const lado = 22.0;

  @override
  Widget build(BuildContext context) {
    final Widget filho;
    if (enviando || estado == 'SENT') {
      filho = Container(
        key: const ValueKey('enviado'),
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          borderRadius: Raio.r1,
          color: Cor.fundo,
          border: Border.all(color: Cor.teal.withValues(alpha: 0.6)),
        ),
        child: Center(child: Losango(cor: Cor.teal, tamanho: 7, pulsar: true)),
      );
    } else if (estado == 'AVAILABLE' || estado == 'RECEIVED') {
      final aceso = estado == 'RECEIVED';
      filho = Container(
        key: ValueKey(estado),
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          borderRadius: Raio.r1,
          // fundo cheio: em cima do retrato não pode deixar a arte vazar
          color: aceso ? Cor.marcado : Cor.painel2,
          border: Border.all(color: aceso ? Cor.ouro : Cor.ouroEscuro),
        ),
        child: Icon(
          Icons.swap_horiz_rounded,
          size: 15,
          color: aceso ? Cor.ouroClaro : Cor.ouro,
        ),
      );
    } else {
      filho = const SizedBox.shrink(key: ValueKey('nada'));
    }
    return AnimatedSwitcher(
      duration: _dur(context, 220),
      switchInCurve: curvaSaida,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.6, end: 1.0).animate(a),
          child: c,
        ),
      ),
      child: filho,
    );
  }
}

/// Toque com o afundar do botão (aliado pra pedir troca, campeão do banco).
class _Tocavel extends StatefulWidget {
  const _Tocavel({
    required this.rotulo,
    required this.aoTocar,
    required this.child,
    this.afundar = 0.97,
  });
  final String rotulo;
  final VoidCallback? aoTocar;
  final Widget child;
  final double afundar;

  @override
  State<_Tocavel> createState() => _TocavelState();
}

class _TocavelState extends State<_Tocavel> {
  bool _apertado = false;
  bool _ocupado = false;

  void _apertar(bool v) {
    if (widget.aoTocar != null && v != _apertado) {
      setState(() => _apertado = v);
    }
  }

  Future<void> _tocar() async {
    if (_ocupado || widget.aoTocar == null) return;
    _ocupado = true;
    widget.aoTocar!();
    // evita toque duplo
    await Future.delayed(const Duration(milliseconds: 900));
    _ocupado = false;
  }

  @override
  Widget build(BuildContext context) {
    // mesma árvore com ou sem toque: trocar a estrutura recriaria a imagem do campeão (pisca)
    return Semantics(
      button: widget.aoTocar != null,
      label: widget.aoTocar == null ? null : widget.rotulo,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _apertar(true),
        onTapCancel: () => _apertar(false),
        onTapUp: (_) => _apertar(false),
        onTap: widget.aoTocar == null ? null : _tocar,
        child: AnimatedScale(
          scale: _apertado ? widget.afundar : 1,
          duration: _dur(context, 120),
          curve: curvaSaida,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Campeões no banco (ARAM). Tocar pega ele, como clicar no banco do client; apagado quando não dá (troca com
/// aliado no meio). [faixa] = uma linha que rola de lado, pra caber em cima das skins.
class _Banco extends StatelessWidget {
  const _Banco({
    required this.sel,
    this.con,
    this.tamanho = 42,
    this.faixa = false,
  });
  final Map sel;
  final Conexao? con;
  final double tamanho;
  final bool faixa;

  @override
  Widget build(BuildContext context) {
    final banco = ((sel['banco'] as List?) ?? const []).cast<num>();
    final ok = con != null && sel['banco_ok'] == true;
    final icones = [
      for (final (i, id) in banco.indexed)
        _Entrada(
          key: ValueKey('banco-$id'),
          chave: 'banco-$id',
          atraso: math.min(i, 6) * 30,
          child: _IconeBanco(
            con: con,
            id: id.toInt(),
            nome: _nomeCampeao(sel['nomes'], id.toInt()),
            tamanho: tamanho,
            ok: ok,
          ),
        ),
    ];
    if (faixa) {
      return Row(
        children: [
          Text('BANCO', style: fonteTitulo(11)),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final w in icones)
                    Padding(padding: const EdgeInsets.only(right: 6), child: w),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('NO BANCO', style: fonteTitulo(12)),
            const Spacer(),
            AnimatedOpacity(
              opacity: ok ? 1 : 0,
              duration: _dur(context, 200),
              child: Text(
                'Toque pra pegar',
                style: TextStyle(color: Cor.apagado, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: icones),
      ],
    );
  }
}

class _IconeBanco extends StatelessWidget {
  const _IconeBanco({
    required this.con,
    required this.id,
    required this.nome,
    required this.tamanho,
    required this.ok,
  });
  final Conexao? con;
  final int id;
  final String nome;
  final double tamanho;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final rotulo = 'banco-$id';
    final pegando = con?.esperando(rotulo) ?? false;
    return Tooltip(
      message: nome,
      child: _Tocavel(
        rotulo: nome.isEmpty ? 'Pegar do banco' : 'Pegar $nome do banco',
        afundar: 0.9,
        aoTocar: ok && con?.ocupado == null
            ? () {
                som.tocar('banco');
                con!.enviar('banco', {'campeao': id}, rotulo);
              }
            : null,
        child: Stack(
          children: [
            _IconeCamp(
              id: id,
              tamanho: tamanho,
              fraco: con != null && !ok,
              corBorda: pegando ? Cor.ouro : null,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: _dur(context, 180),
                  child: pegando
                      ? ColoredBox(
                          key: ValueKey('pegando'),
                          color: Cor.fundo.withValues(alpha: 0.6),
                          child: Center(
                            child: Losango(
                              cor: Cor.ouro,
                              tamanho: 8,
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
    );
  }
}
