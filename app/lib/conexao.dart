import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'navegador.dart';

part 'vitrine.dart';

/// Mapa do Firebase com chave texto (o Firebase devolve as chaves como `Object?`).
Map<String, dynamic> _mapa(Map v) => {
  for (final e in v.entries) '${e.key}': e.value,
};

/// Tela do começo: sem conta (entrar), conta sem PC, PC aberto ou erro.
enum Vinculo { carregando, sem, semPc, ok, erro }

/// Fala com o PC pelo Realtime Database (o PC grava em `ao_vivo/<pc>`, o celular em `comandos/<pc>`).
class Conexao extends ChangeNotifier {
  Conexao(this.nav);

  final Navegador nav;
  // só pega o Firebase quando usa: no modo vitrine ele nem é inicializado
  late final _db = FirebaseDatabase.instance;
  final _subs = <StreamSubscription>[];
  StreamSubscription? _relogio;
  SharedPreferences? _prefs;

  Vinculo vinculo = Vinculo.carregando;
  String? erro;
  String? pc;

  /// E-mail da conta Ping deste celular (null = sem conta: só a tela de entrar). Os PCs são os que
  /// entraram na mesma conta pelo painel, cada um com as contas do LoL dele.
  String? email;

  /// PCs da conta (`contas/<uid>/pcs`): id do PC -> {nome (Riot ID), pc (nome do PC), lol, desde}.
  Map<String, Map<String, dynamic>> pcs = {};
  StreamSubscription? _contaSub;

  /// Criando conta, entrando ou saindo: os botões da conta esperam.
  bool contaOcupada = false;
  Map<String, dynamic> estado = {};
  int _offset = 0; // diferença entre o relógio do celular e o do servidor
  String? _esperando; // id do último comando enviado
  final respostas = StreamController<({bool ok, String msg})>.broadcast();

  /// Ação esperando o PC (o botão dela mostra que está carregando): da hora que manda até a tela mudar.
  String? ocupado;
  Timer? _soltar;
  String?
  _antes; // retrato do que importa quando o PC respondeu: muda, a ação terminou
  bool esperando(String rotulo) => ocupado == rotulo;

  String _retrato() =>
      '$fase|${estado['partida']}|${estado['sala']}|${estado['selecao']}|${estado['runas']}|${estado['abrindo']}|${estado['fechando']}';

  void _liberar() {
    _soltar?.cancel();
    _antes = null;
    ocupado = null;
  }

  /// O LoL acabou de abrir: a barra de abertura ainda aparece um instante, completando até 100%, antes
  /// da tela seguinte (sem isso ela some no meio, porque o PC já manda a fase nova).
  Map? abriu;
  Timer? _abriuTimer;

  void _verSeAbriu(Map<String, dynamic> antes) {
    final ab = antes['abertura'];
    if (antes['abrindo'] == true &&
        ab is Map &&
        estado['abrindo'] != true &&
        fase != 'Fechado') {
      abriu = ab;
      _abriuTimer?.cancel();
      _abriuTimer = Timer(const Duration(milliseconds: 1100), () {
        abriu = null;
        notifyListeners();
      });
    }
  }

  DateTime get agora => DateTime.now().add(Duration(milliseconds: _offset));

  /// O PC avisa a cada 30s: passou de 75s sem notícia, está desligado ou sem internet.
  bool get pcOnline {
    final v = estado['visto'];
    return v is int &&
        agora.difference(DateTime.fromMillisecondsSinceEpoch(v)).inSeconds < 75;
  }

  String get fase => (estado['fase'] as String?) ?? 'Fechado';

  /// Já dá pra mostrar o app: sabe se tem conta e, com PC aberto, já leu o estado dele uma vez.
  bool _recebeu = false;
  bool get pronto =>
      vinculo != Vinculo.carregando && (vinculo != Vinculo.ok || _recebeu);

  Future<void> iniciar() async {
    try {
      final auth = FirebaseAuth.instance;
      var user = await auth.authStateChanges().first;
      // só conta com e-mail e senha mexe no app (anônimo que sobrou sai)
      if (user != null && user.isAnonymous) {
        await auth.signOut();
        user = null;
      }
      email = user?.email;
      _relogio = _db.ref('.info/serverTimeOffset').onValue.listen((e) {
        _offset = (e.snapshot.value as num?)?.toInt() ?? 0;
      });
      _prefs = await SharedPreferences.getInstance();
      if (user == null) {
        vinculo = Vinculo.sem;
        notifyListeners();
        return;
      }
      await _abrirConta();
    } catch (e) {
      debugPrint("Ping: falha ao conectar: $e");
      vinculo = Vinculo.erro;
      erro = 'Não consegui conectar. Confira a internet e abra de novo.';
      notifyListeners();
    }
  }

