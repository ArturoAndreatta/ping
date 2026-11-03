part of 'main.dart';

/// Abre a folha de criar sala (modo e convites), de trocar o modo ou só de convidar.
Future<void> _abrirSala(
  BuildContext context,
  Conexao con, {
  _Passo passo = _Passo.modo,
  bool trocar = false,
}) {
  final base = con.nav.areaSegura().base;
  som.tocar('abrir');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xB3000000),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: const Duration(milliseconds: 340),
            reverseDuration: const Duration(milliseconds: 240),
            curve: _curvaFolha,
            // fechar comeca rapido e assenta devagar (sem o "arranque" lento da curva ao contrario)
            reverseCurve: _curvaFolha.flipped,
          ),
    builder: (_) =>
        _FolhaSala(con: con, inicio: passo, trocar: trocar, base: base),
  );
}

/// Curva de gaveta do iOS: sai rapido e assenta bem devagar no fim.
const _curvaFolha = Cubic(0.32, 0.72, 0, 1);

enum _Passo { modo, convidar }

class _FolhaSala extends StatefulWidget {
  const _FolhaSala({
    required this.con,
    required this.inicio,
    required this.trocar,
    required this.base,
  });
  final Conexao con;
  final _Passo inicio;
  final bool trocar;
  final double base;

  @override
  State<_FolhaSala> createState() => _FolhaSalaState();
}

class _FolhaSalaState extends State<_FolhaSala> {
  late _Passo _passo = widget.inicio;
  int? _fila;
  String? _grupo;
  final Set<String> _marcados = {};
  bool _criando = false; // mandou criar a sala e está esperando ela abrir
  String? _erro;
  StreamSubscription? _resp;

  /// Só convidar (já está numa sala): não tem o passo do modo.
  bool get _soConvidar => widget.inicio == _Passo.convidar;

  @override
  void initState() {
    super.initState();
    // o LoL recusou criar a sala: volta pro modo com o motivo
    _resp = widget.con.respostas.stream.listen((r) {
      if (!r.ok && _criando && !_salaAberta && mounted) {
        setState(() {
          _criando = false;
          _passo = _Passo.modo;
          _erro = r.msg;
        });
      }
    });
    // trocar modo: abre na aba do modo atual
    final atual = _sala['fila'];
    for (final f in _filas) {
      if (f['id'] == atual) _grupo = '${f['grupo']}';
    }
    SharedPreferences.getInstance().then((p) {
      final f = p.getInt('ultima_fila');
      if (!mounted || f == null || _fila != null) return;
      if (_filas.any((x) => x['id'] == f)) {
        setState(() {
          _fila = f;
          _grupo = '${_filas.firstWhere((x) => x['id'] == f)['grupo']}';
        });
      }
    });
  }

  List<Map> get _filas =>
      ((widget.con.estado['filas'] as List?) ?? const []).cast<Map>();

  Map get _sala => (widget.con.estado['sala'] as Map?) ?? const {};

  /// Quem já está na sala ou já foi convidado não aparece pra marcar de novo.
  Map<String, String> get _ocupados => {
    for (final m in ((_sala['membros'] as List?) ?? const []).cast<Map>())
      '${m['puuid']}': 'Na sala',
    for (final c in ((_sala['convidados'] as List?) ?? const []).cast<Map>())
      '${c['puuid']}': 'Convidado',
  };

  late final _filtro = Filtro(
    widget.con,
    () => [
      widget.con.estado['amigos'],
      widget.con.estado['filas'],
      widget.con.estado['sala'],
      widget.con.fase,
      widget.con.ocupado,
    ],
  );

  @override
  void dispose() {
    _resp?.cancel();
    _filtro.dispose();
    super.dispose();
  }

  bool get _salaAberta =>
      widget.con.fase == 'Lobby' && widget.con.estado['sala'] is Map;

