part of 'conexao.dart';

/// Modo vitrine (`?vitrine=<tela>` no link): o app abre numa tela pronta, com dados de mentira no formato que
/// o PC grava em `ao_vivo/<pc>`, sem Firebase e sem PC. Os comandos mudam o estado aqui mesmo, como o PC
/// responderia. Serve pra mostrar cada tela (demonstração e análise do design).
class ConexaoVitrine extends Conexao {
  ConexaoVitrine(super.nav, this.tela);

  /// Tela pedida no link, ou null fora do modo vitrine. Lida antes do roteador mexer na barra.
  static final String? doLink = () {
    final t = Uri.base.queryParameters['vitrine'];
    return t == null || t.isEmpty ? null : t;
  }();

  /// Telas da vitrine, na ordem do app: (id, nome, grupo).
  static const telas = [
    ('entrar', 'Entrar na conta', 'Começo'),
    ('sem_pc', 'Conta sem PC', 'Começo'),
    ('fechado', 'LoL fechado', 'Começo'),
    ('abrindo', 'Abrindo o LoL', 'Começo'),
    ('fechando', 'Fechando o LoL', 'Começo'),
    ('menu', 'Tudo parado', 'Fora da partida'),
    ('criar_sala', 'Criar sala', 'Fora da partida'),
    ('mensagens', 'Mensagens', 'Fora da partida'),
    ('hoje', 'Aba Hoje', 'Abas'),
    ('mais', 'Aba Mais', 'Abas'),
    ('avisos', 'Avisos no celular', 'Abas'),
    ('temas', 'Tema do app', 'Abas'),
    ('sala', 'Sala com chat', 'Sala e fila'),
    ('fila', 'Na fila', 'Sala e fila'),
    ('partida', 'Partida encontrada', 'Sala e fila'),
    ('carregamento', 'Tela de carregamento', 'Sala e fila'),
    ('jogo', 'Em partida', 'Sala e fila'),
    ('vitoria', 'Vitória', 'Sala e fila'),
    ('derrota', 'Derrota', 'Sala e fila'),
    ('planejamento', 'Planejamento', 'Seleção'),
    ('ban', 'Sua vez de banir', 'Seleção'),
    ('pick', 'Sua vez de escolher', 'Seleção'),
    ('esperando', 'Vez de outro', 'Seleção'),
    ('skins', 'Skins', 'Seleção'),
    ('runas', 'Runas', 'Seleção'),
    ('feiticos', 'Feitiços', 'Seleção'),
    ('troca_pos', 'Troca de posição recebida', 'Seleção'),
    ('troca_ordem', 'Troca de ordem recebida', 'Seleção'),
    ('cartas2', 'Duas cartas', 'ARAM: Desordem'),
    ('cartas3', 'Três cartas', 'ARAM: Desordem'),
    ('banco', 'Banco', 'ARAM: Desordem'),
    ('troca_recebida', 'Troca recebida', 'ARAM: Desordem'),
    ('troca_enviada', 'Troca enviada', 'ARAM: Desordem'),
    ('arena_banir', 'Sua vez de banir', 'Arena 3x6'),
    ('arena_escolher', 'Sua vez de escolher', 'Arena 3x6'),
    ('arena_espera', 'Esperando os outros', 'Arena 3x6'),
    ('arena_carregamento', 'Tela de carregamento', 'Arena 3x6'),
    ('arena_fim', 'Fim com colocação', 'Arena 3x6'),
  ];

  String tela;

  /// Sobe a cada troca de tela: a folha da tela nova abre de novo.
  int rodada = 0;

  /// Troca de tela sem recarregar: o app anima de uma pra outra como no uso de verdade.
  void trocarTela(String nova) {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _esperando = null;
    _liberar();
    erro = null;
    tela = nova;
    rodada++;
    web.window.history.replaceState(
      null,
      '',
      '${web.window.location.pathname}?vitrine=$nova',
    );
    _mostrar();
  }

  /// Folha que abre sozinha depois da tela (runas, feitiços, mensagens, criar sala).
  String? get folha => switch (tela) {
    'runas' => 'runas',
    'feiticos' => 'feiticos',
    'mensagens' => 'mensagens',
    'criar_sala' => 'criar_sala',
    _ => null,
  };

  final _rnd = math.Random();
  final _timers = <Timer>[];
  int _n = 0;
  List<Map> _campeoes = const [];
  List<Map> _feiticosTodos = const [];
  Map? _arvore;

  int get _agora => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<void> iniciar() async {
    pc = 'vitrine';
    final (c, f, r) = await (
      _json('vitrine/campeoes.json'),
      _json('vitrine/feiticos.json'),
      _json('vitrine/runas.json'),
    ).wait;
    _campeoes = c is List ? c.cast<Map>() : const [];
    _feiticosTodos = f is List ? f.cast<Map>() : const [];
    _arvore = r is Map ? r : null;
    // uma página local que mostra o app numa moldura (iframe) troca de tela sem recarregar
    web.window.addEventListener(
      'message',
      ((web.MessageEvent e) {
        // só uma página local manda trocar de tela
        if (!RegExp(
          r'^http://(127\.0\.0\.1|localhost)(:\d+)?$',
        ).hasMatch(e.origin)) {
          return;
        }
        final d = e.data.dartify();
        final id = d is Map ? d['pingVitrine'] : null;
        if (id is String && id != tela && telas.any((t) => t.$1 == id)) {
          trocarTela(id);
        }
      }).toJS,
    );
    _mostrar();
  }

  void _mostrar() {
    if (tela == 'entrar' || tela == 'sem_pc') {
      vinculo = tela == 'entrar' ? Vinculo.sem : Vinculo.semPc;
      email = tela == 'entrar' ? null : 'voce@exemplo.com';
      pcs = {};
      estado = {};
      _aplicado = estado;
      notifyListeners();
      return;
    }
    // as telas do app são sempre com conta (sem conta só a de entrar)
    email = 'voce@exemplo.com';
    if (pcs.isEmpty) {
      pcs = {
        'vitrine': {'nome': 'Voce#BR1', 'pc': 'DESKTOP-CASA', 'desde': 1},
      };
    }
    vinculo = Vinculo.ok;
    _recebeu = true;
    estado = _montar(tela);
    _aplicado = estado;
    if (tela == 'abrindo') _simularAbertura();
    // o relógio anda: o PC "avisa" que está ligado e o prazo da vez e o da partida encontrada recomeçam
    // quando acabam, pra tela ficar parada nela
    _timers.add(Timer.periodic(const Duration(seconds: 1), (_) => _tique()));
    notifyListeners();
  }

  Future<Object?> _json(String caminho) async {
    try {
      final r = await web.window.fetch(caminho.toJS).toDart;
      return jsonDecode((await r.text().toDart).toDart);
    } catch (e) {
      debugPrint('Ping vitrine: sem $caminho: $e');
      return null;
    }
  }

  void _tique() {
    final agora = _agora;
    final sel = estado['selecao'];
    final p = estado['partida'];
    final visto = (estado['visto'] as num?)?.toInt() ?? 0;
    final prazo = sel is Map ? (sel['prazo'] as num?)?.toInt() : null;
    final renova = prazo != null && prazo - agora < 1500;
    final achou =
        p is Map &&
        p['resposta'] == 'None' &&
        agora - ((p['inicio'] as num?)?.toInt() ?? 0) > 11000;
    if (agora - visto < 20000 && !renova && !achou) return;
    _mexer((e) {
      e['visto'] = agora;
      if (renova) {
        e['selecao'] = {
          ...sel,
          'prazo': agora + ((sel['duracao'] as num?)?.toInt() ?? 30000),
        };
      }
      if (achou) e['partida'] = {...p, 'inicio': agora};
    });
  }

  /// Muda o estado como uma gravação do PC: só as chaves trocadas viram instâncias novas.
  void _mexer(void Function(Map<String, dynamic> e) f) {
    final novo = Map<String, dynamic>.from(estado);
    f(novo);
    estado = novo;
    _agendar();
  }

  Timer _depois(int ms, void Function() f) {
    final t = Timer(Duration(milliseconds: ms), f);
    _timers.add(t);
    return t;
  }

