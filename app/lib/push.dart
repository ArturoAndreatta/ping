import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Notificações push deste aparelho (skill notificacoes-push): a ponte com o `web/push.js`.
/// Quem manda é o disparador na Cloudflare; aqui só pede a permissão, inscreve e devolve a inscrição pro
/// app gravar no banco.
///
/// Situação: `ativo`, `desligado`, `negado` (recusado nos ajustes), `tela_inicio` (no iPhone só funciona
/// com o app na tela de início) ou `sem_suporte`.
typedef EstadoPush = ({
  String situacao,
  Map<String, dynamic>? inscricao,
  String ua,
});

class Push {
  Push._();

  /// Chave pública VAPID do disparador (a mesma em todos os projetos; a privada fica só no Worker).
  static const chavePublica =
      'BBhVK0TcVYlDGEb1ID3P3L8ugpctlT0NJPSMaCk5g8TQNO23gyfrHvTP14X3RSIZ9shNO45PVs6AGnEjgSdRVqA';

  static JSObject? get _js {
    final v = web.window.getProperty<JSAny?>('appPush'.toJS);
    return v.isA<JSObject>() ? v as JSObject : null;
  }

  static Future<EstadoPush> _chamar(String metodo, [JSAny? arg]) async {
    final js = _js;
    if (js == null) {
      return (situacao: 'sem_suporte', inscricao: null, ua: '');
    }
    try {
      final p = arg == null
          ? js.callMethod<JSPromise<JSAny?>>(metodo.toJS)
          : js.callMethod<JSPromise<JSAny?>>(metodo.toJS, arg);
      final r = await p.toDart;
      // ida e volta por JSON: o objeto JS vira Map do Dart sem conversão campo a campo
      final texto = (globalContext['JSON'] as JSObject)
          .callMethod<JSString>('stringify'.toJS, r)
          .toDart;
      final m = jsonDecode(texto) as Map<String, dynamic>;
      final insc = m['inscricao'];
      return (
        situacao: '${m['situacao']}',
        inscricao: insc is Map<String, dynamic> ? insc : null,
        ua: '${m['ua'] ?? ''}',
      );
    } catch (e) {
      debugPrint('Ping push: $e');
      return (situacao: 'erro', inscricao: null, ua: '');
    }
  }

  static Future<EstadoPush> estado() => _chamar('estado');

  /// Chamar direto do toque: o iPhone só mostra o pedido de permissão dentro do gesto.
  static Future<EstadoPush> ativar() => _chamar(
    'ativarNoToque',
    chavePublica.toJS,
  ); // o onTap do Flutter roda antes do touchend

  /// Liga sem o toque no botão: com a permissão já dada inscreve na hora; sem ela, só termina depois do
  /// primeiro toque em qualquer lugar do app (é nele que o pedido de permissão aparece).
  static Future<EstadoPush> ativarSozinho() =>
      _chamar('ativarSozinho', chavePublica.toJS);

  static Future<EstadoPush> desativar() => _chamar('desativar');
}
