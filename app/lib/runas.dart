part of 'main.dart';

/// Cor de cada caminho de runa, igual no client (as mesmas do painel).
const _corEstilo = {
  8000: Color(0xFFC8AA6E),
  8100: Color(0xFFD44242),
  8200: Color(0xFF9FAAFC),
  8300: Color(0xFF49AAB9),
  8400: Color(0xFFA1D586),
};
Color _corDe(int id) => _corEstilo[id] ?? Cor.ouro;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// Runa apagada (não é a escolhida da linha): escura e quase sem cor. O filtro vai no próprio desenho da
/// imagem (`color` do Image), sem ColorFiltered: cada ColorFiltered é uma camada a mais e com ~60 runas na
/// tela a abertura do editor engasgava.
NetworkImage _fonteRuna(String caminho) => NetworkImage(
  _arte(caminho, 0),
  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
);

/// Ícone de runa do client no CommunityDragon. Sem caminho, um círculo vazio.
Widget _imgRuna(Object? caminho, double tamanho, {bool apagada = false}) {
  final c = '${caminho ?? ''}';
  if (c.isEmpty) return SizedBox(width: tamanho, height: tamanho);
  return Image(
    image: _fonteRuna(c),
    width: tamanho,
    height: tamanho,
    fit: BoxFit.contain,
    gaplessPlayback: true,
    // srcATop pinta só onde a imagem tem cor (o fundo transparente continua transparente)
    color: apagada ? const Color(0xD41A1F24) : null,
    colorBlendMode: apagada ? BlendMode.srcATop : null,
    errorBuilder: (_, _, _) => SizedBox(width: tamanho, height: tamanho),
  );
}

final _preCarregadas = <String>{};
String? _arvoreVista;

/// Baixa e decodifica os ícones das runas assim que o PC manda as árvores: quando a folha ou o editor
/// abrem, tudo já está na memória e a animação não disputa com download e decodificação.
void _preCarregarRunas(BuildContext context, Conexao con) {
  final a = con.estado['runas_arvore'];
  if (a is! Map) return;
  final p = a['perks'];
  final vista = '${(a['estilos'] as List?)?.length}|${p is Map ? p.length : 0}';
  // roda a cada atualização do PC: só olha de novo se a árvore mudou
  if (vista == _arvoreVista) return;
  _arvoreVista = vista;
  final arv = _Arvore(a);
  final caminhos = <String>{
    for (final e in arv.estilos) '${e['icone'] ?? ''}',
    for (final e in arv.estilos)
      for (final l in [...arv.linhas(e), ...arv.frags])
        for (final id in l) '${arv.perk(id)['icone'] ?? ''}',
  }..removeWhere((c) => c.isEmpty || _preCarregadas.contains(c));
  if (caminhos.isEmpty) return;
  _preCarregadas.addAll(caminhos);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    for (final c in caminhos) {
      precacheImage(_fonteRuna(c), context, onError: (_, _) {});
    }
  });
}

/// As árvores de runas que o PC manda (as mesmas do editor do painel).
class _Arvore {
  _Arvore(Map m)
    : estilos = ((m['estilos'] as List?) ?? const []).cast<Map>(),
      _perks = m['perks'];
  final List<Map> estilos;
  final Object? _perks;

  Map? estilo(int id) => estilos.where((e) => _int(e['id']) == id).firstOrNull;

  List<Map> _slots(Map? e) =>
      e == null ? const [] : ((e['slots'] as List?) ?? const []).cast<Map>();

  List<int> _ids(Map sl) => [
    for (final x in (sl['perks'] as List?) ?? const []) _int(x),
  ];

  /// Linhas do caminho: a pedra fundamental e as 3 de baixo.
  List<List<int>> linhas(Map? e) => [
    for (final sl in _slots(e))
      if (sl['tipo'] != 'kStatMod') _ids(sl),
  ];

  /// As 3 linhas de fragmentos (iguais em todos os caminhos).
  List<List<int>> get frags => [
    for (final sl in _slots(estilos.firstOrNull))
      if (sl['tipo'] == 'kStatMod') _ids(sl),
  ];

  /// Caminhos que dá pra usar de secundário com [prim].
  List<Map> subs(int prim) {
    final p = estilo(prim);
    final ok = [for (final x in (p?['subs'] as List?) ?? const []) _int(x)];
    return [
      for (final e in estilos)
        if (_int(e['id']) != prim && (ok.isEmpty || ok.contains(_int(e['id']))))
          e,
    ];
  }

  Map perk(int id) {
    final p = _perks;
    final v = p is Map ? p['$id'] : null;
    return v is Map ? v : const {};
  }

  String nomeEstilo(int id) => '${estilo(id)?['nome'] ?? ''}';
}

/// Página em edição: [pedra, 3 da principal], 2 da secundária, 3 fragmentos.
class _Rascunho {
  _Rascunho({
    required this.pagina,
    required this.nome,
    required this.prim,
    required this.sec,
    required this.p,
    required this.s,
    required this.f,
  });

  /// Começa de uma página do client; o que não casa com a árvore fica vazio.
  factory _Rascunho.de(Map? pag, _Arvore arv) {
    final perks = [
      for (final x in (pag?['perks'] as List?) ?? const []) _int(x),
    ];
    var prim = _int(pag?['prim']);
    var sec = _int(pag?['sec']);
    if (arv.estilo(prim) == null) prim = 0;
    if (sec == prim || !arv.subs(prim).any((e) => _int(e['id']) == sec)) {
      sec = 0;
    }
    final lp = arv.linhas(arv.estilo(prim));
    final ls = arv.linhas(arv.estilo(sec)).skip(1).toList();
    final fr = arv.frags;
    int? em(int i, List<List<int>> linhas, int linha) =>
        i < perks.length &&
            linha < linhas.length &&
            linhas[linha].contains(perks[i])
        ? perks[i]
        : null;
    return _Rascunho(
      pagina: _int(pag?['id']),
      nome: '${pag?['nome'] ?? ''}',
      prim: prim,
      sec: sec,
      p: [for (var i = 0; i < 4; i++) em(i, lp, i)],
      s: [
        for (var i = 4; i < 6 && i < perks.length; i++)
          if (ls.any((l) => l.contains(perks[i]))) perks[i],
      ],
      f: [for (var i = 0; i < 3; i++) em(6 + i, fr, i)],
    );
  }