  String? _atualConta;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static Map<String, Map<String, dynamic>> _pcsDe(Object? v) => {
    if (v is Map)
      for (final e in v.entries)
        if (e.value is Map) '${e.key}': _mapa(e.value as Map),
  };

  /// Logou (abriu o app, criou a conta ou entrou): lê a conta e abre um PC dela.
  Future<void> _abrirConta() async {
    final v = (await _db.ref('contas/$_uid').get()).value;
    final m = v is Map ? _mapa(v) : <String, dynamic>{};
    pcs = _pcsDe(m['pcs']);
    _atualConta = m['atual'] is String ? m['atual'] as String : null;
    _ouvirConta();
    _abrirPc();
  }

  void _ouvirConta() {
    _contaSub?.cancel();
    if (email == null) return;
    // PC entrou na conta pelo painel ou saiu dela: abre ele (ou outro) na hora
    _contaSub = _db.ref('contas/$_uid/pcs').onValue.listen((e) {
      pcs = _pcsDe(e.snapshot.value);
      _abrirPc();
    }, onError: (_) {});
  }

  /// Escolhe a tela: conta sem PC ou o PC (o aberto se ainda está na conta, senão o último usado
  /// neste aparelho, o último usado na conta ou o primeiro).
  void _abrirPc() {
    final prefs = _prefs;
    if (prefs == null || email == null) return;
    final local = pc ?? prefs.getString('pc');
    final atual = _atualConta;
    final p = local != null && pcs.containsKey(local)
        ? local
        : atual != null && pcs.containsKey(atual)
        ? atual
        : (pcs.keys.isEmpty ? null : pcs.keys.first);
    if (p == null) {
      _pararPc();
      pc = null;
      prefs.remove('pc');
      erro = null;
      vinculo = Vinculo.semPc;
      notifyListeners();
      return;
    }
    if (p == pc && vinculo == Vinculo.ok) {
      notifyListeners();
      return;
    }
    pc = p;
    prefs.setString('pc', p);
    _ouvir(prefs);
  }

  /// O PC conta qual Riot ID está logado (`conta_lol`) e o nome dele (`pc_nome`): a lista da conta guarda
  /// pra mostrar as contas do LoL (smurfs) de cada PC. Grava só quando muda.
  String? _quemGravado;
  void _guardarQuem() {
    final p = pc;
    if (email == null || p == null) return;
    final rid = estado['conta_lol'], nome = estado['pc_nome'];
    final atual = pcs[p] ?? const {};
    final lol = atual['lol'] is Map ? atual['lol'] as Map : const {};
    final patch = <String, Object>{};
    if (rid is String && rid.isNotEmpty) {
      final k = rid.toLowerCase().replaceAll(RegExp(r'[.#$\[\]/\s]+'), '_');
      if (atual['nome'] != rid) patch['nome'] = rid;
      if (lol[k] != rid) patch['lol/$k'] = rid;
    }
    if (nome is String && nome.isNotEmpty && atual['pc'] != nome) {
      patch['pc'] = nome;
    }
    if (atual['desde'] == null) patch['desde'] = ServerValue.timestamp;
    final marca = '$p|$patch';
    if (patch.isEmpty || marca == _quemGravado) return;
    _quemGravado = marca;
    _db.ref('contas/$_uid/pcs/$p').update(patch).catchError((_) {});
  }

  /// App na tela: avisa o PC a cada 20s (`olhando`) que você está acompanhando pelo celular, e o PC não
  /// manda aviso push enquanto isso. Fechou ou minimizou, avisa na hora.
  Timer? _pulsoTimer;
  void _vigiarTela() {
    if (_pulsoTimer != null) return;
    _pulsoTimer = Timer.periodic(const Duration(seconds: 20), (_) => _pulso());
    void mudou(web.Event _) {
      if (web.document.visibilityState == 'visible') {
        _pulso();
      } else {
        avisar('olhando', {'valor': false});
      }
    }

    web.document.addEventListener('visibilitychange', mudou.toJS);
    web.window.addEventListener(
      'pagehide',
      ((web.Event _) => avisar('olhando', {'valor': false})).toJS,
    );
  }

