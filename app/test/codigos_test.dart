import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ping_app/codigos.dart';
import 'package:ping_app/l10n/txt.dart';

Txt _t(String l) => lookupTxt(Locale(l));

void main() {
  test('mensagem por código nos três idiomas', () {
    expect(textoMsg(_t('pt'), 'lol_fechado'), 'LoL fechado');
    expect(textoMsg(_t('en'), 'lol_fechado'), 'LoL is closed');
    expect(textoMsg(_t('es'), 'lol_fechado'), 'LoL está cerrado');
  });

  test('mensagem com parâmetros', () {
    expect(textoMsg(_t('en'), 'banido', {'nome': 'Ahri'}), 'Banned: Ahri');
    expect(
      textoMsg(_t('es'), 'convites_mandados', {'n': 3}),
      '3 invitaciones enviadas',
    );
    expect(
      textoMsg(_t('en'), 'sala_criada_e', {'depois': 'convite_mandado'}),
      'Lobby created. Invite sent',
    );
  });

  test('frase em português do PC antigo passa como veio', () {
    for (final l in ['pt', 'en', 'es']) {
      expect(textoMsg(_t(l), 'O LoL recusou'), 'O LoL recusou');
      expect(textoMsg(_t(l), ''), '');
    }
    expect(
      textoStatus(_t('en'), 'Na fila'),
      'In queue',
    ); // texto antigo conhecido
    expect(textoStatus(_t('en'), 'coisa nova'), 'coisa nova');
  });

  test('status, grupo e cor do amigo aceitam código e texto antigo', () {
    expect(textoStatus(_t('es'), 'na_fila'), 'En cola');
    expect(textoGrupo(_t('en'), 'contra_ia'), 'Vs. AI');
    expect(textoGrupo(_t('es'), 'Summoner\'s Rift'), 'Grieta del Invocador');
    expect(statusDisponivel('disponivel'), isTrue);
    expect(statusDisponivel('Disponível'), isTrue);
    expect(statusDisponivel('na_fila'), isFalse);
    expect(statusAusente('ocupado'), isTrue);
    expect(statusAusente('Ausente'), isTrue);
    expect(statusAusente('disponivel'), isFalse);
  });

  test('aviso do chat: código com nome ou frase pronta', () {
    expect(
      textoAvisoChat(_t('en'), {'texto': 'entrou', 'quem': 'Fulano'}),
      'Fulano joined',
    );
    expect(
      textoAvisoChat(_t('es'), {'texto': 'saiu', 'quem': ''}),
      'Alguien salió',
    );
    expect(
      textoAvisoChat(_t('en'), {'texto': 'Fulano entrou'}),
      'Fulano entrou',
    );
  });
}