  final int pagina; // 0 = página nova
  String nome;
  int prim;
  int sec;
  List<int?> p;
  List<int> s;
  List<int?> f;

  List<String> get falta => [
    if (prim == 0) 'caminho principal',
    if (prim != 0 && p[0] == null) 'pedra fundamental',
    if (prim != 0 && p.skip(1).any((x) => x == null)) 'runas da principal',
    if (sec == 0) 'caminho secundário',
    if (sec != 0 && s.length < 2) '2 runas da secundária',
    if (f.any((x) => x == null)) 'fragmentos',
  ];

  /// Como o client grava: a secundária na ordem das linhas.
  List<int> perks(_Arvore arv) {
    final ls = arv.linhas(arv.estilo(sec)).skip(1).toList();
    int linha(int id) => ls.indexWhere((l) => l.contains(id));
    final sec2 = [...s]..sort((a, b) => linha(a) - linha(b));
    return [...p.cast<int>(), ...sec2, ...f.cast<int>()];
  }
}

/// Tem runas pra mostrar: o PC mandou as páginas e as árvores.
bool _temRunas(Conexao con) {
  final r = con.estado['runas'];
  final a = con.estado['runas_arvore'];
  return r is Map &&
      a is Map &&
      ((a['estilos'] as List?) ?? const []).isNotEmpty;
}

List<Map> _paginas(Conexao con) =>
    (((con.estado['runas'] as Map?)?['paginas'] as List?) ?? const [])
        .cast<Map>();

Map? _paginaAtual(Conexao con) =>
    _paginas(con).where((p) => p['atual'] == true).firstOrNull;

/// Botão das runas na seleção (como o do rodapé do client): mostra a pedra da página em uso.
/// [largo]: com o nome da página do lado (deitado, embaixo do time).
class _BotaoRunas extends StatelessWidget {
  const _BotaoRunas({required this.con, this.largo = false});
  final Conexao con;
  final bool largo;