  /// Modo: cria a sala na hora e segue pros amigos. Amigos: convida (ou fecha, sem ninguém marcado).
  void _confirmar() {
    final con = widget.con;
    if (_passo == _Passo.modo) {
      final fila = _fila!;
      SharedPreferences.getInstance().then(
        (p) => p.setInt('ultima_fila', fila),
      );
      con.enviar('criar_sala', {'fila': fila});
      if (widget.trocar) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _criando = true;
        _erro = null;
        _passo = _Passo.convidar;
      });
      return;
    }
    final quem = _marcados.toList();
    Navigator.of(context).pop();
    if (quem.isNotEmpty) con.enviar('convidar', {'quem': quem});
  }

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height;
    return ListenableBuilder(
      listenable: _filtro,
      builder: (context, _) {
        final amigos = ((widget.con.estado['amigos'] as List?) ?? const [])
            .cast<Map>();
        final noModo = _passo == _Passo.modo;
        // camada propria: na subida/descida a folha so e deslocada, nao redesenhada a cada quadro
        return RepaintBoundary(
          child: Container(
            height: math.min(
              alto * 0.84,
              720,
            ), // altura fixa: nao pula ao trocar de aba ou de passo
            decoration: BoxDecoration(
              color: Cor.painel,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              border: Border(top: BorderSide(color: Cor.ouroEscuro)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
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
                _cabecalho(noModo),
                Divider(height: 1, color: Cor.linha),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: _dur(context, 300),
                    switchInCurve: curvaSaida,
                    switchOutCurve: Curves.easeIn,
                    layoutBuilder: (atual, antigos) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...antigos, ?atual],
                    ),
                    transitionBuilder: (c, a) {
                      final indo = c.key == const ValueKey(_Passo.convidar);
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
                    child: noModo
                        ? _Modos(
                            key: const ValueKey(_Passo.modo),
                            filas: _filas,
                            grupo: _grupo,
                            fila: _fila,
                            atual: (_sala['fila'] as num?)?.toInt(),
                            aoGrupo: (g) => setState(() => _grupo = g),
                            aoEscolher: (f) => setState(() => _fila = f),
                          )
                        : _Convites(
                            key: const ValueKey(_Passo.convidar),
                            amigos: amigos,
                            ocupados: _ocupados,
                            marcados: _marcados,
                            aoMarcar: (p) => setState(
                              () => _marcados.contains(p)
                                  ? _marcados.remove(p)
                                  : _marcados.add(p),
                            ),
                            aoMarcarTodos: (ps) => setState(() {
                              final todos = ps.every(_marcados.contains);
                              todos
                                  ? _marcados.removeAll(ps)
                                  : _marcados.addAll(ps);
                            }),
                          ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + widget.base),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Cor.linha)),
                  ),
                  child: _rodape(noModo),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cabecalho(bool noModo) {
    final titulo = noModo
        ? (widget.trocar ? 'TROCAR MODO' : 'CRIAR SALA')
        : (_soConvidar ? 'CONVIDAR AMIGOS' : 'CHAMAR AMIGOS');
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Row(
        children: [
          const SizedBox(width: 44, height: 44), // equilibra o X da direita
          Expanded(
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: _dur(context, 200),
                  child: Text(
                    titulo,
                    key: ValueKey(titulo),
                    style: fonteTitulo(15),
                  ),
                ),
                if (!widget.trocar && !_soConvidar) ...[
                  const SizedBox(height: 6),
                  _Etapas(passo: noModo ? 0 : 1),
                ],
              ],
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

  Widget _rodape(bool noModo) {
    final n = _marcados.length;
    final String texto;
    final bool pode;
    if (noModo) {
      texto = widget.trocar ? 'Trocar modo' : 'Criar sala';
      pode = _fila != null && !(widget.trocar && _fila == _sala['fila']);
    } else if (_criando && !_salaAberta) {
      texto = 'Criando sala...';
      pode = false;
    } else {
      texto = n == 0 ? (_soConvidar ? 'Convidar' : 'Pronto') : 'Convidar ($n)';
      pode = n > 0 || !_soConvidar;
    }
    final nome = _filas.firstWhere(
      (f) => f['id'] == _fila,
      orElse: () => const {},
    )['nome'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: _dur(context, 220),
          curve: curvaSaida,
          child: noModo && _erro != null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Losango(cor: Cor.vermelho, tamanho: 6),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _erro!,
                          style: const TextStyle(
                            color: Cor.vermelho,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : !noModo && !_soConvidar && nome != null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Losango(cor: Cor.ouro, tamanho: 6),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '$nome',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Cor.apagado, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        AnimatedOpacity(
          opacity: pode ? 1 : 0.4,
          duration: _dur(context, 200),
          child: IgnorePointer(
            ignoring: !pode,
            child: Botao(texto: texto, principal: true, aoTocar: _confirmar),
          ),
        ),
      ],
    );
  }
}

/// Dois losangos: modo e amigos.
class _Etapas extends StatelessWidget {
  const _Etapas({required this.passo});
  final int passo;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, t) in ['Modo', 'Amigos'].indexed) ...[
        if (i > 0)
          Container(
            width: 18,
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Cor.linha2,
          ),
        Losango(cor: i <= passo ? Cor.ouro : Cor.linha2, tamanho: 6),
        const SizedBox(width: 6),
        AnimatedDefaultTextStyle(
          duration: _dur(context, 200),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1,
            color: i == passo ? Cor.ouroClaro : Cor.apagado,
          ),
          child: Text(t.toUpperCase()),
        ),
      ],
    ],
  );
}

