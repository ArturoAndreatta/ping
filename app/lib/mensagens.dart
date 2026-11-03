part of 'main.dart';

/// Campo de escrever e o botão de mandar (chat da sala, da seleção e com amigos).
class _CampoMensagem extends StatelessWidget {
  const _CampoMensagem({
    required this.campo,
    required this.aoMandar,
    this.dica = 'Mandar mensagem',
  });
  final TextEditingController campo;
  final VoidCallback aoMandar;
  final String dica;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: campo,
          maxLength: 200,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => aoMandar(),
          style: const TextStyle(fontSize: 15.5),
          cursorColor: Cor.ouro,
          decoration: InputDecoration(
            counterText: '',
            hintText: dica,
            hintStyle: TextStyle(color: Cor.apagado),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF050D15),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
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
      Semantics(
        button: true,
        label: 'Mandar',
        child: SizedBox(
          width: 46,
          height: 46,
          child: IconButton(
            onPressed: aoMandar,
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: Raio.r1,
                side: BorderSide(color: Cor.ouro),
              ),
              backgroundColor: const Color(0xFF2A2518),
            ),
            icon: Icon(Icons.send_rounded, color: Cor.ouroClaro, size: 20),
          ),
        ),
      ),
    ],
  );
}

// ---------------- o que já foi lido ----------------

/// Não lidas de cada conversa: quem manda é o client do PC (`nao_lidas`), então ler lá apaga aqui. Ler aqui
/// avisa o PC (`dm_lida`) e já conta como lida enquanto ele não confirma (até onde foi lida neste celular,
/// hora da última mensagem vista por amigo).
class _Lidas extends ChangeNotifier {
  _Lidas._();
  static final eu = _Lidas._();

  SharedPreferences? _prefs;
  Map<String, int> _ate = {};

  /// Conversa que nunca foi aberta conta desde a primeira vez que o app viu mensagens (senão todo o
  /// histórico antigo do client aparecia como novo).
  int? _desde;

  Future<void> carregar() async {
    if (_prefs != null) return;
    final p = _prefs = await SharedPreferences.getInstance();
    try {
      final j = jsonDecode(p.getString('dm_lidas') ?? '{}');
      if (j is Map) {
        _ate = {
          for (final e in j.entries)
            if (e.value is num) '${e.key}': (e.value as num).toInt(),
        };
      }
    } catch (_) {}
    _desde = p.getInt('dm_desde');
    if (_desde == null) {
      _desde = DateTime.now().millisecondsSinceEpoch;
      await p.setInt('dm_desde', _desde!);
    }
    notifyListeners();
  }

  static int _hora(Map m) => (m['hora'] as num?)?.toInt() ?? 0;

  /// Mensagens do amigo que ainda não foram lidas (nem no PC, nem aqui).
  int naoLidas(String puuid, Map c, List<Map> msgs) {
    if (_prefs == null) return 0;
    final dele = msgs.where((m) => m['eu'] != true);
    final ultima = dele.isEmpty ? 0 : dele.map(_hora).reduce(math.max);
    final ate = _ate[puuid];
    final pc = c['nao_lidas'];
    if (pc is num) {
      // lida aqui depois da última mensagem dele: o PC ainda vai confirmar
      if (ate != null && ate >= ultima) return 0;
      return math.min(pc.toInt(), dele.length);
    }
    // PC sem a contagem (versão antiga): conta pelo que foi visto aqui
    final desde = ate ?? _desde ?? 0;
    return dele.where((m) => _hora(m) > desde).length;
  }

  void marcar(Conexao con, String puuid, Map c, List<Map> msgs) {
    if (msgs.isEmpty || _prefs == null) return;
    final hora = _hora(msgs.last);
    final nova = (_ate[puuid] ?? 0) < hora;
    if (nova) {
      _ate[puuid] = hora;
      _prefs!.setString('dm_lidas', jsonEncode(_ate));
      notifyListeners();
    }
    // o PC ainda conta como não lida: avisa uma vez por mensagem nova
    final pc = c['nao_lidas'];
    if (pc is num && pc > 0 && _avisado[puuid] != hora) {
      _avisado[puuid] = hora;
      con.avisar('dm_lida', {'puuid': puuid});
    }
  }