  void _pulso() {
    if (vinculo != Vinculo.ok || web.document.visibilityState != 'visible') {
      return;
    }
    avisar('olhando', {'valor': true});
  }

  /// Para de ouvir o PC aberto (trocar de PC, perder o acesso): o estado dele some da tela.
  void _pararPc() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    estado = {};
    _aplicado = {};
    _recebeu = false;
    _liberar();
  }

  void _ouvir(SharedPreferences prefs) {
    _pararPc();
    erro = null;
    vinculo = Vinculo.ok;
    notifyListeners();
    _vigiarTela();
    _pulso();
    // filho a filho: cada gravação do PC converte só a chave que mudou (a grade, as runas e as conversas
    // não vêm de novo a cada segundo do relógio) e o que não mudou mantém a mesma instância (`identical`)
    final vivo = _db.ref('ao_vivo/$pc');
    void filho(DatabaseEvent e, {bool saiu = false}) {
      final k = e.snapshot.key;
      if (k == null) return;
      final novo = Map<String, dynamic>.from(estado);
      if (saiu) {
        novo.remove(k);
      } else {
        novo[k] = e.snapshot.value;
      }
      estado = novo;
      _agendar();
    }

    // recusado pelas regras: o PC saiu da conta
    void falhou(Object _) => _perdeuAcesso();
    _subs.addAll([
      vivo.onChildAdded.listen(filho, onError: falhou),
      vivo.onChildChanged.listen(filho, onError: falhou),
      vivo.onChildRemoved.listen((e) => filho(e, saiu: true), onError: falhou),
    ]);
    // nó vazio não dispara filho nenhum: a primeira leitura diz que já recebeu
    vivo.get().then((_) {
      if (!_recebeu) _agendar();
    }, onError: (_) {});
  }

  // vários filhos de uma gravação chegam juntos: aplica uma vez só
  bool _agendado = false;
  Map<String, dynamic> _aplicado = {};
  void _agendar() {
    if (_agendado) return;
    _agendado = true;
    scheduleMicrotask(_aplicar);
  }

  void _aplicar() {
    _agendado = false;
    if (vinculo != Vinculo.ok) return;
    final antes = _aplicado;
    _aplicado = estado;
    _verSeAbriu(antes);
    _recebeu = true;
    _guardarQuem();
    final r = estado['resposta'];
    if (_antes != null && _retrato() != _antes) _liberar();
    if (r is Map && r['id'] == _esperando) {
      _esperando = null;
      final ok = r['ok'] == true;
      respostas.add((ok: ok, msg: '${r['msg'] ?? ''}'));
      if (ok) {
        // deu certo: segue carregando até a tela mudar (no máximo 3s)
        _antes = _retrato();
        _soltar?.cancel();
        _soltar = Timer(const Duration(seconds: 3), () {
          _liberar();
          notifyListeners();
        });
      } else {
        _liberar();
      }
    }
    notifyListeners();
  }

  /// O banco recusou o PC aberto: o PC saiu da conta (Sair da conta no painel). Sai da lista e abre
  /// outro dela, se tiver.
  Future<void> _perdeuAcesso() async {
    if (vinculo != Vinculo.ok) return;
    final saiu = pc;
    _pararPc();
    if (saiu != null) {
      pcs.remove(saiu);
      _db.ref('contas/$_uid/pcs/$saiu').remove().catchError((_) {});
    }
    pc = null;
    _abrirPc();
  }

  // ---------------- conta Ping ----------------

  Future<T?> _naConta<T>(Future<T> Function() f) async {
    if (contaOcupada) return null;
    contaOcupada = true;
    notifyListeners();
    try {
      return await f();
    } finally {
      contaOcupada = false;
      notifyListeners();
    }
  }

  static String _erroConta(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'email-already-in-use' || 'credential-already-in-use' =>
          'Esse e-mail já tem conta. Toque em Entrar.',
        'invalid-email' => 'Esse e-mail não parece certo.',
        'weak-password' => 'A senha precisa de pelo menos 6 letras.',
        'too-many-requests' => 'Muitas tentativas. Espere um pouco.',
        'network-request-failed' => 'Sem internet.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' => 'E-mail ou senha errados.',
        _ => 'Não deu certo. Tente de novo.',
      };
    }
    return 'Não deu certo. Confira a internet.';
  }

  /// Cria a conta ou entra numa que já existe e abre os PCs dela. Devolve o erro, ou null.
  Future<String?> _logar(
    String mail,
    String senha, {
    required bool criar,
  }) async => await _naConta<String?>(() async {
    if (mail.trim().isEmpty || senha.isEmpty) {
      return 'Preencha o e-mail e a senha.';
    }
    final auth = FirebaseAuth.instance;
    try {
      if (criar) {
        await auth.createUserWithEmailAndPassword(
          email: mail.trim(),
          password: senha,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: mail.trim(),
          password: senha,
        );
      }
    } catch (e) {
      debugPrint('Ping: ${criar ? 'criar conta' : 'entrar na conta'}: $e');
      return _erroConta(e);
    }
    email = mail.trim();
    _quemGravado = null;
    erro = null;
    try {
      await _abrirConta();
    } catch (e) {
      debugPrint('Ping: abrir a conta: $e');
      vinculo = Vinculo.erro;
      erro = 'Não consegui abrir a conta. Confira a internet.';
    }
    return null;
  });

  Future<String?> criarConta(String mail, String senha) =>
      _logar(mail, senha, criar: true);

  Future<String?> entrarConta(String mail, String senha) =>
      _logar(mail, senha, criar: false);

  /// Sai da conta neste celular: volta pra tela de entrar (os PCs continuam na conta).
  Future<void> sairConta() async => await _naConta(() async {
    _contaSub?.cancel();
    _contaSub = null;
    _pararPc();
    await FirebaseAuth.instance.signOut();
    email = null;
    pcs = {};
    _quemGravado = null;
    await _prefs?.remove('pc');
    pc = null;
    erro = null;
    vinculo = Vinculo.sem;
  });

  /// Abre outro PC da conta.
  Future<void> trocarPc(String id) async {
    final prefs = _prefs;
    if (prefs == null || id == pc || !pcs.containsKey(id)) return;
    pc = id;
    await prefs.setString('pc', id);
    _db.ref('contas/$_uid/atual').set(id).catchError((_) {});
    _ouvir(prefs);
  }

  /// Tira um PC da lista da conta (volta quando o painel dele entrar na conta de novo).
  Future<void> tirarPc(String id) async {
    try {
      await _db.ref('contas/$_uid/pcs/$id').remove();
    } catch (e) {
      debugPrint('Ping: tirar PC: $e');
    }
    pcs.remove(id);
    if (id == pc) pc = null;
    _abrirPc();
  }

  /// Comando que o app manda sozinho, sem botão esperando: não carrega nada e o PC não responde.
  void avisar(String tipo, [Map<String, Object> extra = const {}]) {
    if (pc == null) return;
    _db
        .ref('comandos/$pc')
        .push()
        .set({
          ...extra,
          'tipo': tipo,
          'em': ServerValue.timestamp,
          'de': FirebaseAuth.instance.currentUser!.uid,
        })
        .catchError((_) {});
  }

  /// [rotulo] diz qual botão fica carregando (padrão: o próprio tipo).
  Future<void> enviar(
    String tipo, [
    Map<String, Object> extra = const {},
    String? rotulo,
  ]) async {
    final ref = _db.ref('comandos/$pc').push();
    _esperando = ref.key;
    _liberar();
    ocupado = rotulo ?? tipo;
    notifyListeners();
    try {
      await ref.set({
        ...extra,
        'tipo': tipo,
        'em': ServerValue.timestamp,
        'de': FirebaseAuth.instance.currentUser!.uid,
      });
    } catch (_) {
      _esperando = null;
      _liberar();
      notifyListeners();
      respostas.add((
        ok: false,
        msg: 'Não consegui mandar. Confira a internet.',
      ));
      return;
    }
    // sem resposta do PC em 8s: avisa
    final id = ref.key;
    Future.delayed(const Duration(seconds: 8), () {
      if (_esperando == id) {
        _esperando = null;
        _liberar();
        notifyListeners();
        respostas.add((ok: false, msg: 'O PC não respondeu.'));
      }
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    _contaSub?.cancel();
    _soltar?.cancel();
    _abriuTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    respostas.close();
    super.dispose();
  }
}