// ---------------- modo ----------------

class _Modos extends StatelessWidget {
  const _Modos({
    super.key,
    required this.filas,
    required this.grupo,
    required this.fila,
    required this.atual,
    required this.aoGrupo,
    required this.aoEscolher,
  });
  final List<Map> filas;
  final String? grupo;
  final int? fila;
  final int? atual;
  final ValueChanged<String> aoGrupo;
  final ValueChanged<int> aoEscolher;

  @override
  Widget build(BuildContext context) {
    if (filas.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Os modos aparecem quando o LoL estiver aberto.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Cor.apagado, fontSize: 15),
        ),
      );
    }
    final grupos = <String>[];
    for (final f in filas) {
      final g = '${f['grupo']}';
      if (!grupos.contains(g)) grupos.add(g);
    }
    final g = grupos.contains(grupo) ? grupo! : grupos.first;
    final doGrupo = filas.where((f) => f['grupo'] == g).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            physics: const ClampingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            children: [
              for (final x in grupos)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Aba(
                    texto: x,
                    ativo: x == g,
                    aoTocar: () => aoGrupo(x),
                  ),
                ),
            ],
          ),
        ),
        Flexible(
          child: AnimatedSwitcher(
            duration: _dur(context, 220),
            switchInCurve: curvaSaida,
            layoutBuilder: (atual, antigos) => Stack(
              alignment: Alignment.topCenter,
              children: [...antigos, ?atual],
            ),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
            child: ListView.builder(
              physics: const ClampingScrollPhysics(),
              key: ValueKey(g),
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              itemCount: doGrupo.length,
              itemBuilder: (_, i) {
                final f = doGrupo[i];
                final id = (f['id'] as num).toInt();
                return _Modo(
                  nome: '${f['nome']}',
                  escolhido: id == fila,
                  atual: id == atual,
                  aoTocar: () => aoEscolher(id),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Aba extends StatelessWidget {
  const _Aba({required this.texto, required this.ativo, required this.aoTocar});
  final String texto;
  final bool ativo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: ativo,
    child: GestureDetector(
      onTap: aoTocar,
      child: AnimatedContainer(
        duration: _dur(context, 200),
        curve: curvaSaida,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: Raio.r1,
          color: ativo ? const Color(0xFF2A2518) : Cor.painel2,
          border: Border.all(color: ativo ? Cor.ouro : Cor.linha2),
        ),
        child: Text(
          texto.toUpperCase(),
          style: TextStyle(
            fontSize: 12.5,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600,
            color: ativo ? Cor.ouroClaro : Cor.apagado,
          ),
        ),
      ),
    ),
  );
}

class _Modo extends StatelessWidget {
  const _Modo({
    required this.nome,
    required this.escolhido,
    required this.atual,
    required this.aoTocar,
  });
  final String nome;
  final bool escolhido;
  final bool atual;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: escolhido,
    child: GestureDetector(
      onTap: aoTocar,
      child: AnimatedContainer(
        duration: _dur(context, 200),
        curve: curvaSaida,
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: Raio.r1,
          color: escolhido ? const Color(0xFF1E1C15) : Cor.painel2,
          border: Border.all(color: escolhido ? Cor.ouro : Cor.linha2),
          boxShadow: escolhido
              ? [
                  BoxShadow(
                    color: Cor.ouro.withValues(alpha: 0.15),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                nome,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: escolhido ? FontWeight.w600 : FontWeight.w500,
                  color: escolhido ? Cor.ouroClaro : Cor.texto,
                ),
              ),
            ),
            if (atual)
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  'ATUAL',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: Cor.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 10),
            AnimatedScale(
              scale: escolhido ? 1 : 0,
              duration: _dur(context, 220),
              curve: curvaSaida,
              child: Losango(cor: Cor.ouro, tamanho: 8),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------- convites ----------------

class _Convites extends StatelessWidget {
  const _Convites({
    super.key,
    required this.amigos,
    required this.ocupados,
    required this.marcados,
    required this.aoMarcar,
    required this.aoMarcarTodos,
  });
  final List<Map> amigos;
  final Map<String, String> ocupados;
  final Set<String> marcados;
  final ValueChanged<String> aoMarcar;
  final ValueChanged<List<String>> aoMarcarTodos;

  @override
  Widget build(BuildContext context) {
    if (amigos.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(32, 36, 32, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icone(Icons.person_off_outlined, cor: Cor.apagado),
            SizedBox(height: 16),
            Text(
              'Nenhum amigo online no LoL agora.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Cor.apagado, fontSize: 15),
            ),
          ],
        ),
      );
    }
    bool livre(Map a) =>
        a['pode'] == true && !ocupados.containsKey('${a['puuid']}');
    final livres = [
      for (final a in amigos)
        if (livre(a)) '${a['puuid']}',
    ];
    // sem entrada item a item: a troca de passo ja anima, e dobrar animacao travava no celular
    Widget item(Map a) => _Amigo(
      a: a,
      ocupado: ocupados['${a['puuid']}'],
      marcado: marcados.contains('${a['puuid']}'),
      aoTocar: () => aoMarcar('${a['puuid']}'),
    );
    return ListView(
      physics: const ClampingScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      children: [
        _Secao(
          titulo: 'Online agora',
          acao: livres.length > 1
              ? (livres.every(marcados.contains) ? 'Desmarcar' : 'Marcar todos')
              : null,
          aoAcao: () => aoMarcarTodos(livres),
        ),
        for (final a in amigos) item(a),
      ],
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, this.acao, this.aoAcao});
  final String titulo;
  final String? acao;
  final VoidCallback? aoAcao;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            titulo.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              color: Cor.apagado,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (acao != null)
          TextButton(
            onPressed: aoAcao,
            style: TextButton.styleFrom(
              foregroundColor: Cor.ouro,
              minimumSize: const Size(44, 36),
            ),
            child: Text(
              acao!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    ),
  );
}

class _Amigo extends StatelessWidget {
  const _Amigo({
    required this.a,
    required this.ocupado,
    required this.marcado,
    required this.aoTocar,
  });
  final Map a;
  final String? ocupado;
  final bool marcado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final pode = a['pode'] == true && ocupado == null;
    final status = ocupado ?? '${a['status']}';
    final corStatus = ocupado != null
        ? Cor.ouro
        : a['pode'] != true
        ? Cor.apagado
        : (status == 'Disponível' ? Cor.teal : Cor.aviso);
    return Semantics(
      button: pode,
      checked: pode ? marcado : null,
      label: '${a['nome']}, $status',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: pode ? aoTocar : null,
          child: AnimatedOpacity(
            opacity: pode || ocupado != null ? 1 : 0.45,
            duration: _dur(context, 200),
            child: AnimatedContainer(
              duration: _dur(context, 200),
              curve: curvaSaida,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: Raio.r1,
                color: marcado ? const Color(0xFF1E1C15) : Colors.transparent,
                border: Border.all(
                  color: marcado ? Cor.ouroEscuro : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Cor.linha2, width: 1.5),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            _icone((a['icone'] as num?)?.toInt() ?? 0),
                            fit: BoxFit.cover,
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.fallback,
                            errorBuilder: (_, _, _) =>
                                ColoredBox(color: Cor.painel2),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Losango(cor: corStatus, tamanho: 7),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${a['nome']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15.5,
                                ),
                              ),
                              if ('${a['tag'] ?? ''}'.isNotEmpty)
                                TextSpan(
                                  text: ' #${a['tag']}',
                                  style: TextStyle(
                                    color: Cor.apagado,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status,
                          style: TextStyle(color: corStatus, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  if (pode) _Marca(marcado: marcado),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Caixinha de marcar no estilo do client: quadrado com fio dourado.
class _Marca extends StatelessWidget {
  const _Marca({required this.marcado});
  final bool marcado;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: _dur(context, 180),
    curve: curvaSaida,
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      borderRadius: Raio.r1,
      color: marcado ? const Color(0xFF3A3220) : Colors.transparent,
      border: Border.all(color: marcado ? Cor.ouro : Cor.linha2, width: 1.5),
    ),
    child: AnimatedScale(
      scale: marcado ? 1 : 0,
      duration: _dur(context, 180),
      curve: curvaSaida,
      child: Icon(Icons.check, size: 16, color: Cor.ouroClaro),
    ),
  );
}

// ---------------- na tela inicial ----------------

/// Fora de sala: criar sala, com os amigos online que dá pra chamar em destaque.
class _CartaoCriar extends StatelessWidget {
  const _CartaoCriar({required this.con});
  final Conexao con;

  @override
  Widget build(BuildContext context) {
    final amigos = ((con.estado['amigos'] as List?) ?? const []).cast<Map>();
    final livres = amigos.where((a) => a['pode'] == true).toList();
    return _Mensagem(
      icone: const Icone(Icons.groups_2_outlined),
      titulo: 'Tudo parado',
      texto: 'Crie uma sala e chame os amigos daqui mesmo.',
      extra: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: _dur(context, 280),
            curve: curvaSaida,
            child: livres.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _Sugeridos(amigos: livres),
                  ),
          ),
          Botao(
            texto: 'Criar sala',
            principal: true,
            grande: true,
            aoTocar: () => _abrirSala(context, con),
          ),
        ],
      ),
    );
  }
}

/// Rostinhos sobrepostos dos amigos que dá pra chamar agora.
class _Sugeridos extends StatelessWidget {
  const _Sugeridos({required this.amigos});
  final List<Map> amigos;

  @override
  Widget build(BuildContext context) {
    final mostra = amigos.take(5).toList();
    final nomes = amigos.map((a) => '${a['nome']}').toList();
    final texto = nomes.length == 1
        ? '${nomes.first} está online'
        : nomes.length == 2
        ? '${nomes[0]} e ${nomes[1]} estão online'
        : '${nomes[0]} e mais ${nomes.length - 1} amigos estão online';
    return Column(
      children: [
        SizedBox(
          height: 36,
          width: 36.0 + (mostra.length - 1) * 24,
          child: Stack(
            children: [
              for (final (i, a) in mostra.indexed)
                Positioned(
                  left: i * 24,
                  child: Container(
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Cor.painel,
                      border: Border.all(color: Cor.ouro, width: 1.5),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        _icone((a['icone'] as num?)?.toInt() ?? 0),
                        fit: BoxFit.cover,
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: Cor.painel2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(color: Cor.teal, fontSize: 13.5),
        ),
      ],
    );
  }
}
