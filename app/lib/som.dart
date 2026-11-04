import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Sons do app: os do próprio client do LoL (tirados do CommunityDragon e guardados em `web/sons/` como mp3,
/// porque o Safari do iPhone não toca ogg). Tocados pela Web Audio, que responde na hora e no iPhone
/// funciona depois do primeiro toque na tela (`liberar`). O mudo fica salvo no aparelho.
class Som {
  Som._();
  static final instancia = Som._();

  /// Volume de cada som: os de aviso mais altos, os de clique baixinhos (clique alto cansa).
  static const _volume = {
    'partida': 0.9,
    'aceitou': 0.7,
    'recusou': 0.6,
    'aceitar': 0.6,
    'selecao': 0.55,
    'vez_ban': 0.8,
    'vez_pick': 0.8,
    'travar': 0.7,
    'banir': 0.7,
    'tique': 0.35,
    'grade': 0.3,
    'skin': 0.4,
    'chroma': 0.4,
    'runa': 0.3,
    'fila': 0.6,
    'clique': 0.3,
    'ouro': 0.45,
    'abrir': 0.35,
    'fechar': 0.3,
    'chat': 0.5,
    'entrou': 0.5,
    'saiu': 0.5,
    'sucesso': 0.5,
    'erro': 0.45,
    'troca_recebida': 0.8,
    'troca_aceita': 0.6,
    'troca_recusada': 0.5,
    'troca': 0.4,
    'banco': 0.45,
    'carta': 0.6,
    'cartas_2': 0.55,
    'cartas_3': 0.55,
    'vitoria': 0.8,
    'derrota': 0.7,
    'remake': 0.6,
  };

  web.AudioContext? _ctx;
  final _buffers = <String, web.AudioBuffer>{};
  final _ultimo = <String, int>{};
  bool _carregou = false;

  /// Mudo (botão no topo). Ouvir pra redesenhar o ícone.
  final mudo = ValueNotifier<bool>(_lerMudo());

  static bool _lerMudo() {
    try {
      return web.window.localStorage.getItem('ping-mudo') == '1';
    } catch (_) {
      return false;
    }
  }

  void alternarMudo() {
    mudo.value = !mudo.value;
    try {
      web.window.localStorage.setItem('ping-mudo', mudo.value ? '1' : '0');
    } catch (_) {}
    if (!mudo.value) tocar('clique');
  }

  web.AudioContext? get contexto => _ctx;

  /// O AudioContext que o `web/index.html` cria ao abrir a página (é lá que o toque do iPhone destrava o
  /// som: o Safari só libera no fim do toque, e o Flutter só avisa o começo).
  web.AudioContext? _daPagina() {
    try {
      final a = web.window.getProperty<JSAny?>('pingAudio'.toJS);
      return a == null ? null : a as web.AudioContext;
    } catch (_) {
      return null;
    }
  }

  /// Ao abrir o app: já baixa e decodifica os sons (não precisa de toque pra isso, só pra tocar).
  void iniciar() {
    _ctx ??= _daPagina();
    _carregar();
  }

  /// Chamado no primeiro toque: sem o contexto da página (navegador antigo), cria um aqui.
  void liberar() {
    try {
      _ctx ??= _daPagina() ?? web.AudioContext();
      if (_ctx!.state != 'running') _ctx!.resume();
    } catch (_) {}
    _carregar();
  }

  void _carregar() {
    final a = _ctx;
    if (_carregou || a == null) return;
    _carregou = true;
    for (final nome in _volume.keys) {
      _baixar(a, nome);
    }
  }

  Future<void> _baixar(web.AudioContext a, String nome) async {
    try {
      final r = await web.window.fetch('sons/$nome.mp3'.toJS).toDart;
      if (!r.ok) return;
      final dados = await r.arrayBuffer().toDart;
      _buffers[nome] = await a.decodeAudioData(dados).toDart;
      if (_buffers.length == _volume.length) {
        debugPrint('Ping: ${_buffers.length} sons prontos');
      }
    } catch (e) {
      debugPrint('Ping: som $nome nao carregou: $e');
    }
  }

  /// Toca um som pelo nome (o mesmo do arquivo em `web/sons/`). Devolve false se não tocou (mudo, iPhone
  /// sem toque ainda, ou o arquivo não carregou).
  bool tocar(String nome) {
    if (mudo.value) return false;
    final a = _ctx;
    final b = _buffers[nome];
    if (a == null || b == null) return false;
    // o mesmo som em rajada (dois avisos no mesmo instante) vira um só
    final agora = DateTime.now().millisecondsSinceEpoch;
    if (agora - (_ultimo[nome] ?? 0) < 90) return true;
    _ultimo[nome] = agora;
    try {
      if (a.state == 'suspended') a.resume();
      final src = a.createBufferSource();
      src.buffer = b;
      final g = a.createGain();
      g.gain.value = _volume[nome] ?? 0.5;
      src.connect(g);
      g.connect(a.destination);
      src.start();
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Atalho: `som.tocar('clique')`.
final som = Som.instancia;