  final _avisado = <String, int>{};
}

/// Conversas com amigos que o PC mandou, mais recente primeiro.
List<({String puuid, Map c, List<Map> msgs})> _conversas(Conexao con) {
  final v = con.estado['conversas'];
  if (v is! Map) return const [];
  final out = <({String puuid, Map c, List<Map> msgs})>[];
  for (final e in v.entries) {
    if (e.value is! Map) continue;
    final c = e.value as Map;
    final msgs = _lista(c['msgs']);
    if (msgs.isEmpty) continue;
    out.add((puuid: '${e.key}', c: c, msgs: msgs));
  }
  int hora(List<Map> m) => (m.last['hora'] as num?)?.toInt() ?? 0;
  out.sort((a, b) => hora(b.msgs).compareTo(hora(a.msgs)));
  return out;
}

/// Lista gravada no Firebase volta como lista ou como mapa {0: .., 1: ..}.
List<Map> _lista(Object? v) {
  final l = v is List ? v : (v is Map ? v.values.toList() : const []);
  return [for (final x in l) ?x is Map ? x : null];
}

int _totalNaoLidas(Conexao con) {
  var n = 0;
  for (final c in _conversas(con)) {
    n += _Lidas.eu.naoLidas(c.puuid, c.c, c.msgs);
  }
  return n;
}

// ---------------- botão do topo ----------------

/// Abre as mensagens com amigos. Com mensagem nova, um selo dourado com quantas.
class _BotaoMensagens extends StatelessWidget {
  const _BotaoMensagens({required this.con});
  final Conexao con;

  static bool pode(Conexao con) =>
      con.fase != 'Fechado' && con.estado['fechando'] != true;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _Lidas.eu,
    builder: (context, _) {
      final n = _totalNaoLidas(con);
      return SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          tooltip: n > 0 ? 'Mensagens ($n novas)' : 'Mensagens',
          onPressed: () => _abrirMensagens(context, con),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 20,
                color: Cor.ouro,
              ),
              Positioned(
                right: -9,
                top: -7,
                child: AnimatedScale(
                  scale: n > 0 ? 1 : 0,
                  duration: _dur(context, 220),
                  curve: n > 0 ? Curves.easeOutBack : Curves.easeIn,
                  child: _Selo(n: n),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Selo extends StatelessWidget {
  const _Selo({required this.n});
  final int n;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 17),
    height: 17,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Cor.ouro,
      borderRadius: Raio.r1,
      border: Border.all(color: Cor.fundo, width: 1.5),
    ),
    child: Text(
      n > 9 ? '9+' : '$n',
      style: TextStyle(
        color: Cor.fundo,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    ),
  );
}

// ---------------- folha ----------------

Future<void> _abrirMensagens(BuildContext context, Conexao con) {
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
            reverseCurve: _curvaFolha.flipped,
          ),
    builder: (_) => _FolhaMensagens(con: con, base: base),
  );
}

class _FolhaMensagens extends StatefulWidget {
  const _FolhaMensagens({required this.con, required this.base});
  final Conexao con;
  final double base;

  @override
  State<_FolhaMensagens> createState() => _FolhaMensagensState();
}

class _FolhaMensagensState extends State<_FolhaMensagens> {
  late final _filtro = Filtro(
    widget.con,
    () => [
      widget.con.estado['conversas'],
      widget.con.estado['amigos'],
      widget.con.estado['fechando'],
      widget.con.fase,
      widget.con.ocupado,
    ],
  );

  @override
  void dispose() {
    _filtro.dispose();
    super.dispose();
  }

  /// Amigo da conversa aberta (null = lista).
  String? _puuid;

  /// Nome e ícone de quem está aberto, guardados: o amigo pode sair da lista de online no meio.
  Map _quem = const {};

  void _abrir(String puuid, Map quem) {
    som.tocar('clique');
    setState(() {
      _puuid = puuid;
      _quem = quem;
    });
  }

  void _voltar() {
    som.tocar('fechar');
    setState(() => _puuid = null);
  }

