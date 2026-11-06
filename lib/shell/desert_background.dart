import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Latar mode Keuangan: gurun dengan bukit pasir.
/// Setiap pindah halaman seekor kadal berlari ke atas batu dan mengangguk,
/// dan isi gurun bertambah: kaktus → rumput kering & tumbleweed → oasis & pohon kurma → bukit batu.
/// Malam: bulan, banyak bintang, oasis memantulkan bulan, kunang-kunang.
class DesertBackground extends StatefulWidget {
  const DesertBackground({super.key, required this.dark, required this.tab});

  final bool dark;
  final int tab;

  /// Tinggi latar untuk lebar layar [w] (desain: 390 × 300).
  static double heightFor(double w) => w / 390 * 300;

  @override
  State<DesertBackground> createState() => _DesertBackgroundState();
}

class _DesertBackgroundState extends State<DesertBackground> with TickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker;
  late final AnimationController _level =
      AnimationController(vsync: this, lowerBound: 0, upperBound: 4, value: widget.tab.toDouble());
  late final AnimationController _lizard =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600), value: 0);
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce && _ticker.isActive) _ticker.stop();
    if (!_reduce && !_ticker.isActive) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant DesertBackground old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) {
      if (_reduce) {
        _level.value = widget.tab.toDouble();
        _lizard.value = 1;
      } else {
        _level.animateTo(widget.tab.toDouble(), duration: const Duration(milliseconds: 700), curve: Curves.easeOutBack);
        _lizard.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _level.dispose();
    _lizard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        return SizedBox(
          width: w,
          height: DesertBackground.heightFor(w),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0, 0.74, 1],
            ).createShader(r),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: widget.dark ? 1 : 0),
              duration: const Duration(milliseconds: 450),
              builder: (context, night, _) => RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _DesertPainter(time: _time, level: _level, lizard: _lizard, night: night),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

Color _mix(int day, int night, double t) => Color.lerp(Color(day), Color(night), t)!;

class _DesertPainter extends CustomPainter {
  _DesertPainter({required this.time, required this.level, required this.lizard, required this.night})
      : super(repaint: Listenable.merge([time, level, lizard]));

  final ValueNotifier<double> time;
  final Animation<double> level;
  final Animation<double> lizard;
  final double night;

  double _pop(int n) => (level.value - (n - 1)).clamp(0.0, 1.0);

