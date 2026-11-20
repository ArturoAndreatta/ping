import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/txt.dart';

/// Idioma do app: `null` = automático (segue o do aparelho), senão `pt`, `en` ou `es` escolhido nas opções.
/// A escolha manual fica no shared_preferences (chave `idioma`; ausente = automático).
class Idioma {
  Idioma._();

  static const codigos = ['pt', 'en', 'es'];
  static final escolha = ValueNotifier<Locale?>(null);

  static Locale? _de(String? c) => codigos.contains(c) ? Locale(c!) : null;

  /// Lê o idioma guardado. `?idioma=en|es|pt` no link (vitrine, prints) vale por cima e não é guardado.
  static Future<void> carregar() async {
    final link = Uri.base.queryParameters['idioma'];
    if (_de(link) != null) {
      escolha.value = _de(link);
      return;
    }
    try {
      final p = await SharedPreferences.getInstance();
      escolha.value = _de(p.getString('idioma'));
    } catch (_) {}
  }

  static Future<void> escolher(Locale? novo) async {
    if (novo?.languageCode == escolha.value?.languageCode) return;
    escolha.value = novo;
    try {
      final p = await SharedPreferences.getInstance();
      if (novo == null) {
        await p.remove('idioma');
      } else {
        await p.setString('idioma', novo.languageCode);
      }
    } catch (_) {}
  }

  /// Idioma do aparelho: pt (inclusive pt-PT), en e es valem; qualquer outro cai em inglês.
  static Locale resolver(Locale? aparelho, Iterable<Locale> aceitos) {
    final lg = aparelho?.languageCode;
    return Locale(codigos.contains(lg) ? lg! : 'en');
  }

  /// Os textos no idioma em uso, pra quem não tem `BuildContext` (mensagens de erro da conexão).
  static Txt get txt => lookupTxt(
    resolver(
      escolha.value ?? WidgetsBinding.instance.platformDispatcher.locale,
      codigos.map(Locale.new),
    ),
  );

  /// Nome de cada idioma, sempre na própria língua.
  static String nome(String codigo) => switch (codigo) {
    'pt' => 'Português',
    'en' => 'English',
    _ => 'Español',
  };
}

extension TxtContexto on BuildContext {
  /// Os textos do app no idioma em uso.
  Txt get txt => Txt.of(this);
}
