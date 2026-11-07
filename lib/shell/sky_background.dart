import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Latar bergerak di bagian atas layar.
/// Siang: matahari, awan, burung, pesawat kertas. Malam: bulan, bintang, awan redup, kunang-kunang.
class SkyBackground extends StatefulWidget {
  const SkyBackground({super.key, required this.dark, this.tab = 0, this.height = 340});

  final bool dark;
  final int tab;
  final double height;

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground> with TickerProviderStateMixin {
  final _time = ValueNotifier<double>(20);
  late final Ticker _ticker;
  late final AnimationController _level =
      AnimationController(vsync: this, lowerBound: 0, upperBound: 4, value: widget.tab.toDouble());
  late final AnimationController _shoot = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didUpdateWidget(covariant SkyBackground old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) {
      _level.animateTo(widget.tab.toDouble(), duration: const Duration(milliseconds: 700), curve: Curves.easeOut);
      if (!MediaQuery.of(context).disableAnimations) _shoot.forward(from: 0);
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => _time.value = 20 + elapsed.inMicroseconds / 1e6);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce && _ticker.isActive) _ticker.stop();
    if (!reduce && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _level.dispose();
    _shoot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.black, Colors.transparent],
            stops: [0, 0.7, 1],
          ).createShader(r),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.dark ? 1 : 0),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
            builder: (context, night, _) => RepaintBoundary(
              child: CustomPaint(painter: _SkyPainter(_time, night, _level, _shoot), size: Size.infinite),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.time, this.night, this.level, this.shoot) : super(repaint: Listenable.merge([time, level, shoot]));

  final ValueNotifier<double> time;
  final double night;
  final Animation<double> level;
  final Animation<double> shoot;

  double _pop(int n) => (level.value - (n - 1)).clamp(0.0, 1.0);

  static const _stars = [
    [28.0, 64.0, 1.0, 3.2], [74.0, 118.0, 1.5, 4.1], [122.0, 40.0, 1.0, 3.6], [168.0, 92.0, 1.0, 2.9],
    [214.0, 30.0, 1.5, 4.4], [250.0, 140.0, 1.0, 3.3], [300.0, 52.0, 1.0, 3.9], [352.0, 110.0, 1.5, 3.1],
    [40.0, 170.0, 1.0, 4.6], [190.0, 190.0, 1.0, 3.4], [330.0, 200.0, 1.0, 4.0], [96.0, 226.0, 1.0, 3.7],
  ];
  static const _flies = [
    [30.0, 250.0, 7.0, 2.2, 0.0], [88.0, 214.0, 9.0, 2.8, 2.0], [140.0, 268.0, 8.0, 1.9, 4.0],
    [196.0, 232.0, 10.0, 2.5, 1.0], [248.0, 282.0, 7.5, 3.1, 3.0], [300.0, 226.0, 9.5, 2.1, 5.0],
    [350.0, 262.0, 8.5, 2.6, 2.5], [62.0, 296.0, 10.0, 2.4, 6.0], [226.0, 300.0, 8.0, 2.9, 1.5],
    [330.0, 190.0, 11.0, 2.3, 3.5],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final w = size.width;
    final sx = w / 390;
    if (night < 1) {
      canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: 1 - night));
      _day(canvas, size, t, sx);
      canvas.restore();
    }
    if (night > 0) {
      canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: night));
      _night(canvas, size, t, sx);
      canvas.restore();
    }
    _extras(canvas, size, t, sx);
  }

  /// Benda yang bertambah setiap pindah halaman + bintang jatuh.
  void _extras(Canvas c, Size s, double t, double sx) {
    final w = s.width;
    // Level 4: pegunungan di kejauhan (+ aurora saat malam).
    final p4 = _pop(4);
    if (p4 > 0) {
      if (night > 0) {
        for (final (y, col, ph) in [(150.0, const Color(0xFF4ADE80), 0.0), (170.0, const Color(0xFFA78BFA), 1.5)]) {
          final path = Path()..moveTo(-20, y);
          for (var x = 0.0; x <= w + 40; x += 40) {
            path.lineTo(x, y + 18 * math.sin(x / 70 + t * 0.6 + ph));
          }
          c.drawPath(
              path,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 16
                ..color = col.withValues(alpha: 0.35 * night * p4)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
        }
      }
      c.save();
      c.translate(0, s.height - 190 + (1 - p4) * 14);
      final m = Path()..moveTo(0, 110);
      const pts = [[0.0, 74.0], [38.0, 40.0], [66.0, 62.0], [112.0, 18.0], [160.0, 66.0], [200.0, 46.0], [248.0, 78.0], [290.0, 30.0], [336.0, 70.0], [366.0, 50.0], [390.0, 64.0]];
      for (final p in pts) {
        m.lineTo(p[0] * sx, p[1]);
      }
      m
        ..lineTo(w, 110)
        ..close();
      c.drawPath(m, Paint()..color = Color.lerp(const Color(0xFFC4E0D0), const Color(0xFF123524), night)!.withValues(alpha: p4));
      final snow = Paint()..color = Color.lerp(Colors.white, const Color(0xFF2E5C46), night)!.withValues(alpha: p4);
      c.drawPath(Path()..moveTo(112 * sx, 18)..lineTo(98 * sx, 34)..lineTo(112 * sx, 30)..lineTo(124 * sx, 38)..close(), snow);
      c.drawPath(Path()..moveTo(290 * sx, 30)..lineTo(278 * sx, 44)..lineTo(290 * sx, 40)..lineTo(302 * sx, 46)..close(), snow);
      c.restore();
    }
    // Level 1: pesawat jet dengan jejak asap.
    final p1 = _pop(1);
    if (p1 > 0) {
      final k = (t / 14) % 1;
      final x = -130 + (w + 230) * k;
      final y = 150 - 90 * k;
      final a = p1 * (k < 0.08 ? k / 0.08 : (k > 0.92 ? (1 - k) / 0.08 : 1));
      c.save();
      c.translate(x, y);
      c.rotate(-0.12);
      c.drawLine(const Offset(0, 12), const Offset(72, 12), Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.7 * a));
      final jet = Paint()..color = Color.lerp(Colors.white, const Color(0xFFDCEBE1), night)!.withValues(alpha: a);
      c.drawRRect(RRect.fromLTRBR(72, 6, 118, 18, const Radius.circular(6)), jet);
      c.drawPath(Path()..moveTo(90, 12)..lineTo(100, 2)..lineTo(105, 2)..lineTo(98, 12)..close(), jet);
      c.drawPath(Path()..moveTo(78, 9)..lineTo(74, 2)..lineTo(79, 2)..lineTo(84, 9)..close(), jet);
      c.restore();
    }
    // Level 2: balon udara melayang.
    final p2 = _pop(2);
    if (p2 > 0) {
      final k = ((t + 10) / 46) % 1;
      final x = -60 + (w + 120) * k;
      final y = 96 + 6 * math.sin(t * 1.4);
      c.save();
      c.translate(x, y);
      final dim = 1 - 0.35 * night;
      c.drawPath(
          Path()
            ..moveTo(20, 2)
            ..cubicTo(9, 2, 3, 11, 3, 20)
            ..cubicTo(3, 29, 10, 35, 14, 40)
            ..lineTo(26, 40)
            ..cubicTo(30, 35, 37, 29, 37, 20)
            ..cubicTo(37, 11, 31, 2, 20, 2)
            ..close(),
          Paint()..color = Color.fromRGBO((248 * dim).round(), (113 * dim).round(), (113 * dim).round(), p2));
      c.drawPath(Path()..moveTo(20, 2)..cubicTo(15, 8, 14, 16, 16, 40)..lineTo(24, 40)..cubicTo(26, 16, 25, 8, 20, 2)..close(),
          Paint()..color = Color.fromRGBO((251 * dim).round(), (191 * dim).round(), (36 * dim).round(), p2));
      c.drawRRect(RRect.fromLTRBR(15, 48, 25, 56, const Radius.circular(2)), Paint()..color = const Color(0xFFB07A45).withValues(alpha: p2));
      final line = Paint()
        ..strokeWidth = 1.2
        ..color = const Color(0xFF7A5C3A).withValues(alpha: p2);
      c.drawLine(const Offset(14, 40), const Offset(17, 48), line);
      c.drawLine(const Offset(26, 40), const Offset(23, 48), line);
      c.restore();
    }
    // Level 3: roket meluncur (+ planet saat malam).
    final p3 = _pop(3);
    if (p3 > 0) {
      if (night > 0) {
        final pl = Offset(66 * sx, 118);
        c.drawCircle(pl, 12, Paint()..color = const Color(0xFFA78BFA).withValues(alpha: night * p3));
        c.save();
        c.translate(pl.dx, pl.dy);
        c.rotate(-0.3);
        c.drawOval(const Rect.fromLTRB(-30, -7, 30, 7), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFC4B5FD).withValues(alpha: night * p3));
        c.restore();
      }
      final k = (t / 9) % 1;
      final e = Curves.easeIn.transform(k);
      final x = 296 * sx + 50 * e;
      final y = 200 - 270 * e;
      final a = p3 * (k < 0.1 ? k / 0.1 : (k > 0.85 ? (1 - k) / 0.15 : 1));
      c.save();
      c.translate(x, y);
      c.rotate(0.21);
      final flame = 0.8 + 0.3 * math.sin(t * 30);
      c.drawPath(Path()..moveTo(7, 32)..lineTo(11, 32 + 22 * flame)..lineTo(15, 32)..close(), Paint()..color = const Color(0xFFFBBF24).withValues(alpha: a));
      c.drawPath(
          Path()..moveTo(11, 0)..cubicTo(16, 8, 18, 16, 18, 28)..lineTo(4, 28)..cubicTo(4, 16, 6, 8, 11, 0)..close(),
          Paint()..color = const Color(0xFFF3F4F6).withValues(alpha: a));
      c.drawCircle(const Offset(11, 16), 3.4, Paint()..color = const Color(0xFF60A5FA).withValues(alpha: a));
      final fin = Paint()..color = const Color(0xFFEF4444).withValues(alpha: a);
      c.drawPath(Path()..moveTo(4, 22)..lineTo(0, 34)..lineTo(4, 31)..close(), fin);
      c.drawPath(Path()..moveTo(18, 22)..lineTo(22, 34)..lineTo(18, 31)..close(), fin);
      c.restore();
    }
    // Bintang jatuh setiap pindah halaman.
    final v = shoot.value;
    if (v > 0 && v < 1) {
      final x = -80 + (w + 160) * v;
      final y = 40 + 70 * v;
      final a = v < 0.15 ? v / 0.15 : 1 - v;
      c.drawLine(Offset(x - 60, y - 6), Offset(x, y), Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.6 * a));
      c.drawCircle(Offset(x, y), 3.4, Paint()..color = const Color(0xFFFDE68A).withValues(alpha: a));
    }
  }

  void _gradient(Canvas c, Size s, List<Color> colors) {
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: const [0, 0.55, 1],
        ).createShader(Offset.zero & s),
    );
  }

  void _hills(Canvas c, Size s, double sx, Color back, Color front) {
    final top = s.height - 130;
    Path hill(List<double> d) {
      // d: [y0, c1x,c1y, c2x,c2y, x,y, c3x,c3y, c4x,c4y, endY]
      final p = Path()..moveTo(0, top + d[0]);
      p.cubicTo(d[1] * sx, top + d[2], d[3] * sx, top + d[4], d[5] * sx, top + d[6]);
      p.cubicTo(d[7] * sx, top + d[8], d[9] * sx, top + d[10], s.width, top + d[11]);
      p.lineTo(s.width, s.height);
      p.lineTo(0, s.height);
      return p..close();
    }

    c.drawPath(hill([74, 60, 42, 120, 48, 182, 72, 244, 96, 304, 52, 62]), Paint()..color = back);
    c.drawPath(hill([100, 80, 80, 152, 84, 232, 102, 292, 114, 342, 96, 92]), Paint()..color = front);
  }

  void _cloud(Canvas c, double x, double y, double scale, Color color) {
    final p = Paint()..color = color;
    c.save();
    c.translate(x, y);
    c.scale(scale);
    c.drawRRect(RRect.fromLTRBR(4, 22, 78, 40, const Radius.circular(12)), p);
    c.drawCircle(const Offset(22, 26), 14, p);
    c.drawCircle(const Offset(40, 18), 18, p);
    c.drawCircle(const Offset(60, 24), 14, p);
    c.restore();
  }

  void _clouds(Canvas c, Size s, double t, Color color, double opacity) {
    const specs = [[26.0, 1.2, 70.0, 20.0], [92.0, 0.9, 95.0, 62.0], [150.0, 1.38, 120.0, 10.0]];
    final travel = s.width + 170 + 60;
    for (final sp in specs) {
      final p = ((t + sp[3]) / sp[2]) % 1;
      _cloud(c, -170 + p * travel, sp[0], sp[1], color.withValues(alpha: opacity));
    }
  }

  void _day(Canvas c, Size s, double t, double sx) {
    final w = s.width;
    _gradient(c, s, const [Color(0xFFD3EEDC), Color(0xFFE6F4EA), Color(0x00F4F7F5)]);
    // Cahaya + matahari
    final sun = Offset(w - 61, 95);
    c.drawCircle(
      sun,
      100,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF2BF), Color(0x99FFF2BF), Color(0x00FFF2BF)],
          stops: [0, 0.3, 0.68],
        ).createShader(Rect.fromCircle(center: sun, radius: 100)),
    );
    c.drawCircle(sun, 23, Paint()..color = const Color(0xFFFFE58A));
    _clouds(c, s, t, Colors.white, 0.92);
    _birds(c, s, t);
    _plane(c, s, t);
    _hills(c, s, sx, const Color(0xFFDDEFE3), const Color(0xFFE8F4EC));
  }

  void _birds(Canvas c, Size s, double t) {
    final p = ((t + 6) / 26) % 1;
    final gx = -90 + p * (s.width + 150);
    final gy = 124 - p * 44;
    final paint = Paint()
      ..color = const Color(0xFF35574A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    const birds = [[0.0, 8.0, 0.0], [26.0, 0.0, 0.15], [30.0, 18.0, 0.3], [54.0, 10.0, 0.1]];
    for (final b in birds) {
      final flap = math.cos((t + b[2]) * 2 * math.pi / 0.55); // 1 .. -1
      final f = 0.25 + 0.75 * (flap + 1) / 2; // tinggi sayap
      final x = gx + b[0], y = gy + b[1];
      final path = Path()
        ..moveTo(x + 1, y + 6)
        ..quadraticBezierTo(x + 6, y + 6 - 6 * f, x + 11, y + 6)
        ..quadraticBezierTo(x + 16, y + 6 - 6 * f, x + 21, y + 6);
      c.drawPath(path, paint);
    }
  }

  void _plane(Canvas c, Size s, double t) {
    // Titik kunci [x, y, sudut] seperti versi desain.
    const keys = [
      [-60.0, 46.0, 10.0], [40.0, 12.0, -8.0], [140.0, 40.0, 9.0],
      [240.0, 8.0, -8.0], [340.0, 34.0, 8.0], [460.0, 6.0, -6.0],
    ];
    final p = ((t + 3) / 19) % 1 * (keys.length - 1);
    final i = p.floor().clamp(0, keys.length - 2);
    final f = Curves.easeInOut.transform(p - i);
    double lerp(int k) => keys[i][k] + (keys[i + 1][k] - keys[i][k]) * f;
    final scaleX = (s.width + 70) / 520;
    final x = -60 + (lerp(0) + 60) * scaleX;
    final y = 168 + lerp(1);
    c.save();
    c.translate(x, y);
    c.rotate(lerp(2) * math.pi / 180);
    final body = Path()
      ..moveTo(1, 11)
      ..lineTo(35, 1)
      ..lineTo(21, 23)
      ..lineTo(16, 14)
      ..close();
    c.drawPath(body, Paint()..color = Colors.white);
    final line = Paint()
      ..color = const Color(0xFF6E8F7E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(body, line);
    c.drawPath(
      Path()
        ..moveTo(16, 14)
        ..lineTo(35, 1)
        ..moveTo(16, 14)
        ..lineTo(13, 21)
        ..lineTo(21, 23),
      line,
    );
    c.restore();
  }

  void _night(Canvas c, Size s, double t, double sx) {
    final w = s.width;
    _gradient(c, s, const [Color(0xFF0F2D1D), Color(0xFF0C1D14), Color(0x000A100D)]);
    final moon = Offset(w - 61, 95);
    c.drawCircle(
      moon,
      85,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0x38F4EFC6), Color(0x00F4EFC6)], stops: [0, 0.65])
            .createShader(Rect.fromCircle(center: moon, radius: 85)),
    );
    // Bulan sabit
    c.save();
    c.translate(moon.dx - 23, moon.dy - 23);
    final crescent = Path()
      ..moveTo(30, 4)
      ..arcToPoint(const Offset(42, 34), radius: const Radius.circular(20), largeArc: true, clockwise: false)
      ..arcToPoint(const Offset(30, 4), radius: const Radius.circular(17), clockwise: true)
      ..close();
    c.drawPath(crescent, Paint()..color = const Color(0xFFF4EFC6));
    c.restore();
    // Bintang berkelip
    for (final st in _stars) {
      final a = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(t * 2 * math.pi / st[3] + st[0]));
      c.drawCircle(Offset(st[0] * sx, st[1]), st[2], Paint()..color = const Color(0xFFF4EFC6).withValues(alpha: a));
    }
    _clouds(c, s, t, const Color(0xFF2D4A3B), 0.55);
    _hills(c, s, sx, const Color(0xFF11281C), const Color(0xFF0E1F16));
    // Kunang-kunang
    for (final f in _flies) {
      final ph = (t + f[4]) * 2 * math.pi / f[2];
      final dx = 14 * math.sin(ph) - 6 * math.sin(2 * ph);
      final dy = -12 * (1 - math.cos(ph));
      final glow = 0.15 + 0.85 * (0.5 + 0.5 * math.sin((t + f[4]) * 2 * math.pi / f[3]));
      final o = Offset(f[0] * sx + dx, f[1] + dy);
      c.drawCircle(
        o,
        9,
        Paint()
          ..color = const Color(0xFFBEF264).withValues(alpha: 0.35 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      c.drawCircle(o, 2.5, Paint()..color = const Color(0xFFE3FF9E).withValues(alpha: glow));
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.night != night;
}