  // Bintang tetap (posisi acak tapi sama setiap kali).
  static final _stars = () {
    final r = math.Random(7);
    return List.generate(48, (_) => (r.nextDouble() * 390, r.nextDouble() * 150, 0.6 + r.nextDouble() * 1.2, r.nextDouble() * 6));
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 390;
    canvas.save();
    canvas.scale(s);
    final t = time.value;
    final day = 1 - night;

    // ---------- Langit ----------
    final sky = Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(0, 220), [
        _mix(0xFFF9D9A6, 0xFF120F2E, night),
        _mix(0xFFFCE9C9, 0xFF2A1F4A, night),
        _mix(0xFFFDF2E0, 0xFF3A2A55, night),
      ], [0, 0.6, 1]);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 390, 300), sky);

    // Bintang
    if (night > 0) {
      for (final (x, y, r, ph) in _stars) {
        final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 1.6 + ph));
        canvas.drawCircle(Offset(x, y), r, Paint()..color = const Color(0xFFFFF6D6).withValues(alpha: night * tw));
      }
    }

    // Matahari / bulan
    const sun = Offset(318, 72);
    canvas.drawCircle(
      sun,
      70,
      Paint()
        ..shader = ui.Gradient.radial(sun, 70, [
          _mix(0xFFFFE7A3, 0xFFF4EFC6, night).withValues(alpha: day * 0.55 + night * 0.18),
          const Color(0x00FFE7A3),
        ]),
    );
    if (day > 0) canvas.drawCircle(sun, 24, Paint()..color = const Color(0xFFFFD36B).withValues(alpha: day));
    if (night > 0) {
      final moon = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: sun, radius: 20))
        ..addOval(Rect.fromCircle(center: sun + const Offset(9, -6), radius: 17));
      canvas.drawPath(moon, Paint()..color = const Color(0xFFF4EFC6).withValues(alpha: night));
    }

    // Awan tipis (siang)
    if (day > 0) {
      for (final (y, speed, w, off) in [(46.0, 9.0, 70.0, 0.0), (96.0, 6.0, 52.0, 180.0)]) {
        final x = (t * speed + off) % 520 - 80;
        final c = Paint()..color = Colors.white.withValues(alpha: 0.85 * day);
        canvas.drawRRect(RRect.fromLTRBR(x, y, x + w, y + 12, const Radius.circular(6)), c);
        canvas.drawCircle(Offset(x + w * 0.35, y + 2), 9, c);
        canvas.drawCircle(Offset(x + w * 0.62, y), 12, c);
      }
    }

    // Hembusan angin
    final wind = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = _mix(0xFFFFFFFF, 0xFFBFB4E6, night).withValues(alpha: 0.55);
    for (final (y, speed, ph) in [(112.0, 70.0, 0.0), (132.0, 90.0, 140.0), (88.0, 55.0, 260.0)]) {
      final x = (t * speed + ph) % 560 - 120;
      final p = Path()
        ..moveTo(x, y)
        ..cubicTo(x + 20, y - 6, x + 40, y + 6, x + 60, y)
        ..quadraticBezierTo(x + 70, y - 4, x + 66, y - 8);
      canvas.drawPath(p, wind);
    }

    // ---------- Bukit batu (level 4) ----------
    final p4 = _pop(4);
    if (p4 > 0) {
      canvas.save();
      canvas.translate(0, (1 - p4) * 14);
      final mesa = Path()
        ..moveTo(-10, 160)
        ..lineTo(10, 128)
        ..lineTo(58, 126)
        ..lineTo(72, 144)
        ..lineTo(96, 140)
        ..lineTo(110, 122)
        ..lineTo(150, 120)
        ..lineTo(168, 160)
        ..close();
      canvas.drawPath(mesa, Paint()..color = _mix(0xFFD08B5B, 0xFF3A2440, night).withValues(alpha: p4));
      final ridge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _mix(0xFFB06E45, 0xFF2A1A33, night).withValues(alpha: p4);
      canvas.drawLine(const Offset(18, 136), const Offset(52, 134), ridge);
      canvas.drawLine(const Offset(116, 130), const Offset(146, 128), ridge);
      canvas.restore();
    }

    // ---------- Bukit pasir ----------
    Path dune(double base, List<double> ys) {
      final p = Path()..moveTo(0, ys.first);
      final step = 390 / (ys.length - 1);
      for (var i = 1; i < ys.length; i++) {
        final x0 = step * (i - 1), x1 = step * i;
        p.cubicTo(x0 + step / 2, ys[i - 1], x0 + step / 2, ys[i], x1, ys[i]);
      }
      p
        ..lineTo(390, base)
        ..lineTo(0, base)
        ..close();
      return p;
    }

    canvas.drawPath(dune(300, [150, 140, 152, 138, 150, 144]), Paint()..color = _mix(0xFFF3D39E, 0xFF3B2F5C, night));
    canvas.drawPath(dune(300, [182, 168, 176, 160, 174, 166]), Paint()..color = _mix(0xFFEBBE7C, 0xFF30264F, night));

    // ---------- Oasis & pohon kurma (level 3) ----------
    final p3 = _pop(3);
    if (p3 > 0) {
      canvas.save();
      canvas.translate(0, (1 - p3) * 10);
      final pond = Rect.fromCenter(center: const Offset(250, 188), width: 128, height: 22);
      canvas.drawOval(pond.inflate(4), Paint()..color = _mix(0xFFB9D98A, 0xFF1F3A2E, night).withValues(alpha: p3));
      canvas.drawOval(
        pond,
        Paint()
          ..shader = ui.Gradient.linear(pond.topCenter, pond.bottomCenter, [
            _mix(0xFF5EC8E5, 0xFF1D3B6E, night).withValues(alpha: p3),
            _mix(0xFF2E9CC4, 0xFF142B52, night).withValues(alpha: p3),
          ]),
      );
      // Pantulan matahari/bulan + kilau bergerak
      canvas.drawOval(Rect.fromCenter(center: const Offset(274, 186), width: 26, height: 5),
          Paint()..color = _mix(0xFFFFF1B8, 0xFFF4EFC6, night).withValues(alpha: 0.75 * p3));
      for (var i = 0; i < 6; i++) {
        final k = (t * 0.5 + i / 6) % 1;
        final x = 200 + i * 18 + 6 * math.sin(t + i);
        final a = math.sin(k * math.pi);
        canvas.drawLine(Offset(x, 183 + (i % 3) * 4), Offset(x + 7, 183 + (i % 3) * 4),
            Paint()
              ..strokeWidth = 1.3
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: 0.8 * a * p3));
      }
      // Pohon kurma
      final sway = 0.05 * math.sin(t * 1.3);
      canvas.save();
      canvas.translate(304, 190);
      canvas.rotate(sway);
      final trunk = Path()
        ..moveTo(-3, 0)
        ..quadraticBezierTo(-8, -26, 2, -52)
        ..lineTo(6, -52)
        ..quadraticBezierTo(-2, -26, 3, 0)
        ..close();
      canvas.drawPath(trunk, Paint()..color = _mix(0xFF9A6B3F, 0xFF3A2A2A, night).withValues(alpha: p3));
      final leaf = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = _mix(0xFF3E9B4F, 0xFF1E4A36, night).withValues(alpha: p3);
      for (final a in [-2.6, -2.0, -1.2, -0.5, 0.2]) {
        final end = Offset(4 + 26 * math.cos(a), -52 + 16 * math.sin(a) + 10);
        final ctrl = Offset(4 + 14 * math.cos(a), -60);
        canvas.drawPath(
            Path()
              ..moveTo(4, -52)
              ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy),
            leaf);
      }
      canvas.restore();
      // Kunang-kunang di oasis (malam)
      if (night > 0) {
        for (var i = 0; i < 6; i++) {
          final fx = 210 + 80 * ((math.sin(t * 0.4 + i * 1.7) + 1) / 2);
          final fy = 168 + 12 * math.sin(t * 0.9 + i);
          final glow = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 2.4 + i * 2));
          canvas.drawCircle(Offset(fx, fy), 4, Paint()..color = const Color(0xFFE3FF9E).withValues(alpha: 0.25 * night * glow * p3));
          canvas.drawCircle(Offset(fx, fy), 1.6, Paint()..color = const Color(0xFFE3FF9E).withValues(alpha: night * glow * p3));
        }
      }
      canvas.restore();
    }

    // Bukit pasir terdekat
    canvas.drawPath(dune(300, [214, 204, 210, 198, 208, 202]), Paint()..color = _mix(0xFFE0A866, 0xFF251E42, night));
    canvas.drawPath(
        Path()
          ..moveTo(0, 214)
          ..cubicTo(39, 214, 39, 204, 78, 204)
          ..cubicTo(117, 204, 117, 210, 156, 210),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _mix(0xFFF6CE92, 0xFF3D3366, night));

    // ---------- Kaktus (level 1) ----------
    final p1 = _pop(1);
    if (p1 > 0) {
      canvas.save();
      canvas.translate(0, (1 - p1) * 12);
      final cactus = Paint()..color = _mix(0xFF4E9A5A, 0xFF1F3F33, night).withValues(alpha: p1);
      final rib = Paint()
        ..strokeWidth = 1
        ..color = _mix(0xFF3B7E46, 0xFF173027, night).withValues(alpha: p1);
      canvas.drawRRect(RRect.fromLTRBR(88, 156, 100, 208, const Radius.circular(6)), cactus);
      canvas.drawRRect(RRect.fromLTRBR(76, 172, 84, 192, const Radius.circular(4)), cactus);
      canvas.drawRRect(RRect.fromLTRBR(76, 186, 92, 193, const Radius.circular(3)), cactus);
      canvas.drawRRect(RRect.fromLTRBR(104, 164, 112, 184, const Radius.circular(4)), cactus);
      canvas.drawRRect(RRect.fromLTRBR(96, 178, 112, 185, const Radius.circular(3)), cactus);
      canvas.drawLine(const Offset(94, 160), const Offset(94, 205), rib);
      if (day > 0) canvas.drawCircle(const Offset(94, 155), 3, Paint()..color = const Color(0xFFF472B6).withValues(alpha: p1 * day));
      // Kaktus bulat kecil
      canvas.drawOval(const Rect.fromLTRB(352, 196, 370, 210), cactus);
      canvas.drawLine(const Offset(361, 197), const Offset(361, 209), rib);
      canvas.restore();
    }

    // ---------- Rumput kering & tumbleweed (level 2) ----------
    final p2 = _pop(2);
    if (p2 > 0) {
      final grass = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = _mix(0xFFB98A45, 0xFF5A4A6E, night).withValues(alpha: p2);
      for (final (bx, by, ph) in [(140.0, 208.0, 0.0), (196.0, 204.0, 1.3), (330.0, 206.0, 2.4), (30.0, 214.0, 3.1)]) {
        for (var i = -2; i <= 2; i++) {
          final bend = 5 * math.sin(t * 2.2 + ph + i * 0.4) + 3;
          canvas.drawPath(
              Path()
                ..moveTo(bx + i * 2.5, by)
                ..quadraticBezierTo(bx + i * 3 + bend * 0.5, by - 8, bx + i * 4 + bend, by - 14 + i.abs() * 2),
              grass);
        }
      }
      // Tumbleweed menggelinding
      final k = (t / 11) % 1;
      final tx = -30 + 450 * k;
      final ty = 200 - 6 * (math.sin(k * math.pi * 6)).abs();
      canvas.save();
      canvas.translate(tx, ty);
      canvas.rotate(t * 3);
      final tw = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _mix(0xFFA87C40, 0xFF6A5A80, night).withValues(alpha: p2);
      canvas.drawCircle(Offset.zero, 8, tw);
      for (var i = 0; i < 5; i++) {
        final a = i * math.pi / 5;
        canvas.drawLine(Offset(math.cos(a), math.sin(a)) * -7, Offset(math.cos(a + 1), math.sin(a + 1)) * 7, tw);
      }
      canvas.restore();
    }

    // ---------- Batu & kadal ----------
    final rock = Path()
      ..moveTo(36, 214)
      ..quadraticBezierTo(38, 198, 54, 196)
      ..quadraticBezierTo(70, 194, 74, 206)
      ..quadraticBezierTo(76, 214, 72, 216)
      ..close();
    canvas.drawPath(rock, Paint()..color = _mix(0xFFB98B62, 0xFF3E3355, night));
    canvas.drawPath(
        Path()
          ..moveTo(44, 204)
          ..quadraticBezierTo(54, 198, 66, 200),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _mix(0xFFD6AC82, 0xFF4E4268, night));
    _drawLizard(canvas, lizard.value, t);

    canvas.restore();
  }

  /// Kadal berlari dari kiri ke atas batu, lalu mengangguk (push-up khas kadal).
  void _drawLizard(Canvas canvas, double v, double t) {
    if (v <= 0) return;
    final run = (v / 0.4).clamp(0.0, 1.0);
    final x = -30 + (52 - -30) * Curves.easeOut.transform(run);
    final y = 214 - 18 * Curves.easeOut.transform(((run - 0.6) / 0.4).clamp(0.0, 1.0));
    final bob = v > 0.45 ? 2.2 * (math.sin((v - 0.45) * 40)).abs() * (1 - v).clamp(0.2, 1.0) : 0.0;
    canvas.save();
    canvas.translate(x, y - bob);
    final body = Paint()..color = _mix(0xFF6E9E3A, 0xFF7C8F4A, night);
    final dark = Paint()..color = _mix(0xFF4F7A26, 0xFF55663A, night);
    // ekor
    canvas.drawPath(
        Path()
          ..moveTo(-6, -1)
          ..quadraticBezierTo(-16, 2, -22, -2 + 2 * math.sin(t * 6))
          ..lineTo(-6, 1)
          ..close(),
        body);
    // badan & kepala
    canvas.drawOval(const Rect.fromLTRB(-8, -4, 8, 2), body);
    canvas.drawOval(const Rect.fromLTRB(6, -6, 14, 0), body);
    canvas.drawCircle(const Offset(11.5, -4), 0.9, Paint()..color = Colors.black);
    // kaki (bergerak saat berlari)
    final step = run < 1 ? math.sin(t * 30) * 2 : 0.0;
    final leg = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = dark.color;
    canvas.drawLine(const Offset(-4, 1), Offset(-7 + step, 4), leg);
    canvas.drawLine(const Offset(4, 1), Offset(7 - step, 4), leg);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DesertPainter old) => old.night != night;
}
