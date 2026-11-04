// Aviso de versão nova (skill aviso-nova-versao, caminho A, montagem acima do Navigator).
//
// Quem descobre a versão nova é o service worker: o script em web/index.html confere a cada 30s (e ao voltar
// pra aba) e marca/emite ping-update-found (achou, baixando) e ping-update-ready (baixou e assumiu).
// O pop-up é obrigatório: um botão só, "Atualizar agora"; tocar fora não fecha.

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'tema.dart';

/// Os nomes são combinados com o script do web/index.html: mudar um lado sem o outro faz o aviso sumir calado.
const _marcaAchou = 'pingUpdateFound';
const _eventoAchou = 'ping-update-found';
const _marcaPronto = 'pingUpdateReady';
const _eventoPronto = 'ping-update-ready';

/// Quanto o botão espera o download antes de liberar de qualquer jeito.
const _paciencia = Duration(seconds: 20);

bool _marca(String nome) {
  final v = globalContext.getProperty<JSAny?>(nome.toJS);
  return v.isA<JSBoolean>() && (v as JSBoolean).toDart;
}

Stream<void> _evento(String nome) {
  late final StreamController<void> c;
  final cb = ((web.Event _) => c.add(null)).toJS;
  c = StreamController<void>.broadcast(
    onListen: () => web.window.addEventListener(nome, cb),
    onCancel: () => web.window.removeEventListener(nome, cb),
  );
  return c.stream;
}

/// Cobre o app inteiro (vai no builder do MaterialApp).
class AvisoVersaoNova extends StatefulWidget {
  const AvisoVersaoNova({required this.child, super.key});
  final Widget child;

  @override
  State<AvisoVersaoNova> createState() => _AvisoVersaoNovaState();
}

class _AvisoVersaoNovaState extends State<AvisoVersaoNova> {
  bool _achou = false;
  bool _pronto = false;
  bool _cansou = false;
  bool _recarregando = false;
  Timer? _espera;
  final _subs = <StreamSubscription<void>>[];

  @override
  void initState() {
    super.initState();
    // o evento pode ter chegado antes deste widget existir: lê as marcas
    if (_marca(_marcaPronto)) {
      _achou = _pronto = true;
    } else if (_marca(_marcaAchou)) {
      _marcarAchou();
    }
    _subs
      ..add(_evento(_eventoAchou).listen((_) => setState(_marcarAchou)))
      ..add(
        _evento(_eventoPronto).listen((_) {
          setState(() => _achou = _pronto = true);
        }),
      );
  }

  void _marcarAchou() {
    if (_achou) return;
    _achou = true;
    _espera = Timer(_paciencia, () {
      if (mounted) setState(() => _cansou = true);
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _espera?.cancel();
    super.dispose();
  }

  void _recarregar() {
    setState(() => _recarregando = true);
    web.window.location.reload();
  }

  @override
  Widget build(BuildContext context) {
    final mov = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 320);
    return Overlay.wrap(
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          AnimatedSwitcher(
            duration: mov,
            switchInCurve: curvaSaida,
            switchOutCurve: Curves.easeIn,
            child: _achou
                ? _Janela(
                    key: const ValueKey('versao-nova'),
                    ocupado: (!_pronto && !_cansou) || _recarregando,
                    mov: mov,
                    aoTocar: _recarregar,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _Janela extends StatelessWidget {
  const _Janela({
    required this.ocupado,
    required this.mov,
    required this.aoTocar,
    super.key,
  });
  final bool ocupado;
  final Duration mov;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      BlockSemantics(
        child: ModalBarrier(
          color: Cor.fundo.withValues(alpha: 0.8),
          dismissible: false,
        ),
      ),
      SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.92, end: 1),
                duration: mov,
                curve: curvaSaida,
                builder: (_, s, c) => Transform.scale(scale: s, child: c),
                // acima do Navigator não há Material: sem ele o texto sai sublinhado de amarelo
                child: Material(
                  color: Cor.painel,
                  shape: RoundedRectangleBorder(
                    borderRadius: Raio.r2,
                    side: BorderSide(color: Cor.ouroEscuro),
                  ),
                  elevation: 12,
                  shadowColor: Cor.sombra,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Transform.rotate(
                            angle: 0.785398,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Cor.ouro,
                                boxShadow: [
                                  BoxShadow(
                                    color: Cor.ouro.withValues(alpha: 0.6),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'VERSÃO NOVA!',
                          textAlign: TextAlign.center,
                          style: fonteTitulo(20, cor: Cor.ouroClaro),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Atualize antes de qualquer ação.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Cor.apagado, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        Semantics(
                          button: true,
                          enabled: !ocupado,
                          label: ocupado
                              ? 'Baixando a versão nova'
                              : 'Atualizar agora',
                          child: GestureDetector(
                            onTap: ocupado ? null : aoTocar,
                            child: AnimatedOpacity(
                              opacity: ocupado ? 0.7 : 1,
                              duration: mov,
                              child: Container(
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: Raio.r1,
                                  border: Border.all(color: Cor.ouro),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Cor.marcadoForte,
                                      Cor.marcadoFundo,
                                    ],
                                  ),
                                ),
                                child: ExcludeSemantics(
                                  child: ocupado
                                      ? SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Cor.ouro,
                                          ),
                                        )
                                      : Text(
                                          'ATUALIZAR AGORA',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.6,
                                            fontSize: 15,
                                            color: Cor.ouroClaro,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
