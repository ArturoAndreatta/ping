import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

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
    this.claro = false,
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

  /// A mesma região no claro: papel com o tom da superfície, tinta do fundo e destaques escurecidos pra ler
  /// no papel (a mesma conta do bloco claro das regiões do painel).
  factory Paleta.regiaoClara({
    required Color bg,
    required Color surf,
    required Color acc,
    required Color acc2,
  }) {
    Color mix(Color a, double parte, Color b) => Color.lerp(b, a, parte)!;
    const branco = Colors.white, preto = Colors.black;
    final texto = mix(bg, .70, preto);
    final ouro = mix(acc, .52, preto);
    return Paleta(
      claro: true,
      fundo: mix(surf, .11, branco),
      painel: mix(surf, .04, branco),
      painel2: mix(surf, .10, branco),
      linha: mix(surf, .20, branco),
      linha2: mix(surf, .34, branco),
      ouro: ouro,
      ouroClaro: mix(ouro, .35, preto),
      ouroEscuro: mix(ouro, .55, branco),
      teal: mix(acc2, .48, preto),
      texto: texto,
      apagado: mix(texto, .66, branco),
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

  /// Fundo claro (papel e tinta): o Material vira claro junto.
  final bool claro;

  /// Fundo de campo de texto.
  Color get campo => claro
      ? Color.lerp(painel, Colors.white, .6)!
      : Color.lerp(fundo, painel, .45)!;

  /// Fundo de item marcado (ouro bem fraco por cima do painel) e a versão mais acesa.
  Color get marcado => Color.lerp(painel2, ouro, claro ? .12 : .13)!;
  Color get marcadoForte => Color.lerp(painel2, ouro, claro ? .2 : .22)!;

  /// Pé do degradê dos botões acesos (do marcado forte pra este).
  Color get marcadoFundo => Color.lerp(fundo, ouro, .08)!;

  /// Véu atrás das folhas e janelas.
  Color get veu => claro
      ? Color.lerp(texto, Colors.transparent, .72)!
      : const Color(0xB3000000);

  /// Sombra dos cartões.
  Color get sombra => claro
      ? Color.lerp(texto, Colors.transparent, .84)!
      : const Color(0x8C000000);

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

  /// Claro do client: pergaminho e tinta, o mesmo ouro escurecido pra ler no papel.
  static const pergaminho = Paleta(
    claro: true,
    fundo: Color(0xFFF2ECE0),
    painel: Color(0xFFFBF8F2),
    painel2: Color(0xFFF3EDE1),
    linha: Color(0xFFE3D9C5),
    linha2: Color(0xFFCFC1A2),
    ouro: Color(0xFF8A6A2E),
    ouroClaro: Color(0xFF3A2A0F),
    ouroEscuro: Color(0xFFB79A5E),
    teal: Color(0xFF087F86),
    texto: Color(0xFF2A2822),
    apagado: Color(0xFF6C6553),
  );
}

/// Um tema da lista: o do client ou uma região de Runeterra, cada um no escuro e no claro.
class TemaApp {
  const TemaApp(this.id, this.nome, this.escura, this.clara);
  final String id;
  final String nome;
  final Paleta escura, clara;

  Paleta paleta(bool claro) => claro ? clara : escura;
}

TemaApp _regiao(String id, String nome, List<int> c) {
  Color cor(int v) => Color(0xFF000000 | v);
  return TemaApp(
    id,
    nome,
    Paleta.regiao(
      bg: cor(c[0]),
      surf: cor(c[1]),
      acc: cor(c[2]),
      acc2: cor(c[3]),
      text: cor(c[4]),
    ),
    Paleta.regiaoClara(
      bg: cor(c[0]),
      surf: cor(c[1]),
      acc: cor(c[2]),
      acc2: cor(c[3]),
    ),
  );
}

/// Mesmas cores das regiões do painel (`ui/index.html`): mexeu lá, mexe aqui.
final List<TemaApp> temasApp = [
  const TemaApp('escuro', 'Client', Paleta.escuro, Paleta.pergaminho),
  _regiao('demacia', 'Demacia', [
    0x0A1226,
    0x26385C,
    0x86ADEE,
    0xE6C25C,
    0xE6ECF8,
  ]),
  _regiao('noxus', 'Noxus', [0x130808, 0x3C1A1C, 0xE0554F, 0x9AAFC2, 0xE9D9D3]),
  _regiao('piltover', 'Piltover', [
    0x0B1417,
    0x2A3F3E,
    0xD9895A,
    0x3FC8F0,
    0xE8DFCF,
  ]),
  _regiao('zaun', 'Zaun', [0x080F0B, 0x1B3C2B, 0x43EE8C, 0xC562FF, 0xD5E6D8]),
  _regiao('freljord', 'Freljord', [
    0x09111A,
    0x27394C,
    0x9DDCF6,
    0x6E9CD8,
    0xE4EEF5,
  ]),
  _regiao('ionia', 'Ionia', [0x130C17, 0x3B2742, 0xF4A9C4, 0x8FD8B0, 0xF5ECDD]),
  _regiao('shurima', 'Shurima', [
    0x150F05,
    0x3D2E12,
    0xEBBB3E,
    0x3FBAA9,
    0xF1E4C9,
  ]),
  _regiao('bilgewater', 'Águas de Sentina', [
    0x08131A,
    0x26403F,
    0xD0803F,
    0x3FA9C8,
    0xDCE5E0,
  ]),
  _regiao('sombras', 'Ilha das Sombras', [
    0x040F0E,
    0x163430,
    0x48DBAA,
    0x9AB0AA,
    0xCDE4DE,
  ]),
  _regiao('targon', 'Targon', [
    0x0A0C22,
    0x2A2C5E,
    0x9B7CFF,
    0xD5DCF2,
    0xE6E4F6,
  ]),
  _regiao('bandopolis', 'Bandópolis', [
    0x120F2A,
    0x3A2C66,
    0xFF63AE,
    0xFFD54A,
    0xF2E8F6,
  ]),
  _regiao('ixtal', 'Ixtal', [0x0A1409, 0x34421F, 0xA9D24B, 0x3FCFA6, 0xE2EBD3]),
  _regiao('vazio', 'Vazio', [0x0A0612, 0x2B1647, 0xA950FF, 0xFF4F9C, 0xE1D5EF]),
];

/// Tema em uso (região e modo): guardado no aparelho (`SharedPreferences`), no link da vitrine
/// (`?tema=` e `?modo=claro`) pra teste.
abstract final class Temas {
  /// Região: `escuro` é o tema do client (o nome ficou do tempo em que só havia o escuro).
  static final ValueNotifier<String> id = ValueNotifier('escuro');

  /// Modo claro (papel e tinta), em qualquer região.
  static final ValueNotifier<bool> claro = ValueNotifier(false);

  /// Muda com a região ou com o modo.
  static final Listenable mudou = Listenable.merge([id, claro]);

  static Paleta _atual = Paleta.escuro;

  static TemaApp _achar(String? chave) =>
      temasApp.firstWhere((t) => t.id == chave, orElse: () => temasApp.first);

  static TemaApp get atual => _achar(id.value);

  /// Lê o tema guardado antes do primeiro quadro (sem piscar o escuro).
  static Future<void> carregar() async {
    final link = Uri.base.queryParameters;
    String? guardado = link['tema'];
    String? modo = link['modo'];
    if (guardado == null || modo == null) {
      try {
        final p = await SharedPreferences.getInstance();
        guardado ??= p.getString('tema');
        modo ??= p.getString('modo');
      } catch (_) {}
    }
    final t = _achar(guardado);
    id.value = t.id;
    claro.value = modo == 'claro';
    _atual = t.paleta(claro.value);
    _pintarPagina();
  }

  /// Troca a região: as cores novas valem na hora em tudo, inclusive nos `const` que não se refazem sozinhos.
  static Future<void> escolher(String novo) async {
    final t = _achar(novo);
    if (t.id == id.value) return;
    id.value = t.id;
    _aplicar();
    try {
      await (await SharedPreferences.getInstance()).setString('tema', t.id);
    } catch (_) {}
  }

  /// Troca entre escuro e claro, na região em uso.
  static Future<void> escolherModo(bool novo) async {
    if (novo == claro.value) return;
    claro.value = novo;
    _aplicar();
    try {
      await (await SharedPreferences.getInstance()).setString(
        'modo',
        novo ? 'claro' : 'escuro',
      );
    } catch (_) {}
  }

  static void _aplicar() {
    _atual = atual.paleta(claro.value);
    _pintarPagina();
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    final raiz = WidgetsBinding.instance.rootElement;
    if (raiz != null) marcar(raiz);
  }
}

/// A página por trás do Flutter (fundo da área segura) e a cor da barra do navegador seguem o tema.
void _pintarPagina() {
  final c = Temas._atual.fundo.toARGB32() & 0xFFFFFF;
  final hex = '#${c.toRadixString(16).padLeft(6, '0')}';
  try {
    web.document
        .querySelector('meta[name="theme-color"]')
        ?.setAttribute('content', hex);
    web.document.documentElement?.setAttribute('style', 'background: $hex');
    web.document.body?.style.background = hex;
  } catch (_) {}
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
  static Color get campo => Temas._atual.campo;
  static Color get marcado => Temas._atual.marcado;
  static Color get marcadoForte => Temas._atual.marcadoForte;
  static Color get marcadoFundo => Temas._atual.marcadoFundo;
  static Color get veu => Temas._atual.veu;
  static Color get sombra => Temas._atual.sombra;
  static bool get claro => Temas._atual.claro;
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
  final esquema = Cor.claro ? ColorScheme.light : ColorScheme.dark;
  final base = ThemeData(
    brightness: Cor.claro ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: Cor.fundo,
    colorScheme: esquema(
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