  @override
  Widget build(BuildContext context) {
    _preCarregarRunas(context, con);
    final atual = _paginaAtual(con);
    final arv = _Arvore(con.estado['runas_arvore'] as Map);
    final perks = (atual?['perks'] as List?) ?? const [];
    final prim = _int(atual?['prim']);
    final cor = atual == null ? Cor.linha2 : _corDe(prim);
    final pedra = perks.isNotEmpty
        ? arv.perk(_int(perks.first))['icone']
        : arv.estilo(prim)?['icone'];
    final nome = '${atual?['nome'] ?? 'Runas'}';
    final icone = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF050D15),
        border: Border.all(color: cor.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(color: cor.withValues(alpha: 0.25), blurRadius: 8),
        ],
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: _dur(context, 220),
        child: KeyedSubtree(key: ValueKey(pedra), child: _imgRuna(pedra, 26)),
      ),
    );
    final botao = Semantics(
      button: true,
      label: 'Runas: $nome',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _abrirRunas(context, con),
        child: Container(
          width: largo ? null : 46,
          height: 46,
          padding: largo ? const EdgeInsets.only(left: 6, right: 8) : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: Raio.r1,
            color: Cor.painel2,
            border: Border.all(color: Cor.linha2),
          ),
          child: largo
              ? Row(
                  children: [
                    icone,
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Cor.ouroClaro,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.unfold_more_rounded,
                      size: 18,
                      color: Cor.apagado,
                    ),
                  ],
                )
              : icone,
        ),
      ),
    );
    // os ícones já desenhados uma vez, minúsculos e invisíveis: a placa de vídeo já tem a textura de cada
    // um quando a folha ou o editor abrem (sem isso o primeiro quadro engasgava subindo ~80 imagens)
    return Stack(
      clipBehavior: Clip.none,
      children: [
        botao,
        Positioned(
          left: 0,
          top: 0,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: Opacity(
                  opacity: 0.01,
                  child: SizedBox(
                    width: 1,
                    height: 1,
                    child: Stack(
                      children: [
                        for (final c in _preCarregadas) _imgRuna(c, 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _abrirRunas(BuildContext context, Conexao con) async {
  final base = con.nav.areaSegura().base;
  som.tocar('abrir');
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Cor.veu,
    constraints: const BoxConstraints(maxWidth: 760),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: const Duration(milliseconds: 340),
            reverseDuration: const Duration(milliseconds: 240),
            curve: _curvaFolha,
            reverseCurve: _curvaFolha.flipped,
          ),
    builder: (_) => _FolhaRunas(con: con, base: base),
  );
  som.tocar('fechar');
}

/// Folha das runas: a lista das suas páginas (toque usa, lápis edita) e o editor, um passo por vez.
class _FolhaRunas extends StatefulWidget {
  const _FolhaRunas({required this.con, required this.base});
  final Conexao con;
  final double base;

  @override
  State<_FolhaRunas> createState() => _FolhaRunasState();
}

class _FolhaRunasState extends State<_FolhaRunas> {
  _Rascunho? _ed;
  int? _escolhida; // tocada aqui e ainda não confirmada pelo PC
  bool _salvando = false;
  String? _erro;
  bool _fechou = false;
  StreamSubscription? _resp;
  String? _visto;

  /// O que a folha mostra. O PC grava o estado várias vezes por segundo na seleção (tempo, chat): redesenhar
  /// a folha inteira a cada gravação travava a animação de abrir e de trocar de passo.
  String _chave() =>
      '${widget.con.fase}|${_temRunas(widget.con)}|${widget.con.estado['runas']}';

  void _mudou() {
    final k = _chave();
    if (k == _visto || !mounted) return;
    setState(() => _visto = k);
  }

  @override
  void initState() {
    super.initState();
    _visto = _chave();
    widget.con.addListener(_mudou);
    _resp = widget.con.respostas.stream.listen((r) {
      if (!mounted) return;
      setState(() {
        if (_salvando) {
          _salvando = false;
          if (r.ok) {
            som.tocar('sucesso');
            _ed = null; // salvou: volta pra lista com ela em uso
          } else {
            _erro = r.msg;
          }
        } else if (_escolhida != null && !r.ok) {
          _escolhida = null;
          _erro = r.msg;
        }
      });
    });
  }

  @override
  void dispose() {
    widget.con.removeListener(_mudou);
    _resp?.cancel();
    super.dispose();
  }

  void _usar(Map pag) {
    final id = _int(pag['id']);
    if (pag['atual'] == true) return;
    setState(() {
      _escolhida = id;
      _erro = null;
    });
    widget.con.enviar('runa_pagina', {'pagina': id});
  }

  void _editar(Map? pag, _Arvore arv) => setState(() {
    _ed = _Rascunho.de(pag, arv);
    _erro = null;
  });

  void _salvar(_Arvore arv) {
    final d = _ed!;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    widget.con.enviar('runa_salvar', {
      'pagina': d.pagina,
      'nome': d.nome.trim().isEmpty ? 'Página nova' : d.nome.trim(),
      'primaria': d.prim,
      'secundaria': d.sec,
      'perks': d.perks(arv),
    });
  }

  void _voltar() => setState(() {
    _ed = null;
    _erro = null;
    _salvando = false;
  });

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height;
    return Builder(
      builder: (context) {
        final con = widget.con;
        if (!_temRunas(con) || con.fase != 'ChampSelect') {
          // a seleção acabou com a folha aberta: fecha sozinha
          if (!_fechou) {
            _fechou = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => Navigator.of(context).maybePop(),
            );
          }
          return const SizedBox.shrink();
        }
        final arv = _Arvore(con.estado['runas_arvore'] as Map);
        final paginas = _paginas(con);
        final atual = _int(_paginaAtual(con)?['id']);
        if (_escolhida == atual) _escolhida = null;
        final ed = _ed;
        return RepaintBoundary(
          child: Container(
            height: math.min(alto * (alto < 520 ? 0.94 : 0.9), 780),
            decoration: BoxDecoration(
              color: Cor.painel,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              border: Border(top: BorderSide(color: Cor.ouroEscuro)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: alto < 520 ? 6 : 10),
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Cor.linha2,
                      borderRadius: Raio.r1,
                    ),
                  ),
                ),
                _cabecalho(ed, baixo: alto < 520),
                Divider(height: 1, color: Cor.linha),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: _dur(context, 300),
                    switchInCurve: curvaSaida,
                    switchOutCurve: Curves.easeIn,
                    layoutBuilder: (a, antigos) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...antigos, ?a],
                    ),
                    transitionBuilder: (c, a) {
                      final indo = c.key == const ValueKey('editor');
                      return FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(
                            begin: Offset(indo ? 0.12 : -0.12, 0),
                            end: Offset.zero,
                          ).animate(a),
                          child: c,
                        ),
                      );
                    },
                    child: ed == null
                        ? RepaintBoundary(
                            key: const ValueKey('lista'),
                            child: _ListaPaginas(
                              con: con,
                              arv: arv,
                              paginas: paginas,
                              escolhida: _escolhida ?? atual,
                              girando: _escolhida,
                              podeCriar:
                                  (con.estado['runas'] as Map)['pode_criar'] ==
                                  true,
                              erro: _erro,
                              base: widget.base,
                              aoUsar: _usar,
                              aoEditar: (p) => _editar(p, arv),
                            ),
                          )
                        : RepaintBoundary(
                            key: const ValueKey('editor'),
                            child: _Editor(
                              arv: arv,
                              d: ed,
                              salvando: _salvando,
                              erro: _erro,
                              base: widget.base,
                              aoMudar: () => setState(() => _erro = null),
                              aoSalvar: () => _salvar(arv),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// [baixo]: celular deitado, com menos respiro (cada pixel de altura conta).
  Widget _cabecalho(_Rascunho? ed, {bool baixo = false}) {
    final titulo = ed == null
        ? 'RUNAS'
        : (ed.pagina == 0 ? 'NOVA PÁGINA' : 'EDITAR PÁGINA');
    return Padding(
      padding: EdgeInsets.fromLTRB(8, baixo ? 0 : 6, 8, baixo ? 2 : 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: AnimatedSwitcher(
              duration: _dur(context, 200),
              child: ed == null
                  ? const SizedBox.shrink()
                  : IconButton(
                      key: const ValueKey('voltar'),
                      tooltip: 'Voltar pras páginas',
                      onPressed: _salvando ? null : _voltar,
                      icon: Icon(Icons.arrow_back_rounded, color: Cor.apagado),
                    ),
            ),
          ),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: _dur(context, 200),
                child: Text(
                  titulo,
                  key: ValueKey(titulo),
                  style: fonteTitulo(15),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: 'Fechar',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: Cor.apagado),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mensagem de erro curta, em vermelho, que entra e sai sem pular a tela.
Widget _erroRunas(BuildContext context, String? erro) => AnimatedSize(
  duration: _dur(context, 220),
  curve: curvaSaida,
  child: erro == null || erro.isEmpty
      ? const SizedBox(width: double.infinity)
      : Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 16,
                color: Cor.vermelho,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  erro,
                  style: const TextStyle(color: Cor.vermelho, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
);

class _ListaPaginas extends StatelessWidget {
  const _ListaPaginas({
    required this.con,
    required this.arv,
    required this.paginas,
    required this.escolhida,
    required this.girando,
    required this.podeCriar,
    required this.erro,
    required this.base,
    required this.aoUsar,
    required this.aoEditar,
  });
  final Conexao con;
  final _Arvore arv;
  final List<Map> paginas;
  final int escolhida;
  final int? girando;
  final bool podeCriar;
  final String? erro;
  final double base;
  final ValueChanged<Map> aoUsar;
  final ValueChanged<Map?> aoEditar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: paginas.isEmpty
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Você ainda não tem página de runas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Cor.apagado, fontSize: 15),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                itemCount: paginas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = paginas[i];
                  final id = _int(p['id']);
                  return _LinhaPagina(
                    arv: arv,
                    pag: p,
                    emUso: id == escolhida,
                    girando: girando == id,
                    aoTocar: () => p['valida'] == false && p['editavel'] == true
                        ? aoEditar(
                            p,
                          ) // incompleta não dá pra usar: abre pra completar
                        : aoUsar(p),
                    aoEditar: p['editavel'] == true ? () => aoEditar(p) : null,
                  );
                },
              ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.sizeOf(context).height < 520 ? 8 : 12,
          20,
          (MediaQuery.sizeOf(context).height < 520 ? 10 : 16) + base,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Cor.linha)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _erroRunas(context, erro),
            if (podeCriar)
              // deitado: botão do tamanho do texto, à direita (largura toda ficava enorme)
              MediaQuery.sizeOf(context).height < 520
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Botao(
                        texto: 'Nova página',
                        compacto: true,
                        aoTocar: () => aoEditar(null),
                      ),
                    )
                  : Botao(texto: 'Nova página', aoTocar: () => aoEditar(null))
            else
              Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Sem espaço pra página nova: edite uma das suas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Cor.apagado, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

/// Uma página: pedra na cor do caminho, o secundário encostado nela, nome e os dois caminhos.
class _LinhaPagina extends StatefulWidget {
  const _LinhaPagina({
    required this.arv,
    required this.pag,
    required this.emUso,
    required this.girando,
    required this.aoTocar,
    required this.aoEditar,
  });
  final _Arvore arv;
  final Map pag;
  final bool emUso;
  final bool girando;
  final VoidCallback aoTocar;
  final VoidCallback? aoEditar;

  @override
  State<_LinhaPagina> createState() => _LinhaPaginaState();
}

class _LinhaPaginaState extends State<_LinhaPagina> {
  bool _apertado = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.pag;
    final arv = widget.arv;
    final prim = _int(p['prim']);
    final sec = _int(p['sec']);
    final perks = (p['perks'] as List?) ?? const [];
    final cor = _corDe(prim);
    final uso = widget.emUso;
    final valida = p['valida'] != false;
    final caminhos = [
      arv.nomeEstilo(prim),
      arv.nomeEstilo(sec),
    ].where((x) => x.isNotEmpty).join(' + ');
    final sub = !valida ? 'Incompleta' : caminhos;
    return Semantics(
      button: true,
      selected: uso,
      label: '${p['nome']}${uso ? ', em uso' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _apertado = true),
        onTapCancel: () => setState(() => _apertado = false),
        onTapUp: (_) => setState(() => _apertado = false),
        onTap: widget.aoTocar,
        child: AnimatedScale(
          scale: _apertado ? 0.985 : 1,
          duration: _dur(context, 120),
          curve: curvaSaida,
          child: AnimatedContainer(
            duration: _dur(context, 240),
            curve: curvaSaida,
            padding: const EdgeInsets.fromLTRB(10, 9, 4, 9),
            decoration: BoxDecoration(
              borderRadius: Raio.r2,
              gradient: LinearGradient(
                colors: [
                  Color.lerp(Cor.painel2, cor, uso ? 0.14 : 0)!,
                  Cor.painel2,
                ],
              ),
              border: Border.all(
                color: uso ? cor.withValues(alpha: 0.85) : Cor.linha2,
              ),
              boxShadow: uso
                  ? [
                      BoxShadow(
                        color: cor.withValues(alpha: 0.18),
                        blurRadius: 14,
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 48,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF050D15),
                          border: Border.all(
                            color: cor.withValues(alpha: uso ? 0.9 : 0.45),
                            width: 1.5,
                          ),
                        ),
                        child: perks.isNotEmpty
                            ? _imgRuna(arv.perk(_int(perks.first))['icone'], 38)
                            : _imgRuna(arv.estilo(prim)?['icone'], 24),
                      ),
                      if (sec != 0)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF050D15),
                              border: Border.all(
                                color: _corDe(sec).withValues(alpha: 0.7),
                              ),
                            ),
                            child: _imgRuna(arv.estilo(sec)?['icone'], 14),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p['nome']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: uso ? Cor.ouroClaro : Cor.texto,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: valida ? Cor.apagado : Cor.aviso,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: _dur(context, 200),
                  child: widget.girando
                      ? SizedBox(
                          key: ValueKey('girando'),
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Cor.ouroClaro,
                          ),
                        )
                      : uso
                      ? Row(
                          key: const ValueKey('uso'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Losango(cor: cor, tamanho: 7),
                            const SizedBox(width: 7),
                            Text(
                              'EM USO',
                              style: TextStyle(
                                color: cor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(key: ValueKey('nada')),
                ),
                if (widget.aoEditar != null)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      tooltip: 'Editar ${p['nome']}',
                      onPressed: widget.aoEditar,
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: Cor.apagado,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Editor de página no jeito do client: o caminho principal com a pedra e 3 linhas, o secundário com 2 de
/// 3 linhas e os fragmentos. Tocar numa runa escolhe e mostra o que ela faz no rodapé.
class _Editor extends StatefulWidget {
  const _Editor({
    required this.arv,
    required this.d,
    required this.salvando,
    required this.erro,
    required this.base,
    required this.aoMudar,
    required this.aoSalvar,
  });
  final _Arvore arv;
  final _Rascunho d;
  final bool salvando;
  final String? erro;
  final double base;
  final VoidCallback aoMudar;
  final VoidCallback aoSalvar;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final _nome = TextEditingController(text: widget.d.nome);
  int? _info; // runa tocada por último: o rodapé mostra o que ela faz
  int _anim = 0; // muda quando troca o caminho: as linhas entram de novo

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  _Rascunho get d => widget.d;
  _Arvore get arv => widget.arv;

  void _mudar(VoidCallback f) {
    som.tocar('runa');
    setState(f);
    widget.aoMudar();
  }

  void _prim(int id) => _mudar(() {
    if (id == d.prim) return;
    d.prim = id;
    d.p = [null, null, null, null];
    if (d.sec == id || !arv.subs(id).any((e) => _int(e['id']) == d.sec)) {
      d.sec = 0;
      d.s = [];
    }
    _anim++;
  });

  void _sec(int id) => _mudar(() {
    if (id == d.sec) return;
    d.sec = id;
    d.s = [];
    _anim++;
  });

  void _runaPrim(int linha, int id) => _mudar(() {
    d.p[linha] = id;
    _info = id;
  });

  void _runaSec(List<int> linha, int id) => _mudar(() {
    _info = id;
    if (d.s.contains(id)) {
      d.s = d.s.where((x) => x != id).toList();
      return;
    }
    // 2 runas de linhas diferentes: a terceira tira a mais antiga
    final s = d.s.where((x) => !linha.contains(x)).toList()..add(id);
    d.s = s.length > 2 ? s.sublist(s.length - 2) : s;
  });

  void _frag(int linha, int id) => _mudar(() {
    d.f[linha] = id;
    _info = id;
  });

  @override
  Widget build(BuildContext context) {
    // duas colunas (principal | secundária + fragmentos) como no client: em pé também, assim cabe sem rolar
    final largo = MediaQuery.sizeOf(context).width >= 340;
    final folga = MediaQuery.sizeOf(context).width >= 600;
    final prim = arv.estilo(d.prim);
    Widget principal(bool encher, {double fatiaMax = double.infinity}) =>
        _secao('PRINCIPAL', d.prim, encher: encher, [
          _Estilos(estilos: arv.estilos, atual: d.prim, aoEscolher: _prim),
          const SizedBox(height: 10),
          if (prim == null)
            const _Vazio(texto: 'Escolha um caminho pra começar.')
          else
            _Trilha(
              key: ValueKey('p${d.prim}-$_anim'),
              entrar: _anim > 0,
              encher: encher,
              fatiaMax: fatiaMax,
              cor: _corDe(d.prim),
              linhas: [
                for (final (i, l) in arv.linhas(prim).take(4).indexed)
                  _Linha(
                    ids: l,
                    escolhidas: {?d.p[i]},
                    tamanho: i == 0 ? 60 : 50,
                    pedra: i == 0,
                    aoTocar: (id) => _runaPrim(i, id),
                  ),
              ],
              arv: arv,
            ),
        ]);
    final corFrag = d.prim == 0 ? Cor.ouroEscuro : _corDe(d.prim);
    List<_Linha> linhasFrags({Color? cor}) => [
      for (final (i, l) in arv.frags.indexed)
        _Linha(
          ids: l,
          escolhidas: {?d.f[i]},
          tamanho: 28,
          cor: cor,
          aoTocar: (id) => _frag(i, id),
        ),
    ];
    Widget trilhaFrags(bool encher) =>
        _Trilha(encher: encher, cor: corFrag, linhas: linhasFrags(), arv: arv);
    // [comFrags]: os fragmentos continuam a trilha da secundária, sem título próprio, como no client
    Widget secundaria(
      bool encher, {
      bool comFrags = false,
    }) => _secao('SECUNDÁRIA', d.sec, encher: encher, [
      if (prim == null) ...[
        const _Vazio(texto: 'Escolha o principal primeiro.'),
        if (comFrags) ...[const SizedBox(height: 10), trilhaFrags(encher)],
      ] else ...[
        _Estilos(estilos: arv.subs(d.prim), atual: d.sec, aoEscolher: _sec),
        const SizedBox(height: 10),
        if (d.sec == 0) ...[
          const _Vazio(texto: 'Escolha o caminho secundário.'),
          if (comFrags) ...[const SizedBox(height: 10), trilhaFrags(encher)],
        ] else
          _Trilha(
            key: ValueKey('s${d.sec}-$_anim'),
            entrar: _anim > 0,
            encher: encher,
            cor: _corDe(d.sec),
            linhas: [
              for (final l in arv.linhas(arv.estilo(d.sec)).skip(1))
                _Linha(
                  ids: l,
                  escolhidas: d.s.where(l.contains).toSet(),
                  // já tem as 2: a linha que ficou de fora apaga, como no client
                  cheia: d.s.length >= 2,
                  tamanho: 40,
                  aoTocar: (id) => _runaSec(l, id),
                ),
              if (comFrags) ...linhasFrags(cor: corFrag),
            ],
            arv: arv,
          ),
      ],
    ]);
    Widget fragmentos(bool encher) =>
        _secao('FRAGMENTOS', 0, encher: encher, [trilhaFrags(encher)]);

    final falta = d.falta;
    final baixo = MediaQuery.sizeOf(context).height < 520;
    final salvar = AnimatedOpacity(
      opacity: falta.isEmpty ? 1 : 0.55,
      duration: _dur(context, 200),
      child: IgnorePointer(
        ignoring: falta.isNotEmpty,
        child: Botao(
          texto: falta.isEmpty ? 'Salvar e usar' : 'Falta: ${falta.first}',
          principal: falta.isEmpty,
          carregando: widget.salvando,
          compacto: baixo,
          pequeno: baixo && largo,
          aoTocar: widget.aoSalvar,
        ),
      ),
    );
    final nome = TextField(
      controller: _nome,
      maxLength: 25,
      // coluna estreita (deitado): o nome quebra em 2 linhas em vez de sumir pela direita. Enter não pula
      // linha (o client não aceita nome com quebra)
      minLines: 1,
      maxLines: 2,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      onChanged: (t) => d.nome = t,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Cor.ouroClaro,
      ),
      cursorColor: Cor.ouro,
      decoration: InputDecoration(
        counterText: '',
        hintText: 'Nome da página',
        hintStyle: TextStyle(color: Cor.apagado),
        prefixIcon: Icon(Icons.edit_outlined, size: 18, color: Cor.apagado),
        isDense: true,
        prefixIconConstraints: BoxConstraints(minWidth: 30, minHeight: 20),
        contentPadding: EdgeInsets.symmetric(vertical: 10),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Cor.linha2),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Cor.ouro),
        ),
      ),
    );
    // celular deitado: altura é o que falta. As três partes lado a lado ocupando a altura toda, e o nome,
    // o que a runa faz e o botão na coluna dos fragmentos (sem rodapé, que comia um quarto da tela)
    if (baixo && largo) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 10 + widget.base),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 6, child: principal(true)),
            const SizedBox(width: 18),
            Expanded(flex: 5, child: secundaria(true)),
            const SizedBox(width: 18),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  nome,
                  const SizedBox(height: 10),
                  Expanded(child: fragmentos(true)),
                  const SizedBox(height: 8),
                  // altura fixa: o texto da runa trocando não pode empurrar os fragmentos
                  SizedBox(
                    height: 40,
                    child: _info == null
                        ? const SizedBox.shrink()
                        : _InfoRuna(arv: arv, id: _info, curto: true),
                  ),
                  _erroRunas(context, widget.erro),
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerRight, child: salvar),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              // em pé: principal à esquerda sem esticar (as runas encolhem na coluna estreita e sobrava
              // vão entre as linhas); à direita a secundária ocupa o que sobra e os fragmentos ficam juntos
              if (!folga && largo && c.maxHeight >= 500) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      nome,
                      const SizedBox(height: 12),
                      // as duas trilhas enchem a mesma altura (terminam juntas, como no client), com teto
                      // pra não esticar em tela alta
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 470),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 6, child: principal(true)),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 5,
                                  child: secundaria(true, comFrags: true),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              // tela grande: as duas colunas ocupam a altura toda e as linhas se espalham até o rodapé
              if (largo && c.maxHeight >= 500) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      nome,
                      const SizedBox(height: 14),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: principal(true)),
                            SizedBox(width: folga ? 20 : 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 5, child: secundaria(true)),
                                  const SizedBox(height: 14),
                                  Expanded(flex: 4, child: fragmentos(true)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    nome,
                    const SizedBox(height: 14),
                    if (largo)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: principal(false)),
                          SizedBox(width: folga ? 20 : 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                secundaria(false),
                                const SizedBox(height: 14),
                                fragmentos(false),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      principal(false),
                      const SizedBox(height: 22),
                      secundaria(false),
                      const SizedBox(height: 22),
                      fragmentos(false),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            20,
            baixo ? 8 : 12,
            20,
            (baixo ? 10 : 16) + widget.base,
          ),
          decoration: BoxDecoration(
            color: Cor.painel,
            border: Border(top: BorderSide(color: Cor.linha)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _erroRunas(context, widget.erro),
              // tela baixa (celular deitado): o que a runa faz fica do lado do botao, numa linha so
              if (baixo)
                Row(
                  children: [
                    Expanded(
                      child: _info == null
                          ? const SizedBox.shrink()
                          : _InfoRuna(arv: arv, id: _info, curto: true),
                    ),
                    const SizedBox(width: 16),
                    salvar,
                  ],
                )
              else ...[
                AnimatedSize(
                  duration: _dur(context, 220),
                  curve: curvaSaida,
                  alignment: Alignment.topCenter,
                  child: _info == null
                      ? const SizedBox(width: double.infinity)
                      : _InfoRuna(arv: arv, id: _info),
                ),
                salvar,
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// [encher]: a última parte (a trilha) ocupa o que sobra da altura.
  Widget _secao(
    String titulo,
    int estilo,
    List<Widget> filhos, {
    bool encher = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, c) {
          final nome = AnimatedSwitcher(
            duration: _dur(context, 200),
            child: Text(
              arv.nomeEstilo(estilo),
              key: ValueKey(estilo),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _corDe(estilo),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          );
          final rotulo = Text(titulo, style: fonteTitulo(12, cor: Cor.apagado));
          // coluna estreita (a secundária ao lado dos fragmentos, em pé): o nome do caminho vai embaixo do
          // título, sempre, pra não cortar nem pular de lugar ao trocar de caminho
          if (c.maxWidth < 240) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                rotulo,
                if (estilo != 0) ...[const SizedBox(height: 2), nome],
              ],
            );
          }
          return Row(
            children: [
              rotulo,
              if (estilo != 0) ...[
                const SizedBox(width: 10),
                Flexible(child: nome),
              ],
            ],
          );
        },
      ),
      const SizedBox(height: 10),
      if (!encher || filhos.isEmpty)
        ...filhos
      else ...[
        ...filhos.take(filhos.length - 1),
        Expanded(
          child: filhos.last is _Trilha
              ? filhos.last
              : Align(alignment: Alignment.topCenter, child: filhos.last),
        ),
      ],
    ],
  );
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
    decoration: BoxDecoration(
      borderRadius: Raio.r2,
      border: Border.all(color: Cor.linha2),
      color: Cor.painel2.withValues(alpha: 0.5),
    ),
    child: Text(
      texto,
      textAlign: TextAlign.center,
      style: TextStyle(color: Cor.apagado, fontSize: 14),
    ),
  );
}

