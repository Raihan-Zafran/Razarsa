import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Latar bergerak di bagian atas layar.
/// Siang: matahari, awan, burung, pesawat kertas. Malam: bulan, bintang, awan redup, kunang-kunang.
class SkyBackground extends StatefulWidget {
  const SkyBackground({super.key, required this.dark, this.height = 340});

  final bool dark;
  final double height;

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(20);
  late final Ticker _ticker;

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
              child: CustomPaint(painter: _SkyPainter(_time, night), size: Size.infinite),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.time, this.night) : super(repaint: time);

  final ValueNotifier<double> time;
  final double night;

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