  /// Conta Ping de mentira: dois PCs, um com smurf.
  Future<String?> _contaVitrine(String mail, String senha) async {
    if (mail.trim().isEmpty || senha.isEmpty) {
      return 'Preencha o e-mail e a senha.';
    }
    if (senha.length < 6) return 'A senha precisa de pelo menos 6 letras.';
    contaOcupada = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 700));
    email = mail.trim();
    pcs = {
      'pc-casa': {
        'nome': 'Voce#BR1',
        'pc': 'DESKTOP-CASA',
        'lol': {'voce_br1': 'Voce#BR1', 'smurf_br1': 'Smurfzinho#BR1'},
        'desde': 1,
      },
      'pc-note': {
        'nome': 'Voce#BR1',
        'pc': 'NOTEBOOK',
        'lol': {'voce_br1': 'Voce#BR1'},
        'desde': 2,
      },
    };
    pc = 'pc-casa';
    contaOcupada = false;
    // entrou pela tela de entrar: abre o PC como o app de verdade
    if (vinculo != Vinculo.ok) {
      vinculo = Vinculo.ok;
      _recebeu = true;
      estado = _montar('menu');
      _aplicado = estado;
    }
    notifyListeners();
    return null;
  }

  @override
  Future<String?> criarConta(String mail, String senha) =>
      _contaVitrine(mail, senha);

  @override
  Future<String?> entrarConta(String mail, String senha) =>
      _contaVitrine(mail, senha);

  @override
  Future<void> sairConta() async {
    email = null;
    pcs = {};
    vinculo = Vinculo.sem;
    notifyListeners();
  }

  @override
  Future<void> trocarPc(String id) async {
    pc = id;
    notifyListeners();
  }

  @override
  Future<void> tirarPc(String id) async {
    pcs.remove(id);
    notifyListeners();
  }

  @override
  void avisar(String tipo, [Map<String, Object> extra = const {}]) {
    if (tipo != 'dm_lida') return;
    final conv = estado['conversas'];
    final puuid = extra['puuid'];
    if (conv is! Map || conv[puuid] is! Map) return;
    _mexer(
      (e) => e['conversas'] = {
        ...conv,
        '$puuid': {...conv[puuid] as Map, 'nao_lidas': 0},
      },
    );
  }

  @override
  Future<void> enviar(
    String tipo, [
    Map<String, Object> extra = const {},
    String? rotulo,
  ]) async {
    final id = 'vitrine-${++_n}';
    _esperando = id;
    _liberar();
    ocupado = rotulo ?? tipo;
    notifyListeners();
    // o tempo do comando ir e o PC responder
    await Future.delayed(Duration(milliseconds: 350 + _rnd.nextInt(350)));
    if (_esperando != id) return;
    final (ok, msg) = _executar(tipo, extra);
    _mexer(
      (e) => e['resposta'] = {'id': id, 'ok': ok, 'msg': msg, 'em': _agora},
    );
  }

  // ---------------- comandos (o que o PC faria) ----------------

  (bool, String) _executar(String tipo, Map<String, Object> x) {
    final fase = this.fase;
    switch (tipo) {
      case 'aceitar' || 'recusar':
        final p = estado['partida'];
        if (fase != 'ReadyCheck' || p is! Map) return (false, 'O LoL recusou');
        final aceitou = tipo == 'aceitar';
        _mexer(
          (e) => e['partida'] = {
            ...p,
            'resposta': aceitou ? 'Accepted' : 'Declined',
          },
        );
        if (!aceitou) {
          _depois(1500, () => _mexer((e) => _irPara(e, 'Lobby')));
        }
        return (true, aceitou ? 'Partida aceita' : 'Partida recusada');
      case 'buscar':
        _mexer((e) {
          _irPara(e, 'Matchmaking');
          e['fila_inicio'] = _agora;
          e['fila_estimado'] = 95;
        });
        return (true, 'Fila iniciada');
      case 'sair_fila':
        _mexer((e) => _irPara(e, e['sala'] is Map ? 'Lobby' : 'None'));
        return (true, 'Saiu da fila');
      case 'sair_sala' || 'sair_selecao':
        _mexer((e) {
          _irPara(e, 'None');
          e.remove('sala');
          e['filas'] = _filas();
        });
        return (true, tipo == 'sair_sala' ? 'Saiu da sala' : 'Saiu da seleção');
      case 'criar_sala':
        final fila = (x['fila'] as num?)?.toInt() ?? 420;
        final f = _filas().firstWhere(
          (f) => f['id'] == fila,
          orElse: () => _filas().first,
        );
        _mexer((e) {
          _irPara(e, 'Lobby');
          e['fila_nome'] = f['nome'];
          e['sala'] = _sala(
            fila: fila,
            custom: f['custom'] == true,
            sozinho: true,
          );
        });
        return (true, '');
      case 'convidar':
        final sala = estado['sala'];
        if (sala is! Map) return (false, 'Você não está numa sala');
        final quem = (x['quem'] as List?) ?? const [];
        final amigos = ((estado['amigos'] as List?) ?? const []).cast<Map>();
        final novos = [
          for (final a in amigos)
            if (quem.contains(a['puuid']))
              {'nome': a['nome'], 'tag': a['tag'], 'puuid': a['puuid']},
        ];
        _mexer(
          (e) => e['sala'] = {
            ...sala,
            'convidados': [
              ...(sala['convidados'] as List? ?? const []),
              ...novos,
            ],
          },
        );
        return (
          true,
          novos.length == 1 ? 'Convite enviado' : 'Convites enviados',
        );
      case 'posicao':
        // mesma regra do PC (_posicao_sala): a que já está no outro lado troca as duas
        final sala = estado['sala'];
        if (sala is! Map) return (false, 'Você não está numa sala');
        final papel = x['papel'];
        final pos = '${x['pos']}';
        final l = (sala['minhas_pos'] as List?) ?? const ['', ''];
        final atuais = <String>['${l[0]}', '${l[1]}'];
        var n = [...atuais];
        n[papel == 0 ? 0 : 1] = pos;
        if (pos == atuais[papel == 0 ? 1 : 0]) {
          n = [atuais[1], atuais[1] == 'FILL' ? '' : atuais[0]];
        }
        if (n[0] == 'FILL') n[1] = '';
        _mexer(
          (e) => e['sala'] = {
            ...sala,
            'minhas_pos': n,
            'segunda_ok': n[0] != 'FILL',
            'membros': [
              for (final m in (sala['membros'] as List).cast<Map>())
                m['eu'] == true
                    ? {
                        ...m,
                        'pos': [
                          for (final p in n)
                            if (p.isNotEmpty) p,
                        ],
                      }
                    : m,
            ],
          },
        );
        return (true, '');
      case 'chat':
        return _chat('${x['texto'] ?? ''}');
      case 'dm':
        return _dm('${x['puuid'] ?? ''}', '${x['texto'] ?? ''}');
      case 'abrir_lol':
        if (estado['fechando'] == true) {
          return (false, 'Espere o LoL terminar de fechar');
        }
        _simularAbertura();
        return (true, 'Abrindo o LoL');
      case 'fechar_lol':
        _mexer((e) {
          e.removeWhere((k, _) => !_base.contains(k));
          e['fase'] = 'Fechado';
          e['fechando'] = true;
        });
        _depois(2600, () => _mexer((e) => e.remove('fechando')));
        return (true, 'Fechando o LoL');
      case 'campeao':
        return _campeao(
          (x['campeao'] as num?)?.toInt() ?? 0,
          '${x['acao']}',
          x['travar'] == true,
        );
      case 'carta':
        return _carta((x['campeao'] as num?)?.toInt() ?? 0);
      case 'banco':
        return _banco((x['campeao'] as num?)?.toInt() ?? 0);
      case 'skin':
        final sel = estado['selecao'];
        if (sel is! Map) return (false, 'Você não está na seleção');
        _mexer((e) => e['selecao'] = {...sel, 'skin': x['skin']});
        return (true, '');
      case 'feitico':
        return _feitico(
          (x['slot'] as num?)?.toInt() ?? 0,
          (x['feitico'] as num?)?.toInt() ?? 0,
        );
      case 'runa_pagina':
        return _usarPagina((x['pagina'] as num?)?.toInt() ?? 0);
      case 'runa_salvar':
        return _salvarPagina(x);
      case final String t
          when RegExp(
            r'^(troca|pos|ordem)_(pedir|aceitar|recusar|cancelar)$',
          ).hasMatch(t):
        return _troca(tipo, (x['cell'] as num?)?.toInt());
    }
    return (false, 'Comando desconhecido');
  }

  static const _base = {'fase', 'visto', 'resposta'};

  void _irPara(Map<String, dynamic> e, String fase) {
    e['fase'] = fase;
    for (final k in ['partida', 'fila_inicio', 'fila_estimado', 'selecao']) {
      if (fase != 'Matchmaking' || k == 'partida' || k == 'selecao') {
        e.remove(k);
      }
    }
    if (fase == 'None' || fase == 'Lobby') e['filas'] = _filas();
  }

  void _simularAbertura() {
    final inicio = _agora;
    const etapas = [
      ['riot', 2500],
      ['league', 9000],
      ['ux', 1500],
      ['pronto', 4000],
    ];
    _mexer((e) {
      e.removeWhere((k, _) => !_base.contains(k));
      e['fase'] = 'Fechado';
      e['abrindo'] = true;
      e['abertura'] = {
        'inicio': inicio,
        'etapas': etapas,
        'feitas': <String, int>{},
        'estimado': false,
      };
    });
    var t = 0;
    final feitas = <String, int>{};
    for (final et in etapas) {
      t += (et[1] as int) + _rnd.nextInt(900) - 300;
      final nome = et[0] as String;
      _depois(t, () {
        if (estado['abrindo'] != true) return;
        feitas[nome] = _agora;
        if (nome == 'pronto') {
          _mexer((e) {
            e.remove('abrindo');
            e.remove('abertura');
            e['fase'] = 'None';
            e['filas'] = _filas();
            e['amigos'] = _amigos();
            e['conversas'] = _conversas();
          });
          return;
        }
        final ab = estado['abertura'];
        if (ab is Map) {
          _mexer(
            (e) => e['abertura'] = {
              ...ab,
              'feitas': {...feitas},
            },
          );
        }
      });
    }
  }

  (bool, String) _chat(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return (false, 'Mensagem vazia');
    final chave = fase == 'ChampSelect' ? 'selecao' : 'sala';
    final onde = estado[chave];
    if (onde is! Map) return (false, 'Sem chat agora');
    final msg = {
      'tipo': 'msg',
      'texto': t,
      'de': 'Voce',
      'eu': true,
      'id': 'v${++_n}',
      'hora': _agora,
    };
    _mexer(
      (e) => e[chave] = {
        ...onde,
        'chat': [...(onde['chat'] as List? ?? const []), msg],
      },
    );
    return (true, '');
  }

  (bool, String) _dm(String puuid, String texto) {
    final t = texto.trim();
    if (t.isEmpty) return (false, 'Mensagem vazia');
    final conv = Map<String, dynamic>.from(
      (estado['conversas'] as Map?) ?? const {},
    );
    final amigo = ((estado['amigos'] as List?) ?? const [])
        .cast<Map>()
        .where((a) => a['puuid'] == puuid)
        .firstOrNull;
    final antes = conv[puuid] is Map
        ? conv[puuid] as Map
        : {
            'nome': amigo?['nome'] ?? 'Amigo',
            'tag': amigo?['tag'] ?? '',
            'icone': amigo?['icone'] ?? 0,
            'nao_lidas': 0,
            'msgs': const [],
          };
    conv[puuid] = {
      ...antes,
      'msgs': [
        ...(antes['msgs'] as List? ?? const []),
        {'id': 'v${++_n}', 'texto': t, 'hora': _agora, 'eu': true},
      ],
    };
    _mexer((e) => e['conversas'] = conv);
    return (true, '');
  }

  // ---------------- seleção ----------------

  Map get _sel => estado['selecao'] as Map;

  void _mudarSel(Map<String, dynamic> Function(Map<String, dynamic> s) f) {
    final s = jsonDecode(jsonEncode(_sel)) as Map<String, dynamic>;
    final novo = f(s);
    final nomes = Map<String, dynamic>.from(novo['nomes'] as Map? ?? {});
    for (final t in ['meu', 'deles']) {
      for (final m in (novo[t] as List).cast<Map>()) {
        for (final k in ['campeao', 'intencao', 'ban']) {
          final id = (m[k] as num?)?.toInt() ?? 0;
          if (id > 0) nomes['$id'] = _nome(id);
        }
      }
    }
    novo['nomes'] = nomes;
    _mexer((e) {
      e['selecao'] = novo;
      final cid = (novo['skins_de'] as num?)?.toInt() ?? 0;
      if (cid > 0) {
        e['skins'] = _skins(cid);
      } else {
        e.remove('skins');
      }
    });
  }

  Map<String, dynamic> _eu(Map<String, dynamic> s) => (s['meu'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((m) => m['eu'] == true);

  (bool, String) _campeao(int cid, String acao, bool travar) {
    if (estado['selecao'] is! Map) return (false, 'Você não está na seleção');
    if (cid <= 0) return (false, 'Campeão inválido');
    final sel = _sel;
    if (sel['arena'] == true) return _campeaoArena(cid, acao, travar);
    final minhaVez = '${sel['minha_vez'] ?? ''}';
    if (acao == 'ban') {
      if (minhaVez != 'ban') return (false, 'Não é sua vez');
      if (!travar) {
        _mudarSel((s) {
          _eu(s)['campeao'] = cid;
          return s;
        });
        return (true, '');
      }
      _mudarSel((s) {
        final eu = _eu(s);
        eu['campeao'] = 0;
        eu['vez'] = '';
        s['minha_vez'] = '';
        (s['bans'] as Map)['meu'] = [...(s['bans'] as Map)['meu'] as List, cid];
        return s;
      });
      return (true, 'Banido: ${_nome(cid)}');
    }
    if (sel['pick_pendente'] != true) return (false, 'Não é sua vez');
    if (!travar || minhaVez != 'pick') {
      // fora da vez é só intenção; na vez, só marcado
      _mudarSel((s) {
        final eu = _eu(s);
        if (minhaVez == 'pick') {
          eu['campeao'] = cid;
        } else {
          eu['intencao'] = cid;
        }
        return s;
      });
      return (true, '');
    }
    _mudarSel((s) {
      final eu = _eu(s);
      eu
        ..['campeao'] = cid
        ..['intencao'] = 0
        ..['travado'] = true
        ..['vez'] = '';
      s
        ..['minha_vez'] = ''
        ..['pick_pendente'] = false
        ..['skins_de'] = cid
        ..['skin'] = cid * 1000;
      return s;
    });
    return (true, 'Travado: ${_nome(cid)}');
  }

  (bool, String) _carta(int cid) {
    if (estado['selecao'] is! Map) return (false, 'Você não está na seleção');
    final cartas = (_sel['cartas'] as List?) ?? const [];
    if (!cartas.contains(cid)) {
      return (false, 'Essa carta não está mais valendo');
    }
    _mudarSel((s) {
      _eu(s)
        ..['campeao'] = cid
        ..['travado'] = true;
      s
        ..['cartas'] = <int>[]
        ..['skins_de'] = cid
        ..['skin'] = cid * 1000;
      return s;
    });
    return (true, 'Escolheu ${_nome(cid)}');
  }

  (bool, String) _banco(int cid) {
    if (estado['selecao'] is! Map) return (false, 'Você não está na seleção');
    final sel = _sel;
    final banco = ((sel['banco'] as List?) ?? const []).cast<num>();
    if (!banco.contains(cid)) return (false, 'Esse campeão saiu do banco');
    if (sel['banco_ok'] != true) {
      return (false, 'Termine a troca com o aliado antes');
    }
    _mudarSel((s) {
      final eu = _eu(s);
      final antes = (eu['campeao'] as num?)?.toInt() ?? 0;
      s['banco'] = [
        for (final b in banco)
          if (b != cid) b,
        if (antes > 0) antes,
      ];
      eu['campeao'] = cid;
      s
        ..['skins_de'] = cid
        ..['skin'] = cid * 1000;
      return s;
    });
    return (true, 'Pegou ${_nome(cid)}');
  }

  /// Troca com aliado (campeão, posição ou ordem de pick), como o PC responderia: pedir deixa SENT, o resto
  /// volta pra AVAILABLE; aceitar troca o campeão, a posição ou o lugar na ordem.
  (bool, String) _troca(String tipo, int? cell) {
    if (estado['selecao'] is! Map) return (false, 'Você não está na seleção');
    final grupo = tipo.split('_').first;
    final acao = tipo.split('_').last;
    final lista = grupo == 'troca' ? 'trocas' : 'trocas_$grupo';
    final chave = grupo == 'troca' ? 'troca' : 'troca_$grupo';
    final trocas = ((_sel[lista] as List?) ?? const []).cast<Map>();
    final t = trocas.where((t) => t['cell'] == cell).firstOrNull;
    if (t == null) return (false, 'Essa troca não existe mais');
    final precisa = switch (acao) {
      'pedir' => 'AVAILABLE',
      'cancelar' => 'SENT',
      _ => 'RECEIVED',
    };
    if (t['estado'] != precisa) {
      return (false, 'Essa troca não está mais valendo');
    }
    final novoEstado = acao == 'pedir' ? 'SENT' : 'AVAILABLE';
    _mudarSel((s) {
      final meu = (s['meu'] as List).cast<Map<String, dynamic>>();
      if (acao == 'aceitar') {
        final eu = _eu(s);
        final ele = meu.firstWhere((m) => m['cell'] == cell);
        final campo = switch (grupo) {
          'pos' => 'pos',
          'ordem' => 'ordem',
          _ => 'campeao',
        };
        final c = eu[campo];
        eu[campo] = ele[campo];
        ele[campo] = c;
        if (grupo == 'troca') {
          s
            ..['skins_de'] = eu['campeao']
            ..['skin'] = ((eu['campeao'] as num?)?.toInt() ?? 0) * 1000;
        }
        if (grupo == 'pos') s['minha_pos'] = eu['pos'];
      }
      for (final x in (s[lista] as List).cast<Map<String, dynamic>>()) {
        if (x['cell'] == cell) x['estado'] = novoEstado;
      }
      for (final m in meu) {
        if (m['cell'] == cell) m[chave] = novoEstado;
      }
      s['banco_ok'] =
          (s['banco'] as List).isNotEmpty && novoEstado == 'AVAILABLE';
      return s;
    });
    final nome = switch (grupo) {
      'pos' => 'Troca de posição',
      'ordem' => 'Troca de ordem',
      _ => 'Troca',
    };
    return (
      true,
      switch (acao) {
        'pedir' => '$nome pedida',
        'aceitar' => '$nome aceita',
        'recusar' => '$nome recusada',
        _ => 'Pedido cancelado',
      },
    );
  }

  (bool, String) _feitico(int slot, int fid) {
    if (estado['selecao'] is! Map) return (false, 'Você não está na seleção');
    final par = ((_sel['feiticos'] as List?) ?? const [0, 0])
        .map((e) => (e as num).toInt())
        .toList();
    if (slot < 0 || slot > 1) return (false, 'Feitiço inválido');
    if ((estado['selecao'] as Map)['arena'] == true &&
        !{2201, 2202}.contains(fid)) {
      return (false, 'Na Arena só dá pra trocar a ordem dos feitiços');
    }
    if (par[slot] == fid) return (true, '');
    final novo = [...par];
    if (par[1 - slot] == fid) novo[1 - slot] = par[slot];
    novo[slot] = fid;
    _mudarSel((s) => s..['feiticos'] = novo);
    return (true, '');
  }

  (bool, String) _usarPagina(int id) {
    final rn = estado['runas'];
    if (rn is! Map) return (false, 'LoL fechado');
    final pags = (rn['paginas'] as List).cast<Map>();
    if (!pags.any((p) => p['id'] == id)) {
      return (false, 'Página não encontrada');
    }
    _mexer(
      (e) => e['runas'] = {
        ...rn,
        'paginas': [
          for (final p in pags) {...p, 'atual': p['id'] == id},
        ],
      },
    );
    return (true, '');
  }

  (bool, String) _salvarPagina(Map<String, Object> x) {
    final rn = estado['runas'];
    if (rn is! Map) return (false, 'LoL fechado');
    final pags = (rn['paginas'] as List).cast<Map>();
    final perks = (x['perks'] as List?) ?? const [];
    if (perks.length != 9) return (false, 'Página incompleta');
    final id = (x['pagina'] as num?)?.toInt() ?? 0;
    final nova = {
      'id': id > 0 ? id : 9000 + _n++,
      'nome': '${x['nome'] ?? ''}'.trim().isEmpty
          ? 'Página nova'
          : '${x['nome']}'.trim(),
      'prim': x['primaria'],
      'sec': x['secundaria'],
      'perks': perks,
      'atual': true,
      'valida': true,
      'editavel': true,
    };
    final lista = [
      for (final p in pags)
        if (p['id'] == id) nova else {...p, 'atual': false},
      if (id <= 0) nova,
    ];
    _mexer(
      (e) => e['runas'] = {
        ...rn,
        'paginas': lista,
        'pode_criar': lista.length < 5,
      },
    );
    return (true, 'Página salva');
  }

  // ---------------- dados de mentira ----------------

  String _nome(int id) =>
      '${_campeoes.where((c) => c['id'] == id).firstOrNull?['name'] ?? ''}';

  List<Map<String, dynamic>> _filas() => [
    {
      'id': 420,
      'nome': 'Ranqueada Solo/Duo',
      'grupo': "Summoner's Rift",
      'custom': false,
    },
    {
      'id': 440,
      'nome': 'Ranqueada Flexível',
      'grupo': "Summoner's Rift",
      'custom': false,
    },
    {
      'id': 400,
      'nome': 'Escolha Alternada',
      'grupo': "Summoner's Rift",
      'custom': false,
    },
    {
      'id': 490,
      'nome': 'Partida Rápida',
      'grupo': "Summoner's Rift",
      'custom': false,
    },
    {'id': 450, 'nome': 'ARAM', 'grupo': 'ARAM', 'custom': false},
    {'id': 2400, 'nome': 'ARAM: Desordem', 'grupo': 'ARAM', 'custom': false},
    {'id': 1700, 'nome': 'Arena', 'grupo': 'Outros modos', 'custom': false},
    {'id': 870, 'nome': 'Introdução', 'grupo': 'Contra a IA', 'custom': false},
    {
      'id': 880,
      'nome': 'Intermediário',
      'grupo': 'Contra a IA',
      'custom': false,
    },
    {
      'id': 3100,
      'nome': 'Escolha às Cegas',
      'grupo': 'Personalizada',
      'custom': true,
    },
    {
      'id': 3130,
      'nome': 'Escolha Alternada',
      'grupo': 'Personalizada',
      'custom': true,
    },
    {'id': 3140, 'nome': 'Modo de Treino', 'grupo': 'Treino', 'custom': true},
  ];

  static const _gente = [
    ('Ventania', 'BR1', 4568, 'p-ventania'),
    ('Rei do Gank', '777', 5021, 'p-rei'),
    ('Sorte Grande', 'BR1', 4655, 'p-sorte'),
    ('Suporte Fiel', '2024', 5367, 'p-suporte'),
    ('Lua Cheia', 'BR1', 6271, 'p-lua'),
    ('Mão Leve', 'TOP', 4834, 'p-mao'),
    ('Pato Bravo', 'BR1', 3478, 'p-pato'),
  ];

  List<Map<String, dynamic>> _amigos() => [
    for (final (i, g) in _gente.indexed)
      {
        'puuid': g.$4,
        'nome': g.$1,
        'tag': g.$2,
        'icone': g.$3,
        'status': const [
          'Disponível',
          'Na fila',
          'Em partida',
          'Disponível',
          'Ausente',
          'Na seleção',
          'No celular',
        ][i],
        'pode': const [true, true, false, true, true, false, false][i],
      },
  ];

  Map<String, dynamic> _conversas() {
    final h = _agora;
    return {
      'p-ventania': {
        'nome': 'Ventania',
        'tag': 'BR1',
        'icone': 4568,
        'nao_lidas': 2,
        'msgs': [
          {
            'id': 'd1',
            'texto': 'bora uma flex hoje?',
            'hora': h - 3600000,
            'eu': false,
          },
          {
            'id': 'd2',
            'texto': 'bora, lá pelas 21h',
            'hora': h - 3500000,
            'eu': true,
          },
          {'id': 'd3', 'texto': 'fechou', 'hora': h - 240000, 'eu': false},
          {
            'id': 'd4',
            'texto': 'me chama quando abrir a sala',
            'hora': h - 200000,
            'eu': false,
          },
        ],
      },
      'p-suporte': {
        'nome': 'Suporte Fiel',
        'tag': '2024',
        'icone': 5367,
        'nao_lidas': 0,
        'msgs': [
          {
            'id': 'd5',
            'texto': 'gg aquela última',
            'hora': h - 86400000,
            'eu': true,
          },
          {
            'id': 'd6',
            'texto': 'gg! que virada',
            'hora': h - 86000000,
            'eu': false,
          },
        ],
      },
    };
  }

  Map<String, dynamic> _sala({
    int fila = 440,
    bool custom = false,
    bool sozinho = false,
  }) {
    final h = _agora;
    return {
      'membros': [
        {
          'nome': 'Voce',
          'tag': 'BR1',
          'icone': 29,
          'puuid': 'p-eu',
          'lider': true,
          'eu': true,
          'pos': sozinho ? <String>[] : ['MIDDLE', 'TOP'],
        },
        if (!sozinho) ...[
          {
            'nome': 'Ventania',
            'tag': 'BR1',
            'icone': 4568,
            'puuid': 'p-ventania',
            'lider': false,
            'eu': false,
            'pos': ['JUNGLE', 'TOP'],
          },
          {
            'nome': 'Suporte Fiel',
            'tag': '2024',
            'icone': 5367,
            'puuid': 'p-suporte',
            'lider': false,
            'eu': false,
            'pos': ['UTILITY', 'FILL'],
          },
        ],
      ],
      'posicoes': !custom && (fila == 420 || fila == 440 || fila == 400),
      'minhas_pos': sozinho ? ['', ''] : ['MIDDLE', 'TOP'],
      'segunda_ok': true,
      'segunda_opcoes': const [
        'TOP',
        'JUNGLE',
        'MIDDLE',
        'BOTTOM',
        'UTILITY',
        'FILL',
      ],
      'fila': fila,
      'custom': custom,
      'max': 5,
      'convidados': [
        if (!sozinho)
          {'nome': 'Sorte Grande', 'tag': 'BR1', 'puuid': 'p-sorte'},
      ],
      'pode_convidar': true,
      'chat_ok': true,
      'chat': [
        if (!sozinho) ...[
          {
            'tipo': 'aviso',
            'texto': 'Ventania entrou',
            'id': 's1',
            'hora': h - 300000,
          },
          {
            'tipo': 'msg',
            'texto': 'cheguei',
            'de': 'Ventania',
            'eu': false,
            'id': 's2',
            'hora': h - 290000,
          },
          {
            'tipo': 'aviso',
            'texto': 'Suporte Fiel entrou',
            'id': 's3',
            'hora': h - 200000,
          },
          {
            'tipo': 'msg',
            'texto': 'vou de sup hoje',
            'de': 'Suporte Fiel',
            'eu': false,
            'id': 's4',
            'hora': h - 190000,
          },
          {
            'tipo': 'msg',
            'texto': 'fechou, chamei o Sorte também',
            'de': 'Voce',
            'eu': true,
            'id': 's5',
            'hora': h - 120000,
          },
        ],
      ],
    };
  }

  List<Map<String, dynamic>> _feiticosDo(String modo, List<int> atuais) {
    final lst = _feiticosTodos.where((f) {
      final modos = (f['modos'] as List?) ?? const [];
      return modos.isEmpty || modos.contains(modo) || atuais.contains(f['id']);
    }).toList();
    lst.sort(
      (a, b) =>
          '${a['nome']}'.toLowerCase().compareTo('${b['nome']}'.toLowerCase()),
    );
    return [
      for (final f in lst)
        {'id': f['id'], 'nome': f['nome'], 'icone': f['icone']},
    ];
  }

  Map<String, dynamic> _skins(int cid) {
    final nome = _nome(cid);
    // a CDN do CommunityDragon acha a arte pelo número da skin (o caminho do client muda por campeão)
    const cdn = 'https://cdn.communitydragon.org/latest/champion';
    String arte(int n) => '$cdn/$cid/splash-art/centered/skin/$n';
    String mini(int n) => '$cdn/$cid/tile/skin/$n';
    final nomes = cid == 99
        ? const [
            'Feiticeira',
            'Ladra de Feitiços',
            'Comando',
            'Imperial',
            'Legião de Aço',
          ]
        : const ['de Gala', 'Arcana', 'Guardiã Estelar', 'Lunar', 'Prestígio'];
    return {
      'campeao': cid,
      'lista': [
        {
          'id': cid * 1000,
          'nome': nome,
          'tem': true,
          'arte': arte(0),
          'mini': mini(0),
          'chromas': const [],
        },
        for (var n = 1; n <= 5; n++)
          {
            'id': cid * 1000 + n,
            'nome': cid == 99 ? 'Lux ${nomes[n - 1]}' : '$nome ${nomes[n - 1]}',
            'tem': n != 3,
            'arte': arte(n),
            'mini': mini(n),
            // a 2 tem quase todos os chromas, a 4 tem chromas mas nenhum seu
            'chromas': n == 2 || n == 4
                ? [
                    for (final (j, cor) in [
                      '#E8C26A',
                      '#5EC8D8',
                      '#B24CE0',
                      '#E05252',
                    ].indexed)
                      {
                        'id': cid * 1000 + n * 50 + j,
                        'tem': n == 2 && j != 3,
                        'cor': cor,
                      },
                  ]
                : const [],
          },
      ],
    };
  }

  Map<String, dynamic> _runas() => {
    'paginas': [
      {
        'id': 101,
        'nome': 'Ranqueada',
        'prim': 8000,
        'sec': 8400,
        'perks': [8010, 9111, 9104, 8299, 8444, 8451, 5005, 5008, 5011],
        'atual': true,
        'valida': true,
        'editavel': true,
      },
      {
        'id': 102,
        'nome': 'Lux mid',
        'prim': 8200,
        'sec': 8300,
        'perks': [8229, 8226, 8210, 8237, 8345, 8347, 5008, 5008, 5001],
        'atual': false,
        'valida': true,
        'editavel': true,
      },
      {
        'id': 103,
        'nome': 'Selva agressiva',
        'prim': 8100,
        'sec': 8200,
        'perks': [8112, 8143, 8140, 8135, 8226, 8237, 5008, 5008, 5011],
        'atual': false,
        'valida': true,
        'editavel': true,
      },
      {
        'id': 104,
        'nome': 'Recomendada',
        'prim': 8400,
        'sec': 8000,
        'perks': [8437, 8446, 8444, 8451, 9111, 9104, 5005, 5008, 5011],
        'atual': false,
        'valida': true,
        'editavel': false,
      },
    ],
    'pode_criar': true,
  };

  Map<String, dynamic> _grade() {
    var semente = 7;
    int sorteio(int max) =>
        (semente = (semente * 1103515245 + 12345) & 0x7fffffff) % max;
    const fav = ['top', 'jungle', 'middle', 'bottom', 'utility'];
    return {
      'campeoes': [
        for (final c in _campeoes)
          {
            'id': c['id'],
            'm': sorteio(10) < 3 ? sorteio(250000) : sorteio(9000),
            'f': [if (sorteio(12) == 0) fav[sorteio(5)]],
            'p': sorteio(10) < 8,
          },
      ],
      'ordem': 'nome',
    };
  }

  Map<String, dynamic> _comum() => {'visto': _agora, 'hoje': _hoje()};

  /// Resumo do dia no formato do `hoje()` do `ponte.py` no PC: 5 partidas, uma delas remake.
  Map<String, dynamic> _hoje() {
    final h = _agora;
    const min = 60000;
    Map<String, dynamic> j(
      int c,
      bool v,
      int k,
      int d,
      int a,
      int cs,
      int s,
      int antes,
    ) => {
      'campeao': c,
      'vitoria': v,
      'remake': s < 300,
      'k': k,
      'd': d,
      'a': a,
      'cs': cs,
      'duracao': s,
      'quando': h - antes * min,
      'fila': 440,
      'modo': 'CLASSIC',
    };
    return {
      'resumo': {
        'partidas': 4,
        'vitorias': 3,
        'derrotas': 1,
        'kda': 3.62,
        'k': 31,
        'd': 13,
        'a': 16,
        'minutos': 121,
        'mvp': {'id': 103, 'nome': 'Ahri', 'partidas': 2, 'vitorias': 2},
      },
      'jogos': [
        j(103, true, 11, 2, 7, 214, 1712, 38),
        j(157, false, 4, 6, 3, 188, 1960, 75),
        j(103, true, 9, 3, 2, 236, 1844, 112),
        j(266, false, 0, 1, 0, 12, 214, 150),
        j(64, true, 7, 2, 4, 141, 1745, 158),
      ],
      'nomes': {
        '103': 'Ahri',
        '157': 'Yasuo',
        '266': 'Aatrox',
        '64': 'Lee Sin',
      },
    };
  }

  Map<String, dynamic> _cliente(String fase) => {
    ..._comum(),
    'fase': fase,
    'amigos': _amigos(),
    'conversas': _conversas(),
  };

  Map<String, dynamic> _montar(String tela) {
    final h = _agora;
    switch (tela) {
      case 'fechado':
        return {..._comum(), 'fase': 'Fechado', 'riot': true};
      case 'abrindo':
      case 'fechando':
        return {
          ..._comum(),
          'fase': 'Fechado',
          if (tela == 'fechando') 'fechando': true,
        };
      case 'menu' ||
          'criar_sala' ||
          'mensagens' ||
          'hoje' ||
          'mais' ||
          'avisos' ||
          'temas':
        return {..._cliente('None'), 'filas': _filas()};
      case 'sala':
        return {
          ..._cliente('Lobby'),
          'filas': _filas(),
          'fila_nome': 'Ranqueada Flexível',
          'sala': _sala(),
        };
      case 'fila':
        return {
          ..._cliente('Matchmaking'),
          'fila_nome': 'Ranqueada Flexível',
          'sala': _sala(),
          'fila_inicio': h - 74000,
          'fila_estimado': 128,
        };
      case 'partida':
        return {
          ..._cliente('ReadyCheck'),
          'fila_nome': 'Ranqueada Flexível',
          'fila_inicio': h - 151000,
          'partida': {'resposta': 'None', 'estado': 'InProgress', 'inicio': h},
        };
      case 'carregamento':
        return {
          ..._cliente('InProgress'),
          'fila_nome': 'Ranqueada Flexível',
          'jogo': {'carregando': true},
          'carregamento': _carregamento(),
        };
      case 'jogo':
        return {
          ..._cliente('InProgress'),
          'fila_nome': 'Ranqueada Flexível',
          'jogo': {
            'inicio': h - 1102000,
            'modo': 'CLASSIC',
            'mapa': 11,
            'tropas': 65,
            'placar': [14, 9],
            'eu': {
              'campeao': 'Ahri',
              'id': 103,
              'k': 5,
              'd': 2,
              'a': 7,
              'cs': 142,
            },
            'eventos': [
              {'t': 251, 'tipo': 'primeiro_abate', 'lado': 'nos'},
              {'t': 402, 'tipo': 'vastilarvas', 'lado': 'nos'},
              {'t': 611, 'tipo': 'dragao', 'lado': 'eles', 'dragao': 'fire'},
              {'t': 788, 'tipo': 'torre', 'lado': 'nos'},
              {'t': 905, 'tipo': 'arauto', 'lado': 'nos'},
              {'t': 1012, 'tipo': 'dragao', 'lado': 'nos', 'dragao': 'water'},
            ],
          },
        };
      case 'vitoria' || 'derrota':
        final ganhou = tela == 'vitoria';
        return {
          ..._cliente(ganhou ? 'EndOfGame' : 'PreEndOfGame'),
          'fila_nome': 'Ranqueada Flexível',
          'fim': {
            'resultado': tela,
            'duracao': ganhou ? 1843 : 1517,
            'placar': ganhou ? [31, 18] : [12, 27],
            'k': ganhou ? 11 : 3,
            'd': ganhou ? 3 : 8,
            'a': ganhou ? 9 : 4,
            'cs': ganhou ? 231 : 164,
            'campeao': ganhou ? 103 : 86,
            'nome_campeao': ganhou ? 'Ahri' : 'Garen',
            'arte': ganhou
                ? '/lol-game-data/assets/ASSETS/Characters/Ahri/Skins/Base/Images/ahri_splash_centered_0.jpg'
                : '/lol-game-data/assets/ASSETS/Characters/Garen/Skins/Base/Images/garen_splash_centered_0.jpg',
            'fila': 'Ranqueada Flexível',
          },
        };
      case 'arena_banir' || 'arena_escolher' || 'arena_espera':
        return _arena(tela);
      case 'arena_carregamento':
        return {
          ..._cliente('InProgress'),
          'fila_nome': 'Arena 3x6',
          'jogo': {'carregando': true},
          'carregamento': _carregamentoArena(),
        };
      case 'arena_fim':
        return {
          ..._cliente('EndOfGame'),
          'fila_nome': 'Arena 3x6',
          'fim': {
            'resultado': 'vitoria',
            'arena': true,
            'colocacao': 2,
            'duracao': 1264,
            'k': 14,
            'd': 6,
            'a': 9,
            'cs': 38,
            'campeao': 17,
            'nome_campeao': 'Teemo',
            'arte':
                '/lol-game-data/assets/ASSETS/Characters/Teemo/Skins/Base/Images/teemo_splash_centered_0.jpg',
            'fila': 'Arena 3x6',
          },
        };
      case 'cartas2' ||
          'cartas3' ||
          'banco' ||
          'troca_recebida' ||
          'troca_enviada':
        return _desordem(tela);
      default:
        return _draft(tela);
    }
  }

  Map<String, dynamic> _comSelecao(Map<String, dynamic> sel, String modo) {
    final feit = (sel['feiticos'] as List).cast<int>();
    final nomes = <String, String>{};
    void usar(Object? id) {
      if (id is int && id > 0) nomes['$id'] = _nome(id);
    }

    for (final t in ['meu', 'deles']) {
      for (final m in (sel[t] as List).cast<Map>()) {
        usar(m['campeao']);
        usar(m['intencao']);
      }
    }
    for (final l in [
      (sel['bans'] as Map)['meu'],
      (sel['bans'] as Map)['deles'],
      sel['banco'],
      sel['cartas'],
      sel['pickaveis'],
      sel['baniveis'],
    ]) {
      (l as List).forEach(usar);
    }
    sel['nomes'] = nomes;
    final cid = (sel['skins_de'] as num?)?.toInt() ?? 0;
    final desordem = sel['fila'] == 2400;
    return {
      ..._cliente('ChampSelect'),
      'fila_nome': desordem ? 'ARAM: Desordem' : 'Ranqueada Solo/Duo',
      'selecao': sel,
      'grade': _grade(),
      'feiticos': _feiticosDo(modo, feit),
      if (cid > 0) 'skins': _skins(cid),
      if (!desordem && _arvore != null) ...{
        'runas': _runas(),
        'runas_arvore': {
          'estilos': _arvore!['estilos'],
          'perks': _arvore!['perks'],
        },
      },
    };
  }

  List<Map<String, dynamic>> _chatSelecao() {
    final h = _agora;
    return [
      {
        'tipo': 'aviso',
        'texto': 'Você entrou na sala de seleção',
        'id': 'c1',
        'hora': h - 40000,
      },
      {
        'tipo': 'msg',
        'texto': 'mid ou jungle?',
        'de': 'Ventania',
        'eu': false,
        'id': 'c2',
        'hora': h - 30000,
      },
      {
        'tipo': 'msg',
        'texto': 'vou mid',
        'de': 'Voce',
        'eu': true,
        'id': 'c3',
        'hora': h - 25000,
      },
    ];
  }

  Map<String, dynamic> _draft(String tela) {
    final h = _agora;
    final todos = [for (final c in _campeoes) c['id'] as int];
    final grade = (_grade()['campeoes'] as List).cast<Map>();
    final meus = [
      for (final c in grade)
        if (c['p'] == true) c['id'] as int,
    ];
    // troca recebida: no planejamento, Rei do Gank (selva) pede a posição e Suporte Fiel (escolhe por último)
    // pede a ordem
    final pedePos = tela == 'troca_pos';
    final pedeOrdem = tela == 'troca_ordem';
    final plan = tela == 'planejamento' || pedePos || pedeOrdem;
    final ban = tela == 'ban';
    final fim = const {'skins', 'runas', 'feiticos'}.contains(tela);
    final pickando = tela == 'pick';
    // aliados: 0 top, 1 selva, 2 você (meio), 3 atirador, 4 suporte
    const aliados = [
      (266, 'top'),
      (64, 'jungle'),
      (99, 'middle'),
      (222, 'bottom'),
      (412, 'utility'),
    ];
    const inimigos = [
      (86, 'top'),
      (121, 'jungle'),
      (157, 'middle'),
      (51, 'bottom'),
      (89, 'utility'),
    ];
    final picksFeitos = plan || ban ? 0 : (fim ? 5 : (pickando ? 2 : 3));
    final meu = [
      for (final (i, (cid, pos)) in aliados.indexed)
        {
          'cell': i,
          'campeao': i == 2
              ? (fim ? cid : (pickando ? 103 : 0))
              : (i < picksFeitos || (i == 3 && tela == 'esperando') ? cid : 0),
          'intencao': i == 2
              ? (fim || pickando ? 0 : 99)
              : (i >= picksFeitos && !(i == 3 && tela == 'esperando')
                    ? cid
                    : 0),
          'travado': i == 2 ? fim : i < picksFeitos,
          'pos': pos,
          'vez': i == 2 && (ban || pickando)
              ? (ban ? 'ban' : 'pick')
              : (i == 3 && tela == 'esperando' ? 'pick' : ''),
          'eu': i == 2,
          'nome': i == 2 ? 'Voce' : _gente[i < 2 ? i : i - 1].$1,
          'tag': i == 2 ? 'BR1' : _gente[i < 2 ? i : i - 1].$2,
          'ordem': i + 1,
        },
    ];
    // trocas como o PC manda: posição sempre; ordem só com você e o aliado sem travar, fora da finalização
    for (final m in meu) {
      if (m['eu'] == true) continue;
      final cell = m['cell'] as int;
      m['troca_pos'] = pedePos && cell == 1 ? 'RECEIVED' : 'AVAILABLE';
      if (!fim && m['travado'] != true) {
        m['troca_ordem'] = pedeOrdem && cell == 4 ? 'RECEIVED' : 'AVAILABLE';
      }
    }
    List<Map> trocasDe(String chave) => [
      for (final m in meu)
        if (m[chave] != null)
          {
            'cell': m['cell'],
            'id': (chave == 'troca_pos' ? 60 : 80) + (m['cell'] as int),
            'estado': m[chave],
          },
    ];
    final deles = [
      for (final (i, (cid, pos)) in inimigos.indexed)
        {
          'cell': 5 + i,
          'campeao': i < (fim ? 5 : (plan || ban ? 0 : 2)) ? cid : 0,
          'intencao': 0,
          'travado': i < (fim ? 5 : (plan || ban ? 0 : 2)),
          'pos': pos,
          'vez': tela == 'esperando' && i == 2 ? 'pick' : '',
          'eu': false,
        },
    ];
    final sel = <String, dynamic>{
      'fase': plan ? 'PLANNING' : (fim ? 'FINALIZATION' : 'BAN_PICK'),
      'prazo': h + (plan ? 28000 : (fim ? 52000 : 26000)),
      'duracao': plan ? 30000 : (fim ? 60000 : 30000),
      'fila': 420,
      'pode_sair': false,
      'infinito': false,
      'minha_vez': ban ? 'ban' : (pickando ? 'pick' : ''),
      'pick_pendente': !fim,
      'skins_de': fim ? 99 : 0,
      'skin': fim ? 99000 : 0,
      'pickaveis': meus,
      'baniveis': todos,
      'minha_pos': 'middle',
      'meu': meu,
      'deles': deles,
      'bans': plan
          ? {'meu': <int>[], 'deles': <int>[]}
          : ban
          ? {
              'meu': [555, 875],
              'deles': [238, 777, 91],
            }
          : {
              'meu': [555, 875, 141, 245, 11],
              'deles': [238, 777, 91, 360, 147],
            },
      'banco': <int>[],
      'cartas': <int>[],
      'trocas': <Map>[],
      'trocas_pos': trocasDe('troca_pos'),
      'trocas_ordem': trocasDe('troca_ordem'),
      'feiticos': [4, 14],
      'banco_ok': false,
      'chat': _chatSelecao(),
      'chat_ok': true,
    };
    return _comSelecao(sel, 'CLASSIC');
  }

  // ---------------- Arena 3x6 ----------------
  // Formato das capturas reais (fila 1750): 18 em `meu`, `deles` vazio, ban e pick simultâneos, `oculto` pro
  // campeão que o client esconde, `ban`/`ban_travado` por jogador. Sem feitiços, runas, troca nem banco.

  /// Etapa da simulação: banir, escolher ou fim. Só anda depois que você trava a sua ação.
  String _arenaEtapa = 'banir';

  static const _arenaCampeoes = [
    350,
    238,
    102,
    266,
    50,
    233,
    25,
    145,
    893,
    43,
    12,
    117,
    876,
    33,
    32,
    21,
    910,
    950, //
  ];

  Map<String, dynamic> _arena(String tela) {
    final h = _agora;
    final banir = tela == 'arena_banir';
    final escolher = tela == 'arena_escolher';
    final espera = tela == 'arena_espera';
    _arenaEtapa = escolher ? 'escolher' : 'banir';
    const eu = 6;
    // os amigos aparecem com nome; o resto o client manda sem nome
    const visiveis = {1: 0, 7: 1, 12: 2, 15: 4};
    final meu = <Map<String, dynamic>>[];
    for (var i = 0; i < 18; i++) {
      final eVoce = i == eu;
      final g = visiveis[i];
      final bancando = banir || espera;
      // ban: na tela de banir só uns terminaram; esperando, só você e uns poucos; depois todos
      final baniu = bancando
          ? (banir ? (!eVoce && i % 3 != 0) : (eVoce || i % 4 != 1))
          : true;
      final marcou = banir && !eVoce && !baniu && i % 2 == 0;
      final ban = _arenaCampeoes[(i * 7 + 3) % _arenaCampeoes.length];
      // pick: na tela de escolher uns travaram, uns só marcaram e uns estão escondidos
      final travou = escolher && !eVoce && i % 3 == 1;
      final hover = escolher && !eVoce && i % 3 == 2 && i % 2 == 0;
      final oculto = escolher && !eVoce && i % 3 == 2 && i % 2 == 1;
      final cid = _arenaCampeoes[(i * 5 + 1) % _arenaCampeoes.length];
      meu.add({
        'cell': i,
        'campeao': travou || hover ? cid : 0,
        'intencao': 0,
        'travado': travou,
        'pos': '',
        'vez': bancando
            ? (baniu ? '' : 'ban')
            : (escolher && !travou ? 'pick' : ''),
        'eu': eVoce,
        if (eVoce || g != null) 'nome': eVoce ? 'Voce' : _gente[g!].$1,
        if (eVoce || g != null) 'tag': eVoce ? 'BR1' : _gente[g!].$2,
        if (oculto) 'oculto': true,
        'ban': bancando
            ? (baniu || marcou ? (eVoce ? 25 : ban) : 0)
            : (eVoce ? 25 : ban),
        'ban_travado': bancando ? baniu : true,
      });
    }
    final bansFeitos = <int>{
      for (final m in meu)
        if (m['ban_travado'] == true && (m['ban'] as int) > 0) m['ban'] as int,
    }.toList();
    final todos = [for (final c in _campeoes) c['id'] as int];
    final grade = (_grade()['campeoes'] as List).cast<Map>();
    final sel = <String, dynamic>{
      'fase': 'BAN_PICK',
      'prazo': h + (escolher ? 31000 : 17000),
      'duracao': escolher ? 40000 : 25000,
      'fila': 1750,
      'arena': true,
      'pode_sair': false,
      'infinito': false,
      'minha_vez': banir ? 'ban' : (escolher ? 'pick' : ''),
      'pick_pendente': true,
      'skins_de': 0,
      'skin': 0,
      'pickaveis': [
        for (final c in grade)
          if (c['p'] == true) c['id'] as int,
      ],
      'baniveis': todos,
      'minha_pos': '',
      'meu': meu,
      'deles': <Map>[],
      'bans': {'meu': bansFeitos, 'deles': <int>[]},
      'banco': <int>[],
      'cartas': <int>[],
      'trocas': <Map>[],
      'trocas_pos': <Map>[],
      'trocas_ordem': <Map>[],
      'banco_ok': false,
      'feiticos': [2201, 2202],
      'chat': _chatSelecao(),
      'chat_ok': true,
    };
    return _comSelecaoArena(sel);
  }

  Map<String, dynamic> _comSelecaoArena(Map<String, dynamic> sel) {
    final nomes = <String, String>{};
    void usar(Object? id) {
      if (id is int && id > 0) nomes['$id'] = _nome(id);
    }

    for (final m in (sel['meu'] as List).cast<Map>()) {
      usar(m['campeao']);
      usar(m['intencao']);
      usar(m['ban']);
    }
    for (final l in [sel['pickaveis'], sel['baniveis']]) {
      (l as List).forEach(usar);
    }
    sel['nomes'] = nomes;
    final cid = (sel['skins_de'] as num?)?.toInt() ?? 0;
    return {
      ..._cliente('ChampSelect'),
      'fila_nome': 'Arena 3x6',
      'selecao': sel,
      'grade': _grade(),
      // o par da Arena é fixo (Fuga + Flash): a folha só inverte D e F
      'feiticos': _feiticosDo('CHERRY', const [2201, 2202]),
      if (cid > 0) 'skins': _skins(cid),
    };
  }

  /// Banir e escolher na Arena como o PC responderia: marcar não trava, travar fecha a sua ação e os outros 17
  /// vão terminando aos poucos (ban e pick são ao mesmo tempo); fechados os bans abre a escolha.
  (bool, String) _campeaoArena(int cid, String acao, bool travar) {
    final sel = _sel;
    final minhaVez = '${sel['minha_vez'] ?? ''}';
    if (minhaVez != acao) return (false, 'Não é sua vez');
    if (acao == 'ban') {
      _mudarSel((s) {
        final eu = _eu(s);
        eu['ban'] = cid;
        if (travar) {
          eu
            ..['ban_travado'] = true
            ..['vez'] = '';
          s['minha_vez'] = '';
        }
        return s;
      });
      if (travar) _arenaAndar();
      return (true, travar ? 'Banido: ${_nome(cid)}' : '');
    }
    _mudarSel((s) {
      final eu = _eu(s);
      eu['campeao'] = cid;
      if (travar) {
        eu
          ..['travado'] = true
          ..['vez'] = '';
        s
          ..['minha_vez'] = ''
          ..['pick_pendente'] = false
          ..['skins_de'] = cid
          ..['skin'] = cid * 1000;
      }
      return s;
    });
    if (travar) _arenaAndar();
    return (true, travar ? 'Travado: ${_nome(cid)}' : '');
  }

  /// Os outros jogadores terminando a ação deles, um ou dois por vez, até acabar a etapa.
  void _arenaAndar() {
    _depois(1100 + _rnd.nextInt(700), () {
      if (estado['selecao'] is! Map) return;
      final banir = _arenaEtapa == 'banir';
      final acao = banir ? 'ban' : 'pick';
      var seguir = true;
      _mudarSel((s) {
        final meu = (s['meu'] as List).cast<Map<String, dynamic>>();
        final pend = [
          for (final m in meu)
            if (m['vez'] == acao && m['eu'] != true) m,
        ]..shuffle(_rnd);
        for (final m in pend.take(1 + _rnd.nextInt(3))) {
          final id = _arenaCampeoes[_rnd.nextInt(_arenaCampeoes.length)];
          m[banir ? 'ban' : 'campeao'] = id;
          m[banir ? 'ban_travado' : 'travado'] = true;
          m['vez'] = '';
        }
        // sua ação ainda aberta segura a etapa; senão acabou quando ninguém mais tem a vez
        if (!meu.any((m) => m['vez'] == acao)) {
          if (banir) {
            // bans fechados: abre a escolha de todo mundo (40s)
            _arenaEtapa = 'escolher';
            for (final m in meu) {
              m['vez'] = 'pick';
            }
            s
              ..['prazo'] = _agora + 40000
              ..['duracao'] = 40000;
            if (_eu(s)['travado'] != true) s['minha_vez'] = 'pick';
          } else {
            _arenaEtapa = 'fim';
            seguir = false;
            s
              ..['fase'] = 'FINALIZATION'
              ..['prazo'] = _agora + 10000
              ..['duracao'] = 10000;
          }
        }
        return s;
      });
      if (seguir) _arenaAndar();
    });
  }

  Map<String, dynamic> _desordem(String tela) {
    final h = _agora;
    final cartas = tela == 'cartas2' || tela == 'cartas3';
    final pedido = tela == 'troca_enviada'
        ? 'SENT'
        : tela == 'troca_recebida'
        ? 'RECEIVED'
        : null;
    // time de verdade de uma captura de Desordem (ids dos campeões), com nomes de mentira
    const time = [43, 14, 99, 51, 67];
    final meu = [
      for (final (i, cid) in time.indexed)
        {
          'cell': i,
          'campeao': cartas && i == 2 ? 0 : cid,
          'intencao': 0,
          'travado': !(cartas && i == 2),
          'pos': '',
          'vez': '',
          'eu': i == 2,
          'nome': i == 2 ? 'Voce' : _gente[i < 2 ? i : i - 1].$1,
          'tag': i == 2 ? 'BR1' : _gente[i < 2 ? i : i - 1].$2,
          if (i != 2)
            'troca': i == 1 && pedido != null
                ? pedido
                : (cartas ? 'INVALID' : 'AVAILABLE'),
        },
    ];
    final sel = <String, dynamic>{
      'fase': 'BAN_PICK',
      'prazo': h + 48000,
      'duracao': 60000,
      'fila': 2400,
      'pode_sair': false,
      'infinito': false,
      'minha_vez': '',
      'pick_pendente': false,
      'skins_de': cartas ? 0 : 99,
      'skin': cartas ? 0 : 99000,
      'pickaveis': <int>[],
      'baniveis': <int>[],
      'minha_pos': '',
      'meu': meu,
      'deles': [
        for (var i = 0; i < 5; i++)
          {
            'cell': 5 + i,
            'campeao': 0,
            'intencao': 0,
            'travado': false,
            'pos': '',
            'vez': '',
            'eu': false,
          },
      ],
      'bans': {'meu': <int>[], 'deles': <int>[]},
      'banco': [2, 799, 19, 421, 112, 432],
      'cartas': tela == 'cartas3'
          ? [103, 25, 202]
          : tela == 'cartas2'
          ? [103, 25]
          : <int>[],
      'trocas': [
        for (final m in meu)
          if (m['eu'] != true)
            {
              'cell': m['cell'],
              'id': 40 + (m['cell'] as int),
              'estado': m['troca'],
            },
      ],
      'feiticos': [4, 32],
      'banco_ok': !cartas && pedido == null,
      'chat': _chatSelecao(),
      'chat_ok': true,
    };
    return _comSelecao(sel, 'ARAM');
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }
}

/// Tela de carregamento com dez jogadores (nomes inventados, artes reais do CommunityDragon).
Map _carregamento() {
  const f = '/lol-game-data/assets/DATA/Spells/Icons2D/';
  Map j(
    int id,
    String pasta,
    String campeao,
    String nome,
    List<String> feit, {
    String? skin,
    int n = 0,
    String? tier,
    String div = '',
    bool eu = false,
  }) {
    final base =
        '/lol-game-data/assets/ASSETS/Characters/$pasta/Skins/'
        '${n == 0 ? 'Base' : 'Skin${n.toString().padLeft(2, '0')}'}/';
    return {
      'campeao': id,
      'nome_campeao': campeao,
      'nome': nome,
      'tag': 'BR1',
      'tela': '$base${pasta}LoadScreen${n == 0 ? '' : '_$n'}.jpg',
      'arte': '${base}Images/${pasta.toLowerCase()}_splash_centered_$n.jpg',
      'feiticos': [for (final x in feit) '$f$x.png'],
      'skin': ?skin,
      'elo': ?(tier == null ? null : {'tier': tier, 'div': div}),
      if (eu) 'eu': true,
    };
  }

  const flash = 'Summoner_flash', ign = 'SummonerIgnite';
  const smite = 'Summoner_smite', tp = 'Summoner_Teleport_New';
  const heal = 'Summoner_heal', exa = 'Summoner_exhaust';
  return {
    'fila': 'Ranqueada Flexível',
    'times': [
      [
        j(
          164,
          'Camille',
          'Camille',
          'Lâmina Fria',
          [tp, flash],
          tier: 'GOLD',
          div: 'I',
        ),
        j(
          64,
          'LeeSin',
          'Lee Sin',
          'Chute Duplo',
          [smite, flash],
          skin: 'Lee Sin Acólito',
          n: 2,
          tier: 'PLATINUM',
          div: 'IV',
        ),
        j(
          103,
          'Ahri',
          'Ahri',
          'Raposa Noturna',
          [flash, ign],
          skin: 'Ahri Noturna',
          n: 2,
          tier: 'GOLD',
          div: 'II',
          eu: true,
        ),
        j(
          222,
          'Jinx',
          'Jinx',
          'Foguetinho',
          [heal, flash],
          skin: 'Jinx Fogos de Artifício',
          n: 2,
          tier: 'SILVER',
          div: 'I',
        ),
        j(
          89,
          'Leona',
          'Leona',
          'Sol Nascente',
          [flash, ign],
          skin: 'Leona Paladina',
          n: 2,
        ),
      ],
      [
        j(
          122,
          'Darius',
          'Darius',
          'Machado Noxiano',
          [flash, tp],
          tier: 'GOLD',
          div: 'III',
        ),
        j(
          11,
          'MasterYi',
          'Master Yi',
          'Golpe Alfa',
          [smite, flash],
          skin: 'Master Yi, o Escolhido',
          n: 2,
          tier: 'GOLD',
          div: 'IV',
        ),
        j(
          238,
          'Zed',
          'Zed',
          'Sombra Viva',
          [flash, ign],
          skin: 'SKT T1 Zed',
          n: 2,
          tier: 'MASTER',
        ),
        j(
          22,
          'Ashe',
          'Ashe',
          'Flecha Gélida',
          [heal, flash],
          skin: 'Ashe de Sherwood',
          n: 2,
        ),
        j(
          412,
          'Thresh',
          'Thresh',
          'Lanterna Verde',
          [flash, exa],
          skin: 'Thresh Mundial 2013',
          n: 2,
          tier: 'GOLD',
          div: 'II',
        ),
      ],
    ],
  };
}

/// Tela de carregamento da Arena com os 18 jogadores (nomes inventados, artes reais do CommunityDragon).
/// Formato do `carregamento()` do `ponte.py` no PC: uma lista só, você primeiro, sem elo.
Map _carregamentoArena() {
  const f = '/lol-game-data/assets/DATA/Spells/Icons2D/';
  Map j(
    int id,
    String pasta,
    String campeao,
    String nome, {
    bool eu = false,
    int? time,
  }) {
    // a CDN do CommunityDragon acha a arte pelo número da skin (o caminho do client muda por campeão)
    final arte =
        'https://cdn.communitydragon.org/latest/champion/$id/splash-art/centered/skin/0';
    return {
      'campeao': id,
      'nome_campeao': campeao,
      'nome': nome,
      'tag': 'BR1',
      'tela': arte,
      'arte': arte,
      'feiticos': ['${f}Summoner_flash.png', '${f}SummonerIgnite.png'],
      if (eu) 'eu': true,
      'time': ?time,
    };
  }

  return {
    'arena': true,
    'times': [],
    'fila': 'Arena 3x6',
    'jogadores': [
      j(17, 'Teemo', 'Teemo', 'Voce', eu: true, time: 0),
      j(103, 'Ahri', 'Ahri', 'Raposa Noturna', time: 0),
      j(222, 'Jinx', 'Jinx', 'Foguetinho', time: 0),
      j(412, 'Thresh', 'Thresh', 'Lanterna Verde', time: 1),
      j(238, 'Zed', 'Zed', 'Sombra Viva', time: 1),
      j(89, 'Leona', 'Leona', 'Sol Nascente', time: 1),
      j(86, 'Garen', 'Garen', 'Demacia Já', time: 2),
      j(64, 'LeeSin', 'Lee Sin', 'Chute Duplo', time: 2),
      j(99, 'Lux', 'Lux', 'Luz do Dia', time: 2),
      j(122, 'Darius', 'Darius', 'Machado Noxiano'),
      j(22, 'Ashe', 'Ashe', 'Flecha Gélida'),
      j(164, 'Camille', 'Camille', 'Lâmina Fria'),
      j(11, 'MasterYi', 'Master Yi', 'Golpe Alfa'),
      j(81, 'Ezreal', 'Ezreal', 'Explorador'),
      j(25, 'Morgana', 'Morgana', 'Sombra Caída'),
      j(67, 'Vayne', 'Vayne', 'Caçadora Noturna'),
      j(117, 'Lulu', 'Lulu', 'Fada Travessa'),
      j(21, 'MissFortune', 'Miss Fortune', 'Capitã Sorte'),
    ],
  };
}