/// Fileira dos caminhos: o escolhido maior, com anel na cor dele.
class _Estilos extends StatelessWidget {
  const _Estilos({
    required this.estilos,
    required this.atual,
    required this.aoEscolher,
  });
  final List<Map> estilos;
  final int atual;
  final ValueChanged<int> aoEscolher;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      // cabe na coluna: em pé são duas colunas lado a lado
      final caixa = math.min(52.0, c.maxWidth / math.max(1, estilos.length));
      final grande = caixa - 2;
      final pequeno = caixa * 0.76;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final e in estilos)
            Builder(
              builder: (context) {
                final id = _int(e['id']);
                final sel = id == atual;
                final cor = _corDe(id);
                return Semantics(
                  button: true,
                  selected: sel,
                  label: '${e['nome']}',
                  child: Tooltip(
                    message: '${e['nome']}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => aoEscolher(id),
                      child: SizedBox(
                        width: caixa,
                        height: caixa,
                        child: Center(
                          child: AnimatedContainer(
                            duration: _dur(context, 240),
                            curve: curvaSaida,
                            width: sel ? grande : pequeno,
                            height: sel ? grande : pequeno,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF050D15),
                              border: Border.all(
                                color: sel ? cor : Cor.linha2,
                                width: sel ? 2 : 1,
                              ),
                              boxShadow: sel
                                  ? [
                                      BoxShadow(
                                        color: cor.withValues(alpha: 0.35),
                                        blurRadius: 14,
                                      ),
                                    ]
                                  : const [],
                            ),
                            child: _imgRuna(
                              e['icone'],
                              sel ? grande * 0.56 : pequeno * 0.55,
                              apagada: !sel && atual != 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}

class _Linha {
  const _Linha({
    required this.ids,
    required this.escolhidas,
    required this.tamanho,
    required this.aoTocar,
    this.pedra = false,
    this.cheia = false,
    this.cor,
  });
  final List<int> ids;
  final Set<int> escolhidas;
  final bool cheia;

  /// Cor própria da linha (os fragmentos na trilha da secundária); sem ela, a da trilha.
  final Color? cor;
  final double tamanho;
  final bool pedra;
  final ValueChanged<int> aoTocar;
}

/// Linhas de runas com o trilho vertical na cor do caminho (um nó aceso por linha completa), como no client.
/// Entra uma linha depois da outra quando o caminho muda.
class _Trilha extends StatefulWidget {
  const _Trilha({
    super.key,
    required this.cor,
    required this.linhas,
    required this.arv,
    this.entrar = false,
    this.encher = false,
    this.fatiaMax = double.infinity,
  });
  final Color cor;
  final List<_Linha> linhas;
  final _Arvore arv;

  /// Ocupa a altura que recebe: as linhas se espalham de cima a baixo.
  final bool encher;

  /// Enchendo: altura máxima de cada linha. Sobrando altura, a trilha fica em cima em vez de esticar.
  final double fatiaMax;

  /// Linhas entram uma depois da outra (trocou o caminho). Ao abrir o editor não: ele já entra deslizando,
  /// e as duas animações juntas pesavam.
  final bool entrar;

  @override
  State<_Trilha> createState() => _TrilhaState();
}

class _TrilhaState extends State<_Trilha> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.entrar || MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  // uma curva por linha, criada uma vez: CurvedAnimation no build prende um listener no _c a cada toque
  final _curvas = <(int, int), CurvedAnimation>{};
  CurvedAnimation _curva(int i, int n) => _curvas.putIfAbsent(
    (i, n),
    () => CurvedAnimation(
      parent: _c,
      curve: Interval(i / (n + 2), (i + 3) / (n + 2), curve: curvaSaida),
    ),
  );

  @override
  void dispose() {
    for (final c in _curvas.values) {
      c.dispose();
    }
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = widget.cor;
    final n = widget.linhas.length;
    // enchendo a altura: cada linha tem no máximo a sua fatia (a runa encolhe se a tela for baixa)
    return LayoutBuilder(
      builder: (context, caixa) {
        // a linha da pedra fundamental vale 1,4 linha: ela é a maior, como no client
        final partes = n + (widget.linhas.any((l) => l.pedra) ? 0.4 : 0);
        // os fios entre as linhas também ocupam altura
        final fios = (n - 1) * _Fio.altura;
        final fatia = widget.encher && caixa.maxHeight.isFinite
            ? math.min((caixa.maxHeight - fios) / partes, widget.fatiaMax)
            : double.infinity;
        final limitada =
            widget.encher &&
            fatia.isFinite &&
            fatia * partes + fios < caixa.maxHeight;
        final trilha = Stack(
          fit: widget.encher ? StackFit.expand : StackFit.loose,
          children: [
            // trilho
            Positioned(
              left: 5,
              top: 14,
              bottom: 14,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  borderRadius: Raio.r1,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cor, cor.withValues(alpha: 0.25)],
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: widget.encher
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.start,
              children: [
                for (final (i, l) in widget.linhas.indexed) ...[
                  FadeTransition(
                    opacity: _curva(i, n),
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(_curva(i, n)),
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: i == n - 1 || widget.encher
                              ? 0
                              : (l.pedra ? 8 : 4),
                        ),
                        child: Row(
                          children: [
                            // secundária com as 2: a linha que ficou de fora não tem nó, como no client
                            // (some pela cor, sem camada de Opacity)
                            AnimatedContainer(
                              duration: _dur(context, 220),
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: l.escolhidas.isNotEmpty
                                    ? (l.cor ?? cor)
                                    : l.cheia
                                    ? const Color(0x00050D15)
                                    : const Color(0xFF050D15),
                                border: Border.all(
                                  color: l.cheia && l.escolhidas.isEmpty
                                      ? (l.cor ?? cor).withValues(alpha: 0)
                                      : (l.cor ?? cor),
                                  width: 2,
                                ),
                                boxShadow: l.escolhidas.isNotEmpty
                                    ? [
                                        BoxShadow(
                                          color: (l.cor ?? cor).withValues(
                                            alpha: 0.6,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : const [],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              // em pé as duas árvores ficam lado a lado (como no client): a runa encolhe pra caber
                              child: LayoutBuilder(
                                builder: (_, c) {
                                  final cada = c.maxWidth / l.ids.length;
                                  final f = l.pedra ? fatia * 1.4 : fatia;
                                  final t = math.min(
                                    math.min(l.tamanho, cada - 6),
                                    f - 10,
                                  );
                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      for (final id in l.ids)
                                        _BotaoRuna(
                                          perk: widget.arv.perk(id),
                                          cor: (l.cor ?? cor),
                                          tamanho: t,
                                          area: math.min(
                                            math.min(
                                              math.max(44.0, t + 6),
                                              cada,
                                            ),
                                            f - 2,
                                          ),
                                          pedra: l.pedra,
                                          escolhida: l.escolhidas.contains(id),
                                          apagada:
                                              (l.escolhidas.isNotEmpty ||
                                                  l.cheia) &&
                                              !l.escolhidas.contains(id),
                                          aoTocar: () => l.aoTocar(id),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // fio com losango nas pontas entre uma linha e a outra, como no client
                  if (i < n - 1)
                    FadeTransition(
                      opacity: _curva(i, n),
                      child: _Fio(cor: (l.cor ?? cor)),
                    ),
                ],
              ],
            ),
          ],
        );
        if (!limitada) return trilha;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(height: fatia * partes + fios, child: trilha),
        );
      },
    );
  }
}

/// Fio fino entre as linhas da trilha, com um losango em cada ponta.
class _Fio extends StatelessWidget {
  const _Fio({required this.cor});
  final Color cor;

  static const altura = 7.0;

  @override
  Widget build(BuildContext context) {
    final c = cor.withValues(alpha: 0.4);
    return SizedBox(
      height: altura,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 4),
        child: Row(
          children: [
            Losango(cor: c, tamanho: 5),
            Expanded(child: Container(height: 1, color: c)),
            Losango(cor: c, tamanho: 5),
          ],
        ),
      ),
    );
  }
}

class _BotaoRuna extends StatefulWidget {
  const _BotaoRuna({
    required this.perk,
    required this.cor,
    required this.tamanho,
    required this.pedra,
    required this.escolhida,
    required this.apagada,
    required this.aoTocar,
    this.area,
  });
  final Map perk;
  final Color cor;
  final double tamanho;

  /// Área de toque (a largura que sobra pra ela na linha).
  final double? area;
  final bool pedra;
  final bool escolhida;
  final bool apagada;
  final VoidCallback aoTocar;

  @override
  State<_BotaoRuna> createState() => _BotaoRunaState();
}

class _BotaoRunaState extends State<_BotaoRuna> {
  bool _apertado = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tamanho;
    final sel = widget.escolhida;
    final cor = widget.cor;
    // área de toque de pelo menos 44px, mesmo nos fragmentos
    final area = widget.area ?? math.max(44.0, t + 6);
    return Semantics(
      button: true,
      selected: sel,
      label: '${widget.perk['nome'] ?? 'Runa'}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _apertado = true),
        onTapCancel: () => setState(() => _apertado = false),
        onTapUp: (_) => setState(() => _apertado = false),
        onTap: widget.aoTocar,
        child: SizedBox(
          width: area,
          height: area,
          child: Center(
            child: AnimatedScale(
              scale: _apertado ? 0.9 : (sel && widget.pedra ? 1.08 : 1),
              duration: _dur(context, 160),
              curve: curvaSaida,
              child: AnimatedContainer(
                duration: _dur(context, 220),
                curve: curvaSaida,
                width: t,
                height: t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.pedra ? null : const Color(0xFF050D15),
                  border: widget.pedra
                      ? null
                      : Border.all(
                          color: sel ? cor : Cor.linha2,
                          width: sel ? 2 : 1.5,
                        ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: cor.withValues(
                              alpha: widget.pedra ? 0.45 : 0.3,
                            ),
                            blurRadius: widget.pedra ? 16 : 10,
                          ),
                        ]
                      : const [],
                ),
                clipBehavior: Clip.antiAlias,
                child: _imgRuna(
                  widget.perk['icone'],
                  t,
                  apagada: widget.apagada,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// O que a última runa tocada faz (no client é o balão do mouse; no celular fica fixo no rodapé).
class _InfoRuna extends StatelessWidget {
  const _InfoRuna({required this.arv, required this.id, this.curto = false});
  final _Arvore arv;
  final int? id;

  /// Do lado do botão: sem respiro embaixo e a descrição em 2 linhas.
  final bool curto;

  @override
  Widget build(BuildContext context) {
    final p = id == null ? null : arv.perk(id!);
    return AnimatedSize(
      duration: _dur(context, 220),
      curve: curvaSaida,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: curto ? 0 : 10),
        child: AnimatedSwitcher(
          duration: _dur(context, 200),
          layoutBuilder: (a, antigos) =>
              Stack(alignment: Alignment.topLeft, children: [...antigos, ?a]),
          child: p == null
              ? Text(
                  'Toque numa runa pra ver o que ela faz.',
                  key: ValueKey(0),
                  style: TextStyle(color: Cor.apagado, fontSize: 13.5),
                )
              : Row(
                  key: ValueKey(id),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _imgRuna(p['icone'], 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['nome'] ?? ''}',
                            style: TextStyle(
                              color: Cor.ouroClaro,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                          if ('${p['desc'] ?? ''}'.isNotEmpty)
                            Text(
                              '${p['desc']}',
                              maxLines: curto ? 2 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Cor.apagado,
                                fontSize: 13,
                                height: 1.3,
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
}
