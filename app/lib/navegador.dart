import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'som.dart';

/// Coisas do navegador que o Flutter não cobre: som do aviso, vibração e o link do QR.
class Navegador {
  /// iPhone só libera som depois de um toque na página: chamar no primeiro toque.
  void liberarSom() => som.liberar();

  /// Aviso que pede atenção (partida encontrada, sua vez): o som do client e vibração no Android. Se o som
  /// ainda não carregou, três bipes subindo.
  void avisar(String nome) {
    try {
      if (!som.tocar(nome) && !som.mudo.value && som.contexto != null) {
        for (var i = 0; i < 3; i++) {
          _bipe(i * 0.18, 660 + i * 220, 0.25);
        }
      }
      web.window.navigator.vibrate(
        [200, 100, 200].map((e) => e.toJS).toList().toJS,
      );
    } catch (_) {}
  }

  void _bipe(double atraso, double freq, double volume) {
    final a = som.contexto!;
    final t = a.currentTime + atraso;
    final osc = a.createOscillator();
    final ganho = a.createGain();
    osc.type = 'triangle';
    osc.frequency.value = freq;
    ganho.gain.setValueAtTime(0, t);
    ganho.gain.linearRampToValueAtTime(volume, t + 0.02);
    ganho.gain.exponentialRampToValueAtTime(0.0001, t + 0.16);
    osc.connect(ganho);
    ganho.connect(a.destination);
    osc.start(t);
    osc.stop(t + 0.18);
  }

  /// Link velho do QR de vínculo (?v=): o vínculo saiu, só tira da barra (entrar é com a conta).
  static void lerLink() {
    if (Uri.base.queryParameters.containsKey('v')) {
      web.window.history.replaceState(null, '', web.window.location.pathname);
    }
  }

  /// Área segura (relógio em cima, home indicator embaixo) lida do CSS: o engine web não repassa ao app.
  /// Deitado, o recorte da câmera fica num dos lados (esq/dir).
  /// Guardada pelo tamanho da janela (só muda ao girar ou redimensionar): getComputedStyle a cada
  /// rebuild podia forçar o navegador a recalcular o estilo no meio de uma animação.
  ({double topo, double base, double esq, double dir}) areaSegura() {
    final tam = '${web.window.innerWidth}x${web.window.innerHeight}';
    final guardada = _area;
    if (guardada != null && _areaTam == tam) return guardada;
    final html = web.document.documentElement;
    if (html == null) return (topo: 0, base: 0, esq: 0, dir: 0);
    final st = web.window.getComputedStyle(html);
    double ler(String n) =>
        double.tryParse(st.getPropertyValue(n).trim().replaceFirst('px', '')) ??
        0;
    final a = (
      topo: ler('--k-safe-top'),
      base: ler('--k-safe-bottom'),
      esq: ler('--k-safe-left'),
      dir: ler('--k-safe-right'),
    );
    // tudo zero pode ser o CSS ainda não aplicado na abertura: só guarda quando já veio algo
    if (a.topo + a.base + a.esq + a.dir > 0) {
      _area = a;
      _areaTam = tam;
    }
    return a;
  }

  ({double topo, double base, double esq, double dir})? _area;
  String? _areaTam;

  /// Tira a tela de abertura do `index.html` (ela espera o app ter o que mostrar, não só o primeiro quadro).
  static bool _abriu = false;
  void tirarAbertura() {
    if (_abriu) return;
    _abriu = true;
    web.window.dispatchEvent(web.Event('ping-pronto'));
  }

  bool get instalado =>
      web.window.matchMedia('(display-mode: standalone)').matches;

  bool get ehIphone => web.window.navigator.userAgent.contains('iPhone');
}
