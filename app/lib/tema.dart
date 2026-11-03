import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Conjunto de cores de um tema (os mesmos tokens do painel do PC).
class Paleta {
  const Paleta({
    required this.fundo,
    required this.painel,
    required this.painel2,
    required this.linha,
    required this.linha2,
    required this.ouro,
    required this.ouroClaro,
    required this.ouroEscuro,
    required this.teal,
    required this.texto,
    required this.apagado,
  });

  /// Região de Runeterra: só 5 cores, o resto sai delas (a mesma conta do bloco de regiões do painel).
  factory Paleta.regiao({
    required Color bg,
    required Color surf,
    required Color acc,
    required Color acc2,
    required Color text,
  }) {
    // mistura `a` com `b`, `parte` de `a` (o color-mix do CSS)
    Color mix(Color a, double parte, Color b) => Color.lerp(b, a, parte)!;
    return Paleta(
      fundo: bg,
      painel: mix(bg, .70, surf),
      painel2: mix(bg, .42, surf),
      linha: mix(bg, .30, surf),
      linha2: mix(surf, .86, text),
      ouro: acc,
      ouroClaro: mix(acc, .30, Colors.white),
      ouroEscuro: mix(acc, .60, bg),
      teal: acc2,
      texto: text,
      apagado: mix(text, .72, bg),
    );
  }

  final Color fundo,
      painel,
      painel2,
      linha,
      linha2,
      ouro,
      ouroClaro,
      ouroEscuro,
      teal,
      texto,
      apagado;

  static const escuro = Paleta(
    fundo: Color(0xFF010A13),
    painel: Color(0xFF0A1219),
    painel2: Color(0xFF111B23),
    linha: Color(0xFF1A242D),
    linha2: Color(0xFF2E3A44),
    ouro: Color(0xFFC8AA6E),
    ouroClaro: Color(0xFFF0E6D2),
    ouroEscuro: Color(0xFF785A28),
    teal: Color(0xFF0AC8B9),
    texto: Color(0xFFDCD3BF),
    apagado: Color(0xFFA09B8C),
  );
}

/// Um tema da lista: escuro do client ou uma região de Runeterra.
class TemaApp {
  const TemaApp(this.id, this.nome, this.paleta);
  final String id;
  final String nome;
  final Paleta paleta;
}

Paleta _regiao(int bg, int surf, int acc, int acc2, int text) => Paleta.regiao(
  bg: Color(0xFF000000 | bg),
  surf: Color(0xFF000000 | surf),
  acc: Color(0xFF000000 | acc),
  acc2: Color(0xFF000000 | acc2),
  text: Color(0xFF000000 | text),
);

/// Mesmas cores das regiões do painel (`ui/index.html`): mexeu lá, mexe aqui.
final List<TemaApp> temasApp = [
  const TemaApp('escuro', 'Escuro', Paleta.escuro),
  TemaApp(
    'demacia',
    'Demacia',
    _regiao(0x0A1226, 0x26385C, 0x86ADEE, 0xE6C25C, 0xE6ECF8),
  ),
  TemaApp(
    'noxus',
    'Noxus',
    _regiao(0x130808, 0x3C1A1C, 0xE0554F, 0x9AAFC2, 0xE9D9D3),
  ),
  TemaApp(
    'piltover',
    'Piltover',
    _regiao(0x0B1417, 0x2A3F3E, 0xD9895A, 0x3FC8F0, 0xE8DFCF),
  ),
  TemaApp(
    'zaun',
    'Zaun',
    _regiao(0x080F0B, 0x1B3C2B, 0x43EE8C, 0xC562FF, 0xD5E6D8),
  ),
  TemaApp(
    'freljord',
    'Freljord',
    _regiao(0x09111A, 0x27394C, 0x9DDCF6, 0x6E9CD8, 0xE4EEF5),
  ),
  TemaApp(
    'ionia',
    'Ionia',
    _regiao(0x130C17, 0x3B2742, 0xF4A9C4, 0x8FD8B0, 0xF5ECDD),
  ),
  TemaApp(
    'shurima',
    'Shurima',
    _regiao(0x150F05, 0x3D2E12, 0xEBBB3E, 0x3FBAA9, 0xF1E4C9),
  ),
  TemaApp(
    'bilgewater',
    'Águas de Sentina',
    _regiao(0x08131A, 0x26403F, 0xD0803F, 0x3FA9C8, 0xDCE5E0),
  ),
  TemaApp(
    'sombras',
    'Ilha das Sombras',
    _regiao(0x040F0E, 0x163430, 0x48DBAA, 0x9AB0AA, 0xCDE4DE),
  ),
  TemaApp(
    'targon',
    'Targon',
    _regiao(0x0A0C22, 0x2A2C5E, 0x9B7CFF, 0xD5DCF2, 0xE6E4F6),
  ),
  TemaApp(
    'bandopolis',
    'Bandópolis',
    _regiao(0x120F2A, 0x3A2C66, 0xFF63AE, 0xFFD54A, 0xF2E8F6),
  ),
  TemaApp(
    'ixtal',
    'Ixtal',
    _regiao(0x0A1409, 0x34421F, 0xA9D24B, 0x3FCFA6, 0xE2EBD3),
  ),
  TemaApp(
    'vazio',
    'Vazio',
    _regiao(0x0A0612, 0x2B1647, 0xA950FF, 0xFF4F9C, 0xE1D5EF),
  ),
];