  Map? _amigo(String puuid) => _lista(
    widget.con.estado['amigos'],
  ).where((a) => a['puuid'] == puuid).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height;
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    return ListenableBuilder(
      listenable: Listenable.merge([_filtro, _Lidas.eu]),
      builder: (context, _) {
        final puuid = _puuid;
        final aberta = puuid == null
            ? null
            : _conversas(widget.con).where((c) => c.puuid == puuid).firstOrNull;
        final amigo = puuid == null ? null : _amigo(puuid);
        return Padding(
          padding: EdgeInsets.only(bottom: teclado),
          child: RepaintBoundary(
            child: Container(
              // altura fixa (não pula ao trocar de tela); com o teclado aberto, o que sobra
              height: math.max(
                260,
                math.min(math.min(alto * 0.84, 720), alto - teclado - 24),
              ),
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
                  _cabecalho(aberta?.c ?? amigo ?? _quem, amigo),
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
                        final indo = c.key != const ValueKey('lista');
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
                      child: puuid == null
                          ? _ListaConversas(
                              key: const ValueKey('lista'),
                              con: widget.con,
                              aoAbrir: _abrir,
                            )
                          : _Conversa(
                              key: ValueKey('c-$puuid'),
                              con: widget.con,
                              puuid: puuid,
                              nome:
                                  '${(aberta?.c ?? amigo ?? _quem)['nome'] ?? ''}',
                              msgs: aberta?.msgs ?? const [],
                              conversa: aberta?.c ?? const {},
                              base: teclado > 0 ? 0 : widget.base,
                            ),
                    ),
                  ),
                  if (puuid == null) SizedBox(height: widget.base),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cabecalho(Map quem, Map? amigo) {
    final aberta = _puuid != null;
    final status = amigo == null ? 'Offline' : '${amigo['status']}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: AnimatedSwitcher(
              duration: _dur(context, 200),
              child: aberta
                  ? IconButton(
                      key: const ValueKey('voltar'),
                      tooltip: 'Voltar',
                      onPressed: _voltar,
                      icon: Icon(Icons.arrow_back, color: Cor.ouro),
                    )
                  : const SizedBox(key: ValueKey('nada')),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: _dur(context, 200),
              child: aberta
                  ? Column(
                      key: ValueKey('t-$_puuid'),
                      children: [
                        Text(
                          '${quem['nome'] ?? ''}'.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: fonteTitulo(15),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Losango(cor: _corStatus(amigo), tamanho: 6),
                            const SizedBox(width: 6),
                            Text(
                              status,
                              style: TextStyle(
                                color: _corStatus(amigo),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Text(
                      'MENSAGENS',
                      key: const ValueKey('titulo'),
                      textAlign: TextAlign.center,
                      style: fonteTitulo(15),
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

Color _corStatus(Map? amigo) {
  if (amigo == null) return Cor.apagado;
  final s = '${amigo['status']}';
  if (s == 'Disponível') return Cor.teal;
  if (s == 'Ausente' || s == 'Ocupado') return Cor.aviso;
  return Cor.ouro; // em partida, na fila, na seleção
}

/// Conversas recentes e, embaixo, os amigos online pra começar uma.
class _ListaConversas extends StatelessWidget {
  const _ListaConversas({super.key, required this.con, required this.aoAbrir});
  final Conexao con;
  final void Function(String puuid, Map quem) aoAbrir;

  @override
  Widget build(BuildContext context) {
    final convs = _conversas(con);
    final amigos = _lista(con.estado['amigos']);
    final online = {for (final a in amigos) '${a['puuid']}': a};
    final comConversa = {for (final c in convs) c.puuid};
    final outros = amigos
        .where((a) => !comConversa.contains('${a['puuid']}'))
        .toList();
    if (convs.isEmpty && outros.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(32, 40, 32, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icone(Icons.forum_outlined, cor: Cor.apagado),
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
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      children: [
        if (convs.isNotEmpty) ...[
          const _Secao(titulo: 'Conversas'),
          for (final c in convs)
            _LinhaConversa(
              quem: c.c,
              amigo: online[c.puuid],
              ultima: c.msgs.last,
              novas: _Lidas.eu.naoLidas(c.puuid, c.c, c.msgs),
              aoTocar: () => aoAbrir(c.puuid, c.c),
            ),
          const SizedBox(height: 14),
        ],
        if (outros.isNotEmpty) ...[
          const _Secao(titulo: 'Online agora'),
          for (final a in outros)
            _LinhaConversa(
              quem: a,
              amigo: a,
              aoTocar: () => aoAbrir('${a['puuid']}', a),
            ),
        ],
      ],
    );
  }
}

class _LinhaConversa extends StatelessWidget {
  const _LinhaConversa({
    required this.quem,
    required this.amigo,
    required this.aoTocar,
    this.ultima,
    this.novas = 0,
  });
  final Map quem;
  final Map? amigo;
  final Map? ultima;
  final int novas;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cor = _corStatus(amigo);
    final u = ultima;
    final linha2 = u != null
        ? '${u['eu'] == true ? 'Você: ' : ''}${u['texto']}'
        : (amigo == null ? 'Offline' : '${amigo!['status']}');
    final tem = novas > 0;
    return Semantics(
      button: true,
      label: '${quem['nome']}${tem ? ', $novas mensagens novas' : ''}',
      child: ExcludeSemantics(
        child: _Pressionar(
          aoTocar: aoTocar,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: Raio.r1,
              color: tem ? const Color(0xFF1E1C15) : Cor.painel2,
              border: Border.all(color: tem ? Cor.ouroEscuro : Cor.linha),
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
                          _icone((quem['icone'] as num?)?.toInt() ?? 0),
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
                      child: Losango(cor: cor, tamanho: 7),
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
                              text: '${quem['nome']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15.5,
                              ),
                            ),
                            if ('${quem['tag'] ?? ''}'.isNotEmpty)
                              TextSpan(
                                text: ' #${quem['tag']}',
                                style: TextStyle(
                                  color: Cor.apagado,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        linha2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tem
                              ? Cor.ouroClaro
                              : (u != null ? Cor.apagado : cor),
                          fontSize: 13,
                          fontWeight: tem ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (u != null) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _quando((u['hora'] as num?)?.toInt() ?? 0),
                        style: TextStyle(
                          color: tem ? Cor.ouro : Cor.apagado,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedScale(
                        scale: tem ? 1 : 0,
                        duration: _dur(context, 200),
                        curve: curvaSaida,
                        child: _Selo(n: novas),
                      ),
                    ],
                  ),
                ] else
                  Icon(Icons.chevron_right, color: Cor.apagado, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hora de hoje ou dia/mês.
String _quando(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final hoje = DateTime.now();
  String dois(int n) => n.toString().padLeft(2, '0');
  if (d.year == hoje.year && d.month == hoje.month && d.day == hoje.day) {
    return '${dois(d.hour)}:${dois(d.minute)}';
  }
  return '${dois(d.day)}/${dois(d.month)}';
}

/// Afunda de leve ao tocar.
class _Pressionar extends StatefulWidget {
  const _Pressionar({required this.aoTocar, required this.child});
  final VoidCallback aoTocar;
  final Widget child;

  @override
  State<_Pressionar> createState() => _PressionarState();
}

class _PressionarState extends State<_Pressionar> {
  bool _baixo = false;

  void _por(bool v) {
    if (_baixo != v) setState(() => _baixo = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => _por(true),
    onTapUp: (_) => _por(false),
    onTapCancel: () => _por(false),
    onTap: widget.aoTocar,
    child: AnimatedScale(
      scale: _baixo ? 0.98 : 1,
      duration: _dur(context, 120),
      curve: curvaSaida,
      child: widget.child,
    ),
  );
}

/// Uma conversa: mensagens e o campo. O que você mandou aparece na hora, apagado, até o PC confirmar.
class _Conversa extends StatefulWidget {
  const _Conversa({
    super.key,
    required this.con,
    required this.puuid,
    required this.nome,
    required this.msgs,
    required this.conversa,
    required this.base,
  });
  final Conexao con;
  final String puuid;
  final String nome;
  final List<Map> msgs;
  final Map conversa;
  final double base;

  @override
  State<_Conversa> createState() => _ConversaState();
}

class _ConversaState extends State<_Conversa> {
  final _campo = TextEditingController();
  final _pendentes = <({String id, String texto, int hora})>[];
  // id da mensagem real -> id da que estava esperando: ela fica no mesmo lugar e só acende,
  // sem sumir e entrar de novo
  final _herda = <String, String>{};
  StreamSubscription? _resp;
  int _n = 0;

  @override
  void initState() {
    super.initState();
    _resp = widget.con.respostas.stream.listen((r) {
      // o LoL recusou: tira o que estava esperando e devolve o texto pro campo
      if (!r.ok && _pendentes.isNotEmpty && mounted) {
        setState(() {
          if (_campo.text.isEmpty) _campo.text = _pendentes.last.texto;
          _pendentes.clear();
        });
      }
    });
    _marcar();
  }

  @override
  void didUpdateWidget(covariant _Conversa antes) {
    super.didUpdateWidget(antes);
    // a mensagem que você mandou chegou do PC: sai da lista de esperando. Só casa com mensagem sua
    // nova (do envio pra frente): um texto igual a uma antiga não tira a que ainda está esperando
    for (final p in [..._pendentes]) {
      final real = widget.msgs.where((m) {
        final hora = (m['hora'] as num?)?.toInt() ?? 0;
        return m['eu'] == true &&
            '${m['texto']}' == p.texto &&
            hora >= p.hora - 10000 &&
            !_herda.containsKey('${m['id']}');
      }).firstOrNull;
      if (real != null) {
        _herda['${real['id']}'] = p.id;
        _pendentes.remove(p);
      }
    }
    _marcar();
  }

  void _marcar() {
    final msgs = widget.msgs;
    final conversa = widget.conversa;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _Lidas.eu.marcar(widget.con, widget.puuid, conversa, msgs),
    );
  }

  @override
  void dispose() {
    _resp?.cancel();
    _campo.dispose();
    super.dispose();
  }

  void _mandar() {
    var t = _campo.text.trim();
    if (t.isEmpty) return;
    if (t.length > 200) t = t.substring(0, 200);
    widget.con.enviar('dm', {'puuid': widget.puuid, 'texto': t}, 'dm');
    som.tocar('clique');
    setState(() {
      _pendentes.add((
        id: 'p${_n++}',
        texto: t,
        hora: widget.con.agora.millisecondsSinceEpoch,
      ));
      _campo.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final msgs = [
      for (final m in widget.msgs)
        {
          ...m,
          'id': _herda['${m['id']}'] ?? m['id'],
          'tipo': 'msg',
          'de': widget.nome,
        },
      for (final p in _pendentes)
        {
          'id': p.id,
          'tipo': 'msg',
          'texto': p.texto,
          'hora': p.hora,
          'eu': true,
          'esperando': true,
        },
    ];
    final ids = [for (final m in msgs) '${m['id']}'];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + widget.base),
      child: Column(
        children: [
          Expanded(
            child: msgs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icone(Icons.waving_hand_outlined),
                        const SizedBox(height: 14),
                        Text(
                          'Mande a primeira mensagem pra ${widget.nome}.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Cor.apagado, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true, // a mais nova embaixo, a lista acompanha
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    itemCount: msgs.length,
                    findChildIndexCallback: (k) {
                      final i = ids.indexOf((k as ValueKey<String>).value);
                      return i < 0 ? null : msgs.length - 1 - i;
                    },
                    itemBuilder: (_, i) {
                      final m = msgs[msgs.length - 1 - i];
                      return _Entrada(
                        key: ValueKey('${m['id']}'),
                        chave: '${m['id']}',
                        child: AnimatedOpacity(
                          opacity: m['esperando'] == true ? 0.55 : 1,
                          duration: _dur(context, 200),
                          child: _Mensagem2(m: m),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          _CampoMensagem(
            campo: _campo,
            aoMandar: _mandar,
            dica: 'Mensagem pra ${widget.nome}',
          ),
        ],
      ),
    );
  }
}
