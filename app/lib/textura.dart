import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tema.dart';

/// Textura de fundo da região escolhida, os mesmos desenhos da janela do PC (`--tex` no `pc/ui/index.html`):
/// um ladrilho sem emenda por região, pintado na cor de destaque bem fraco, mais forte embaixo.
/// Fica numa camada própria (`RepaintBoundary`): só repinta quando o tema muda.
class TexturaFundo extends StatelessWidget {
  const TexturaFundo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Temas.mudou,
      builder: (context, _) => RepaintBoundary(
        child: CustomPaint(
          painter: _Pintor(Temas.id.value, Cor.ouro, Cor.claro),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Pintor extends CustomPainter {
  _Pintor(this.id, this.cor, this.claro);
  final String id;
  final Color cor;
  final bool claro;

  @override
  void paint(Canvas canvas, Size size) {
    final l = _ladrilho(id, cor);
    if (l == null || size.isEmpty) return;
    final area = Offset.zero & size;
    canvas.saveLayer(
      area,
      Paint()..color = Color.fromRGBO(0, 0, 0, claro ? .1 : .07),
    );
    for (var y = 0.0; y < size.height + l.h; y += l.h) {
      for (var x = 0.0; x < size.width + l.w; x += l.w) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawPicture(l.desenho);
        canvas.restore();
      }
    }
    // some devagar no topo
    canvas.drawRect(
      area,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height * .7),
          [const Color(0x59000000), const Color(0xFF000000)],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Pintor velho) =>
      velho.id != id || velho.cor != cor || velho.claro != claro;
}

class _Ladrilho {
  _Ladrilho(this.w, this.h, this.desenho);
  final double w, h;
  final ui.Picture desenho;
}

final Map<String, _Ladrilho?> _cache = {};

_Ladrilho? _ladrilho(String id, Color cor) {
  final chave = '$id ${cor.toARGB32()}';
  return _cache.putIfAbsent(chave, () {
    final d = _desenhos[id] ?? _desenhos['escuro'];
    if (d == null) return null;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    d.$3(_Pena(c, cor));
    return _Ladrilho(d.$1, d.$2, rec.endRecording());
  });
}

/// Caneta do ladrilho: traço e preenchimento numa cor só (a camada inteira ganha a transparência depois).
class _Pena {
  _Pena(this.c, this.cor);
  final Canvas c;
  final Color cor;

  Paint _tinta(double? w) => Paint()
    ..color = cor
    ..isAntiAlias = true
    ..style = w == null ? PaintingStyle.fill : PaintingStyle.stroke
    ..strokeWidth = w ?? 0
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void traco(String d, double w, {bool reto = false}) {
    final p = _tinta(w);
    if (reto) {
      p.strokeCap = StrokeCap.butt;
      p.strokeJoin = StrokeJoin.miter;
    }
    c.drawPath(_caminho(d), p);
  }

  void cheio(String d) => c.drawPath(_caminho(d), _tinta(null));
  void bola(double x, double y, double r, [double? w]) =>
      c.drawCircle(Offset(x, y), r, _tinta(w));

  /// Elipse girada (graus) em volta do próprio centro.
  void elipse(double x, double y, double rx, double ry, double graus) {
    c.save();
    c.translate(x, y);
    c.rotate(graus * math.pi / 180);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      _tinta(null),
    );
    c.restore();
  }

  /// Anel de dentes (engrenagem, raios do sol): o círculo tracejado do SVG.
  void dentes(double x, double y, double r, double w, int n) {
    final p = _tinta(w)..strokeCap = StrokeCap.butt;
    final passo = 2 * math.pi / n;
    final rect = Rect.fromCircle(center: Offset(x, y), radius: r);
    for (var i = 0; i < n; i++) {
      c.drawArc(rect, i * passo, passo / 2, false, p);
    }
  }

  /// Desenha `f` girado (graus) em volta de (x, y).
  void girado(double x, double y, double graus, void Function() f) {
    c.save();
    c.translate(x, y);
    c.rotate(graus * math.pi / 180);
    f();
    c.restore();
  }
}

/// Largura, altura e desenho de cada região. Mexeu na janela do PC (`--tex`), mexe aqui.
final Map<String, (double, double, void Function(_Pena))> _desenhos = {
  // hextech: losangos do client
  'escuro': (
    40,
    40,
    (p) {
      p.traco('M20 15l5 5-5 5-5-5z', 1.5, reto: true);
      p.cheio(
        'M0-2l2 2-2 2-2-2zM40-2l2 2-2 2-2-2zM0 38l2 2-2 2-2-2zM40 38l2 2-2 2-2-2z',
      );
    },
  ),
  // pedra branca de petricita em blocos, com a estrela do brasão
  'demacia': (
    56,
    28,
    (p) {
      p.traco('M0 .5H56M0 14.5H56M14 .5V14.5M42 14.5V28', 1, reto: true);
      p.cheio(
        'M42 3L43 6 46 7 43 8 42 11 41 8 38 7 41 6ZM14 17L15 20 18 21 15 22 14 25 13 22 10 21 13 20Z',
      );
    },
  ),
  // fortaleza de ferro: espinhos e lâminas
  'noxus': (
    24,
    34,
    (p) {
      p.cheio('M12 2L15 26H9ZM0 14L1.6 26H-1.6ZM24 14L25.6 26H22.4Z');
      p.traco('M0 30H24', 1.2, reto: true);
    },
  ),
  // engrenagens e relojoaria hextec
  'piltover': (
    64,
    64,
    (p) {
      p.dentes(32, 32, 12, 5, 12);
      p.bola(32, 32, 8.5, 1.3);
      p.bola(32, 32, 2.5);
      for (final (x, y) in [
        (0.0, 0.0),
        (64.0, 0.0),
        (0.0, 64.0),
        (64.0, 64.0),
      ]) {
        p.dentes(x, y, 7, 4, 8);
      }
    },
  ),
  // canos da cidade de baixo e bolhas de quimtec
  'zaun': (
    64,
    64,
    (p) {
      p.traco('M0 16H20V44H44V16H64M52 0V64', 1.5);
      for (final (x, y) in [
        (20.0, 16.0),
        (20.0, 44.0),
        (44.0, 44.0),
        (44.0, 16.0),
        (52.0, 16.0),
      ]) {
        p.bola(x, y, 2.4);
      }
      p.bola(10, 34, 1.8, 1);
      p.bola(13, 26, 1.1, 1);
      p.bola(32, 56, 2.4, 1);
      p.bola(30, 8, 1.4, 1);
    },
  ),
  // cristais de gelo
  'freljord': (
    60,
    60,
    (p) {
      for (var i = 0; i < 6; i++) {
        p.girado(
          30,
          30,
          i * 60.0,
          () => p.traco('M0 0V-12M0-7l-3.5-3.5M0-7l3.5-3.5', 1.3),
        );
      }
      p.traco(
        'M-3 0H3M0-3V3M57 0H63M60-3V3M-3 60H3M0 57V63M57 60H63M60 57V63',
        1.3,
      );
    },
  ),
  // flores espirituais e pétalas soltas
  'ionia': (
    56,
    56,
    (p) {
      for (var i = 0; i < 5; i++) {
        p.girado(14, 14, i * 72.0, () => p.elipse(0, -5.5, 2.8, 5, 0));
      }
      p.elipse(42, 40, 2, 4.2, 35);
      p.elipse(36, 12, 1.4, 3, -25);
      p.bola(10, 42, 1.2);
      p.bola(50, 24, .9);
    },
  ),
  // disco solar dos Ascendentes sobre as dunas
  'shurima': (
    72,
    72,
    (p) {
      p.bola(36, 28, 5);
      p.dentes(36, 28, 10.5, 4, 16);
      p.bola(36, 28, 15, .8);
      p.traco('M0 60Q18 52 36 60T72 60', 1.2);
      p.traco('M0 67Q18 61 36 67T72 67', .8);
    },
  ),
  // corda de navio e ondas
  'bilgewater': (
    48,
    48,
    (p) {
      p.traco('M0 10H48M0 16H48', .8, reto: true);
      p.traco(
        'M0 16L6 10M6 16L12 10M12 16L18 10M18 16L24 10M24 16L30 10M30 16L36 10M36 16L42 10M42 16L48 10',
        1.3,
      );
      p.traco('M0 34c3 -5 9 -5 12 0s9 5 12 0 9 -5 12 0 9 5 12 0', 1.2);
    },
  ),
  // névoa negra em fios e luzes de alma
  'sombras': (
    96,
    96,
    (p) {
      p.traco('M0 30C16 18 32 42 48 30S80 18 96 30', 1.7);
      p.traco('M0 70C20 62 28 80 48 72S76 62 96 70', 1.3);
      p.traco('M72 50a3 3 0 1 1 3 3a6 6 0 1 1 -6 -6', 1.3);
      p.traco('M22 50a2 2 0 1 1 2 2a4 4 0 1 1 -4 -4', 1.2);
      p.bola(60, 12, 1.3);
      p.bola(14, 88, 1);
      p.bola(86, 88, .8);
    },
  ),
  // céu de estrelas e constelações
  'targon': (
    100,
    100,
    (p) {
      p.traco('M12 18L30 10 46 26 38 44M66 60L82 52 90 72 74 84Z', 1);
      for (final (x, y, r) in [
        (12.0, 18.0, 1.4),
        (30.0, 10.0, 1.6),
        (46.0, 26.0, 1.3),
        (38.0, 44.0, 1.5),
        (66.0, 60.0, 1.4),
        (82.0, 52.0, 1.6),
        (90.0, 72.0, 1.3),
        (74.0, 84.0, 1.4),
        (55.0, 40.0, .7),
        (92.0, 30.0, .7),
        (40.0, 90.0, .7),
        (6.0, 56.0, .7),
        (58.0, 96.0, .6),
      ]) {
        p.bola(x, y, r);
      }
      p.cheio(
        'M70 14L71.2 20.8 78 22 71.2 23.2 70 30 68.8 23.2 62 22 68.8 20.8ZM20 72L20.8 76.2 25 77 20.8 77.8 20 82 19.2 77.8 15 77 19.2 76.2Z',
      );
    },
  ),
  // portais dos yordles e confete
  'bandopolis': (
    60,
    60,
    (p) {
      p.traco('M18 20a2 2 0 1 1 2 2a4 4 0 1 1 -4 -4a6 6 0 1 1 6 6', 1.5);
      p.traco('M32 46q3 -4 6 0t6 0t6 0', 1.5);
      p.girado(46.5, 13, 30, () => p.cheio('M-2.5-1.1h5v2.2h-5z'));
      p.girado(10, 45, -40, () => p.cheio('M-2.25-1h4.5v2h-4.5z'));
      p.bola(50, 30, 1.6);
      p.bola(30, 6, 1.2);
      p.bola(4, 28, 1);
      p.cheio(
        'M40 52L41 55 44 56 41 57 40 60 39 57 36 56 39 55ZM40 -8L41 -5 44 -4 41 -3 40 0 39 -3 36 -4 39 -5Z',
      );
    },
  ),
  // degraus dos templos da selva
  'ixtal': (
    48,
    40,
    (p) {
      p.traco(
        'M0 34H6V28H12V22H18V16H30V22H36V28H42V34H48M21 34V28H27V34',
        1.3,
        reto: true,
      );
      p.cheio('M24 4l3 3-3 3-3-3zM0 4l3 3-3 3-3-3zM48 4l3 3-3 3-3-3z');
    },
  ),
  // carapaça de células do Vazio
  'vazio': (
    60,
    34.64,
    (p) {
      for (final (x, y) in [
        (0.0, 0.0),
        (30.0, 0.0),
        (0.0, 17.32),
        (30.0, 17.32),
      ]) {
        p.girado(
          x,
          y,
          0,
          () => p.traco('M0 8.66L5 0H15L20 8.66L15 17.32H5ZM20 8.66H30', 1.4),
        );
      }
      p.bola(10, 8.66, 1.6);
      p.bola(40, 25.98, 1.6);
      p.bola(25, 17.32, .9);
    },
  ),
};

/// Leitor do atributo `d` do SVG (M L H V C S Q T A Z, absoluto e relativo), pra copiar os desenhos da janela do PC.
Path _caminho(String d) {
  final t = RegExp(
    r'[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)',
  ).allMatches(d).map((m) => m[0]!).toList();
  final path = Path();
  var i = 0;
  var cmd = 'M';
  var ultimo = '';
  double x = 0, y = 0, x0 = 0, y0 = 0, cx = 0, cy = 0;
  double n() => double.parse(t[i++]);
  bool letra(String s) => RegExp(r'^[A-Za-z]$').hasMatch(s);
  while (i < t.length) {
    if (letra(t[i])) cmd = t[i++];
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    final tipo = cmd.toUpperCase();
    switch (tipo) {
      case 'M':
        x = ox + n();
        y = oy + n();
        path.moveTo(x, y);
        x0 = x;
        y0 = y;
        cmd = rel ? 'l' : 'L';
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
      case 'H':
        x = ox + n();
        path.lineTo(x, y);
      case 'V':
        y = oy + n();
        path.lineTo(x, y);
      case 'C' || 'S':
        final double x1, y1;
        if (tipo == 'C') {
          x1 = ox + n();
          y1 = oy + n();
        } else {
          final reflete = ultimo == 'C' || ultimo == 'S';
          x1 = reflete ? 2 * x - cx : x;
          y1 = reflete ? 2 * y - cy : y;
        }
        final x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        cx = x2;
        cy = y2;
      case 'Q' || 'T':
        final double qx, qy;
        if (tipo == 'Q') {
          qx = ox + n();
          qy = oy + n();
        } else {
          final reflete = ultimo == 'Q' || ultimo == 'T';
          qx = reflete ? 2 * x - cx : x;
          qy = reflete ? 2 * y - cy : y;
        }
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(qx, qy, x, y);
        cx = qx;
        cy = qy;
      case 'A':
        final rx = n(),
            ry = n(),
            giro = n(),
            grande = n() != 0,
            horario = n() != 0;
        x = ox + n();
        y = oy + n();
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: giro,
          largeArc: grande,
          clockwise: horario,
        );
      case 'Z':
        path.close();
        x = x0;
        y = y0;
    }
    if (tipo != 'C' && tipo != 'S' && tipo != 'Q' && tipo != 'T') {
      cx = x;
      cy = y;
    }
    ultimo = tipo;
  }
  return path;
}
