part of 'main.dart';

String _semAcento(String t) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const pa = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final c in t.toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i < 0 ? c : pa[i]);
  }
  return b.toString();
}

/// Escolher ou banir pelo celular na sua vez (no planejamento, declarar intenção). Tocar marca o campeão
/// (hover); só o botão trava/bane. Marcar é só marcar: nada trava sem você tocar no botão.
class _Escolha extends StatefulWidget {
  const _Escolha({super.key, required this.con, required this.sel});
  final Conexao con;
  final Map sel;

  @override
  State<_Escolha> createState() => _EscolhaState();
}

class _EscolhaState extends State<_Escolha> {
  final _busca = TextEditingController();
  int? _escolhido;
  String? _ordem; // null = a mesma do client
  // lista da grade guardada: só refaz quando muda o que ela mostra (ver chave no build)
  int? _chave;
  List<int> _lista = const [];
  Set<int> _disponiveis = const {};
  Map<int, bool> _fav = const {};
  Map<int, int> _indice = const {};

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.sel;
    final vez = '${sel['minha_vez'] ?? ''}';
    final planejamento = vez.isEmpty;
    final acao = vez == 'ban' ? 'ban' : 'pick';
    String nome(int id) => _nomeCampeao(sel['nomes'], id);
    final meu = ((sel['meu'] as List?) ?? const []).cast<Map>();
    final deles = ((sel['deles'] as List?) ?? const []).cast<Map>();
    final bans = (sel['bans'] as Map?) ?? const {};
    // fora da grade: banidos, travados por qualquer um e o que um aliado já marcou
    // Arena: repetir campeão vale (os 18 escolhem ao mesmo tempo), então nada some da grade; o que o client
    // não deixa já fica de fora da lista `pickaveis`/`baniveis`
    final arena = _ehArena(sel);
    final fora = <int>{
      if (!arena) ...[
        for (final b in [...?bans['meu'] as List?, ...?bans['deles'] as List?])
          (b as num).toInt(),
        for (final m in [...meu, ...deles])
          if ((m['travado'] == true || m['eu'] != true) &&
              ((m['campeao'] as num?) ?? 0) > 0)
            (m['campeao'] as num).toInt(),
      ],
    };
    final euSlot = meu.firstWhere(
      (m) => m['eu'] == true,
      orElse: () => const {},
    );
    final minhaAtual = ((euSlot['campeao'] as num?) ?? 0).toInt();
    final filtro = _semAcento(_busca.text.trim());
    final base =
        ((acao == 'ban' ? sel['baniveis'] : sel['pickaveis']) as List?) ??
        const [];
    // ordem igual a do client: Favorito (da sua posicao), Nome, Maestria; comeca na que voce usa la
    final grade = (widget.con.estado['grade'] as Map?) ?? const {};
    final ordem = _ordem ?? '${grade['ordem'] ?? 'nome'}';
    final pos = '${sel['minha_pos'] ?? ''}'.toLowerCase();
    // o PC grava a seleção várias vezes por segundo (relógio, chat, hover): a lista só é refeita
    // quando muda o que ela mostra, senão ordenava ~170 campeões a cada gravação
    final chave = Object.hash(
      acao,
      filtro,
      ordem,
      pos,
      minhaAtual,
      Object.hashAllUnordered(fora),
      Object.hashAll(base),
      identityHashCode(grade),
    );
    if (chave != _chave) {
      _chave = chave;
      final info = <int, Map>{
        for (final c in ((grade['campeoes'] as List?) ?? const []).cast<Map>())
          (c['id'] as num).toInt(): c,
      };
      bool favDe(int id) {
        final f = ((info[id]?['f'] as List?) ?? const []).map((x) => '$x');
        return pos.isEmpty
            ? f.isNotEmpty
            : f.any((x) => x == pos || pos.startsWith(x) || x.startsWith(pos));
      }

      final disp = base
          .map((e) => (e as num).toInt())
          .where((id) => !fora.contains(id) || id == minhaAtual)
          .toList();
      _disponiveis = disp.toSet();
      _fav = {for (final id in disp) id: favDe(id)};
      final maestria = {
        for (final id in disp) id: ((info[id]?['m'] as num?) ?? 0).toInt(),
      };
      final nomes = {for (final id in disp) id: nome(id)};
      _lista =
          disp
              .where(
                (id) =>
                    filtro.isEmpty || _semAcento(nomes[id]!).contains(filtro),
              )
              .toList()
            ..sort((a, b) {
              if (ordem == 'favorito' && _fav[a] != _fav[b]) {
                return _fav[a]! ? -1 : 1;
              }
              if (ordem == 'maestria' && maestria[a] != maestria[b]) {
                return maestria[b]!.compareTo(maestria[a]!);
              }
              return nomes[a]!.compareTo(nomes[b]!);
            });
      _indice = {for (var i = 0; i < _lista.length; i++) _lista[i]: i};
    }
    final lista = _lista;
    bool fav(int id) => _fav[id] ?? false;
    // o que você tocou sumiu da grade (aliado travou, alguém baniu) ou o PC já marcou: vale o do client
    if (_escolhido != null &&
        (!_disponiveis.contains(_escolhido) || _escolhido == minhaAtual)) {
      _escolhido = null;
    }
    final marcado = _escolhido ?? (minhaAtual > 0 ? minhaAtual : null);
    final verbo = acao == 'ban' ? 'Banir' : 'Travar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _busca,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 15.5),
                cursorColor: Cor.ouro,
                decoration: InputDecoration(
                  hintText: 'Buscar campeão',
                  hintStyle: TextStyle(color: Cor.apagado),
                  prefixIcon: Icon(Icons.search, color: Cor.apagado, size: 20),
                  suffixIcon: _busca.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar',
                          onPressed: () => setState(_busca.clear),
                          icon: Icon(
                            Icons.close_rounded,
                            color: Cor.apagado,
                            size: 18,
                          ),
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: Cor.campo,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: Raio.r1,
                    borderSide: BorderSide(color: Cor.linha2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: Raio.r1,
                    borderSide: BorderSide(color: Cor.ouro),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _Ordem(atual: ordem, aoMudar: (o) => setState(() => _ordem = o)),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: lista.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum campeão com esse nome.',
                    style: TextStyle(color: Cor.apagado, fontSize: 14),
                  ),
                )
              : GridView.builder(
                  itemCount: lista.length,
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 72,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.78,
                  ),
                  // cada item preso ao campeão: buscar ou trocar a ordem não faz os ícones
                  // trocarem de lugar com crossfade
                  findChildIndexCallback: (k) =>
                      k is ValueKey<int> ? _indice[k.value] : null,
                  itemBuilder: (_, i) {
                    final id = lista[i];
                    final ativo = id == marcado;
                    return KeyedSubtree(
                      key: ValueKey<int>(id),
                      child: Semantics(
                        button: true,
                        selected: ativo,
                        label: nome(id),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            som.tocar('grade');
                            setState(() => _escolhido = id);
                            widget.con.enviar('campeao', {
                              'campeao': id,
                              'acao': acao,
                              'travar': false,
                            });
                          },
                          child: ExcludeSemantics(
                            child: Column(
                              children: [
                                AnimatedScale(
                                  scale: ativo ? 1.06 : 1,
                                  duration: _dur(context, 180),
                                  curve: curvaSaida,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      _IconeCamp(
                                        id: id,
                                        tamanho: 52,
                                        destaque: ativo,
                                      ),
                                      if (fav(id))
                                        Positioned(
                                          right: -4,
                                          top: -4,
                                          child: Icon(
                                            Icons.star_rounded,
                                            size: 16,
                                            color: Cor.ouro,
                                            shadows: [
                                              Shadow(
                                                color: Cor.fundo,
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  nome(id),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: ativo ? Cor.ouroClaro : Cor.apagado,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        // planejamento: tocar já mostra pro time, não tem o que confirmar
        if (!planejamento) ...[
          const SizedBox(height: 8),
          // deitado, botão no meio e mais estreito, como o do client
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _deitado(context) ? 320 : double.infinity,
              ),
              child: AnimatedOpacity(
                opacity: marcado == null ? 0.45 : 1,
                duration: _dur(context, 200),
                child: IgnorePointer(
                  ignoring: marcado == null,
                  child: Botao(
                    texto: marcado == null ? verbo : '$verbo ${nome(marcado)}',
                    principal: true,
                    carregando: widget.con.esperando('travar'),
                    som: acao == 'ban' ? 'banir' : 'travar',
                    aoTocar: () => widget.con.enviar('campeao', {
                      'campeao': marcado!,
                      'acao': acao,
                      'travar': true,
                    }, 'travar'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Favorito | Nome | Maestria, como o "Ordenar por" do client, num botão só.
class _Ordem extends StatelessWidget {
  const _Ordem({required this.atual, required this.aoMudar});
  final String atual;
  final ValueChanged<String> aoMudar;

  static const _opcoes = {
    'favorito': 'Favorito',
    'nome': 'Nome',
    'maestria': 'Maestria',
  };

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Ordenar por',
    initialValue: atual,
    onSelected: aoMudar,
    color: Cor.painel2,
    position: PopupMenuPosition.under,
    popUpAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: const Duration(milliseconds: 220),
            curve: curvaSaida,
          ),
    shape: RoundedRectangleBorder(
      borderRadius: Raio.r2,
      side: BorderSide(color: Cor.linha2),
    ),
    itemBuilder: (_) => [
      for (final o in _opcoes.entries)
        PopupMenuItem(
          value: o.key,
          child: Text(
            o.value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: o.key == atual ? Cor.ouroClaro : Cor.texto,
            ),
          ),
        ),
    ],
    child: Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: Raio.r1,
        color: Cor.painel2,
        border: Border.all(color: Cor.linha2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sort_rounded, size: 18, color: Cor.apagado),
          const SizedBox(width: 6),
          Text(
            _opcoes[atual] ?? 'Nome',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Cor.texto,
            ),
          ),
        ],
      ),
    ),
  );
}