/// Tema em uso: guardado no aparelho (`SharedPreferences`), no link da vitrine (`?tema=`) pra teste.
abstract final class Temas {
  static final ValueNotifier<String> id = ValueNotifier('escuro');
  static Paleta _atual = Paleta.escuro;

  static TemaApp _achar(String? chave) =>
      temasApp.firstWhere((t) => t.id == chave, orElse: () => temasApp.first);

  /// Lê o tema guardado antes do primeiro quadro (sem piscar o escuro).
  static Future<void> carregar() async {
    String? guardado = Uri.base.queryParameters['tema'];
    if (guardado == null) {
      try {
        guardado = (await SharedPreferences.getInstance()).getString('tema');
      } catch (_) {}
    }
    final t = _achar(guardado);
    _atual = t.paleta;
    id.value = t.id;
  }

  /// Troca o tema: as cores novas valem na hora em tudo, inclusive nos `const` que não se refazem sozinhos.
  static Future<void> escolher(String novo) async {
    final t = _achar(novo);
    if (t.id == id.value) return;
    _atual = t.paleta;
    id.value = t.id;
    _refazerTudo();
    try {
      await (await SharedPreferences.getInstance()).setString('tema', t.id);
    } catch (_) {}
  }

  static void _refazerTudo() {
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    final raiz = WidgetsBinding.instance.rootElement;
    if (raiz != null) marcar(raiz);
  }
}

/// Cores do painel do Ping (cara do client do LoL), do tema em uso.
abstract final class Cor {
  static Color get fundo => Temas._atual.fundo;
  static Color get painel => Temas._atual.painel;
  static Color get painel2 => Temas._atual.painel2;
  static Color get linha => Temas._atual.linha;
  static Color get linha2 => Temas._atual.linha2;
  static Color get ouro => Temas._atual.ouro;
  static Color get ouroClaro => Temas._atual.ouroClaro;
  static Color get ouroEscuro => Temas._atual.ouroEscuro;
  static Color get teal => Temas._atual.teal;
  static Color get texto => Temas._atual.texto;
  static Color get apagado => Temas._atual.apagado;
  static const vermelho = Color(0xFFE84057);
  static const aviso = Color(0xFFE2B04A);
}

abstract final class Raio {
  static const r1 = BorderRadius.all(Radius.circular(2));
  static const r2 = BorderRadius.all(Radius.circular(4));
}

/// Curva das entradas (mesma do painel).
const curvaSaida = Cubic(0.23, 1, 0.32, 1);

// guardado: os relógios pedem o mesmo estilo a cada 250ms
final _titulos = <(double, Color), TextStyle>{};
TextStyle fonteTitulo(double tamanho, {Color? cor}) {
  final c = cor ?? Cor.ouro;
  return _titulos.putIfAbsent(
    (tamanho, c),
    () => GoogleFonts.cinzel(
      fontSize: tamanho,
      fontWeight: FontWeight.w700,
      letterSpacing: tamanho * 0.12,
      color: c,
    ),
  );
}

/// As fontes pedidas até agora já chegaram (no máximo 1,5s; sem internet segue com a reserva).
Future<void> esperarFontes() => GoogleFonts.pendingFonts()
    .timeout(const Duration(milliseconds: 1500))
    .then((_) {}, onError: (_) {});

ThemeData tema() {
  final base = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Cor.fundo,
    colorScheme: ColorScheme.dark(
      primary: Cor.ouro,
      secondary: Cor.teal,
      surface: Cor.painel,
      error: Cor.vermelho,
      onSurface: Cor.texto,
    ),
    splashFactory: NoSplash.splashFactory,
  );
  return base.copyWith(
    textTheme: GoogleFonts.barlowTextTheme(
      base.textTheme,
    ).apply(bodyColor: Cor.texto, displayColor: Cor.texto),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Cor.painel2,
      contentTextStyle: GoogleFonts.barlow(color: Cor.texto, fontSize: 15),
      shape: RoundedRectangleBorder(
        borderRadius: Raio.r2,
        side: BorderSide(color: Cor.ouroEscuro),
      ),
    ),
  );
}
