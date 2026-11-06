import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/format.dart';
import '../widgets/common.dart';

/// Latar mode Produktif: ruang kelas dengan papan tulis, jendela, meja, dan bangku.
/// Setiap pindah halaman, penghapus menyapu papan, kapur menggambar ulang,
/// dan isi kelas bertambah (pensil, kalender dinding, buku & lampu, tanaman & lampu hias).
class ClassroomBackground extends StatefulWidget {
  const ClassroomBackground({super.key, required this.dark, required this.tab, required this.name});

  final bool dark;
  final int tab;
  final String name;

  /// Tinggi latar untuk lebar layar [w] (desain: 390 × 232).
  static double heightFor(double w) => w / 390 * 232;

  @override
  State<ClassroomBackground> createState() => _ClassroomBackgroundState();
}

class _ClassroomBackgroundState extends State<ClassroomBackground> with TickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker;
  late final AnimationController _level =
      AnimationController(vsync: this, lowerBound: 0, upperBound: 4, value: widget.tab.toDouble());
  late final AnimationController _chalk =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200), value: 1);
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
  void didUpdateWidget(covariant ClassroomBackground old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) {
      if (_reduce) {
        _level.value = widget.tab.toDouble();
      } else {
        _level.animateTo(widget.tab.toDouble(), duration: const Duration(milliseconds: 650), curve: Curves.easeOutBack);
        _chalk.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _level.dispose();
    _chalk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final s = w / 390;
        return SizedBox(
          width: w,
          height: ClassroomBackground.heightFor(w),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0, 0.8, 1],
            ).createShader(r),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: widget.dark ? 1 : 0),
              duration: const Duration(milliseconds: 450),
              builder: (context, night, _) => Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _BackPainter(night))),
                Positioned(
                  left: 264 * s,
                  top: 102 * s,
                  width: 104 * s,
                  height: 68 * s,
                  child: Stack(fit: StackFit.expand, children: [
                    Image.asset(Assets.sceneDay, fit: BoxFit.cover),
                    Opacity(opacity: night, child: Image.asset(Assets.sceneNight, fit: BoxFit.cover)),
                  ]),
                ),
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _FrontPainter(
                        time: _time,
                        level: _level,
                        chalk: _chalk,
                        night: night,
                        tab: widget.tab,
                        name: widget.name,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 14 * s,
                  top: 130 * s,
                  width: 112 * s,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: widget.tab == 0 ? 1 : 0,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _time,
                      builder: (context, t, child) =>
                          Transform.translate(offset: Offset(0, -4 * s * math.sin(t * math.pi / 2)), child: child),
                      child: Image.asset(Assets.dragonHappy),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

Color _mix(int day, int night, double t) => Color.lerp(Color(day), Color(night), t)!;

class _BackPainter extends CustomPainter {
  _BackPainter(this.night);

  final double night;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 390;
    canvas.scale(s);
    final p = Paint();
    canvas.drawRect(const Rect.fromLTWH(0, 0, 390, 190), p..color = _mix(0xFFEAF3EC, 0xFF102A1D, night));
    canvas.drawRect(const Rect.fromLTWH(0, 176, 390, 14), p..color = _mix(0xFFD6E7DA, 0xFF0C2016, night));
    canvas.drawRect(const Rect.fromLTWH(0, 190, 390, 42), p..color = _mix(0xFFD8C8A2, 0xFF17251C, night));
    final line = Paint()
      ..color = _mix(0xFFC5B38A, 0xFF12201A, night)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(0, 204), const Offset(390, 204), line);
    canvas.drawLine(const Offset(0, 219), const Offset(390, 219), line);
  }

  @override
  bool shouldRepaint(covariant _BackPainter old) => old.night != night;
}

class _FrontPainter extends CustomPainter {
  _FrontPainter({
    required this.time,
    required this.level,
    required this.chalk,
    required this.night,
    required this.tab,
    required this.name,
  }) : super(repaint: Listenable.merge([time, level, chalk]));

  final ValueNotifier<double> time;
  final Animation<double> level;
  final Animation<double> chalk;
  final double night;
  final int tab;
  final String name;

  double _pop(int n) => (level.value - (n - 1)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 390;
    canvas.save();
    canvas.scale(s);
    final t = time.value;
    final p = Paint();
    final frame = _mix(0xFF9C7A52, 0xFF4A3A28, night);
    final boardFrame = _mix(0xFF8B6B45, 0xFF4A3A28, night);
    final chalkColor = _mix(0xFFF4F7F2, 0xFFDCEBE1, night);
    final paper = _mix(0xFFFFFFFF, 0xFFDCEBE1, night);
    final hand = _mix(0xFF1F2937, 0xFFDCEBE1, night);
    final deskTop = _mix(0xFFD9B57C, 0xFF4A3B29, night);
    final deskLeg = _mix(0xFF8A6A44, 0xFF2A2018, night);

    // Sinar matahari dari jendela (siang).
    if (night < 1) {
      final beam = Path()
        ..moveTo(264, 170)
        ..lineTo(368, 170)
        ..lineTo(318, 232)
        ..lineTo(176, 232)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..shader = ui.Gradient.linear(const Offset(0, 170), const Offset(0, 232), [
            const Color(0xFFFFF3B8).withValues(alpha: 0.4 * (1 - night)),
            const Color(0x00FFF3B8),
          ]),
      );
    }

    // Jendela.
    final win = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(const Rect.fromLTWH(258, 96, 116, 80))
      ..addRect(const Rect.fromLTWH(264, 102, 104, 68));
    canvas.drawPath(win, p..color = frame);
    final mull = Paint()
      ..color = frame
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(316, 102), const Offset(316, 170), mull);
    canvas.drawLine(const Offset(264, 136), const Offset(368, 136), mull);
    canvas.drawRRect(RRect.fromLTRBR(252, 176, 380, 181, const Radius.circular(2)), p..color = frame);
    final curtain = _mix(0xFFBEE3C8, 0xFF1F4A35, night);
    for (final (x, dir, phase) in [(258.0, 1.0, 0.0), (374.0, -1.0, 2.0)]) {
      canvas.save();
      canvas.translate(x, 96);
      canvas.skew(0.04 * math.sin((t + phase) * math.pi / 3), 0);
      final c = Path()
        ..moveTo(0, 0)
        ..lineTo(22 * dir, 0)
        ..quadraticBezierTo(14 * dir, 40, 19 * dir, 80)
        ..lineTo(0, 80)
        ..close();
      canvas.drawPath(c, p..color = curtain);
      canvas.restore();
    }

    // Papan tulis.
    canvas.drawRRect(RRect.fromLTRBR(12, 94, 242, 176, const Radius.circular(5)), p..color = boardFrame);
    canvas.drawRRect(RRect.fromLTRBR(16, 98, 238, 172, const Radius.circular(2)), p..color = _mix(0xFF2F6B4C, 0xFF0B2A1C, night));
    canvas.drawRRect(RRect.fromLTRBR(40, 172, 210, 176, const Radius.circular(2)), p..color = boardFrame);
    canvas.drawRRect(RRect.fromLTRBR(150, 169, 164, 172, const Radius.circular(1.5)), p..color = chalkColor);
    canvas.drawRRect(RRect.fromLTRBR(170, 170, 178, 172, const Radius.circular(1)), p..color = const Color(0xFFFCD34D));
    _drawChalk(canvas, chalkColor);

    // Jam dinding (waktu sungguhan).
    const cc = Offset(206, 70);
    canvas.drawCircle(cc, 19, p..color = _mix(0xFFFFFFFF, 0xFF1E3A2B, night));
    canvas.drawCircle(
        cc,
        19,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = boardFrame);
    final hp = Paint()
      ..color = hand
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      canvas.drawLine(cc + Offset(math.sin(a), -math.cos(a)) * 14, cc + Offset(math.sin(a), -math.cos(a)) * 16.5, hp..strokeWidth = 1.6);
    }
    final now = DateTime.now();
    final ma = (now.minute + now.second / 60) / 60 * 2 * math.pi;
    final ha = ((now.hour % 12) + now.minute / 60) / 12 * 2 * math.pi;
    canvas.drawLine(cc, cc + Offset(math.sin(ma), -math.cos(ma)) * 12, hp..strokeWidth = 2);
    canvas.drawLine(cc, cc + Offset(math.sin(ha), -math.cos(ha)) * 7.5, hp..strokeWidth = 2.6);

    // Lampu hias (level 4).
    final p4 = _pop(4);
    if (p4 > 0) {
      final wire = Path()
        ..moveTo(6, 8)
        ..quadraticBezierTo(100, 36, 195, 14)
        ..quadraticBezierTo(290, -8, 384, 10);
      canvas.drawPath(
          wire,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = frame.withValues(alpha: p4));
      const bulbs = [(36.0, 19.0, 0xFFFCD34D), (84.0, 26.0, 0xFFF9A8D4), (132.0, 27.0, 0xFF86EFAC), (180.0, 20.0, 0xFF93C5FD),
        (228.0, 14.0, 0xFFFCD34D), (276.0, 18.0, 0xFFF9A8D4), (324.0, 18.0, 0xFF86EFAC), (366.0, 12.0, 0xFF93C5FD)];
      for (var i = 0; i < bulbs.length; i++) {
        final (x, y, c) = bulbs[i];
        final tw = 0.55 + 0.45 * math.sin(t * 2.2 + i * 1.3);
        if (night > 0) canvas.drawCircle(Offset(x, y), 7, Paint()..color = Color(c).withValues(alpha: 0.4 * night * p4 * tw));
        canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = Color(c).withValues(alpha: p4 * tw));
      }
    }

    // Kalender dinding (level 2).
    final p2 = _pop(2);
    if (p2 > 0) {
      canvas.save();
      canvas.translate(0, (1 - p2) * 10);
      final a = p2;
      canvas.drawRRect(RRect.fromLTRBR(146, 52, 182, 92, const Radius.circular(4)), Paint()..color = paper.withValues(alpha: a));
      canvas.drawRRect(
          RRect.fromLTRBAndCorners(146, 52, 182, 62, topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
          Paint()..color = const Color(0xFFEF4444).withValues(alpha: a));
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          final hl = r == 1 && c == 1;
          canvas.drawCircle(Offset(154.0 + c * 10, 70.0 + r * 8), hl ? 3.4 : 1.6,
              Paint()..color = (hl ? const Color(0xFF22C55E) : hand).withValues(alpha: a));
        }
      }
      canvas.restore();
    }

    // Bangku & meja.
    final chair = _mix(0xFF6FA283, 0xFF1F4A35, night);
    for (final x in [56.0, 186.0, 316.0]) {
      canvas.drawRRect(RRect.fromLTRBR(x, 170, x + 34, 192, const Radius.circular(7)), p..color = chair);
    }
    for (final x in [26.0, 99.0, 156.0, 229.0, 286.0, 359.0]) {
      canvas.drawRect(Rect.fromLTWH(x, 192, 5, 22), p..color = deskLeg);
    }
    for (final x in [20.0, 150.0, 280.0]) {
      canvas.drawRRect(RRect.fromLTRBR(x, 186, x + 90, 194, const Radius.circular(3)), p..color = deskTop);
    }

    // Level 1: pensil, buku tulis, apel di meja 1.
    final p1 = _pop(1);
    if (p1 > 0) {
      canvas.save();
      canvas.translate(0, (1 - p1) * 10);
      final a = Paint();
      canvas.drawRRect(RRect.fromLTRBR(34, 174, 44, 186, const Radius.circular(2)), a..color = const Color(0xFFE9A23B).withValues(alpha: p1));
      final pen = Paint()
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(36, 174), const Offset(35, 170), pen..color = const Color(0xFFEF4444).withValues(alpha: p1));
      canvas.drawLine(const Offset(40, 174), const Offset(40, 169), pen..color = const Color(0xFFEF4444).withValues(alpha: p1));
      canvas.drawLine(const Offset(42, 174), const Offset(44, 170), pen..color = const Color(0xFF3B82F6).withValues(alpha: p1));
      canvas.drawRRect(RRect.fromLTRBR(52, 181, 72, 186, const Radius.circular(1.5)), a..color = paper.withValues(alpha: p1));
      canvas.drawCircle(const Offset(88, 181), 5, a..color = const Color(0xFFEF4444).withValues(alpha: p1));
      canvas.restore();
    }

    // Level 3: buku, lampu meja (menyala saat malam), pesawat kertas.
    final p3 = _pop(3);
    if (p3 > 0) {
      canvas.save();
      canvas.translate(0, (1 - p3) * 10);
      if (night > 0) {
        canvas.drawCircle(
          const Offset(226, 168),
          30,
          Paint()
            ..shader = ui.Gradient.radial(const Offset(226, 168), 30, [
              const Color(0xFFFFD66B).withValues(alpha: 0.6 * night * p3),
              const Color(0x00FFD66B),
            ]),
        );
      }
      final a = Paint();
      canvas.drawRRect(RRect.fromLTRBR(160, 178, 188, 186, const Radius.circular(1.5)), a..color = const Color(0xFF3B82F6).withValues(alpha: p3));
      canvas.drawRRect(RRect.fromLTRBR(162, 171, 186, 178, const Radius.circular(1.5)), a..color = const Color(0xFFF59E0B).withValues(alpha: p3));
      canvas.drawRRect(RRect.fromLTRBR(194, 180, 214, 186, const Radius.circular(1.5)), a..color = paper.withValues(alpha: p3));
      canvas.drawRRect(RRect.fromLTRBR(218, 183, 230, 186, const Radius.circular(1.5)), a..color = deskLeg.withValues(alpha: p3));
      final arm = Path()
        ..moveTo(224, 183)
        ..lineTo(219, 168)
        ..lineTo(231, 163);
      canvas.drawPath(
          arm,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..color = deskLeg.withValues(alpha: p3));
      final shade = Path()
        ..moveTo(227, 160)
        ..lineTo(241, 154)
        ..lineTo(245, 163)
        ..lineTo(231, 169)
        ..close();
      canvas.drawPath(shade, a..color = const Color(0xFF22C55E).withValues(alpha: p3));
      canvas.restore();

      // Pesawat kertas melintas.
      final k = (t % 15) / 15;
      final px = -50 + 480 * k;
      final py = 60 - 18 * math.sin(k * math.pi * 2);
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(0.12 * math.sin(k * math.pi * 4));
      final plane = Path()
        ..moveTo(0, 9)
        ..lineTo(28, 0)
        ..lineTo(17, 18)
        ..lineTo(13, 11)
        ..close();
      canvas.drawPath(plane, Paint()..color = paper.withValues(alpha: p3));
      canvas.drawPath(
          plane,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = boardFrame.withValues(alpha: p3));
      canvas.restore();
    }

    // Level 4: tanaman di meja 3.
    if (p4 > 0) {
      canvas.save();
      canvas.translate(0, (1 - p4) * 10);
      canvas.drawRRect(RRect.fromLTRBR(312, 176, 328, 186, const Radius.circular(2)), Paint()..color = const Color(0xFFC2703D).withValues(alpha: p4));
      for (final (dx, rot, c) in [(-4.0, -0.42, 0xFF22A559), (4.0, 0.42, 0xFF16A34A), (0.0, 0.0, 0xFF4ADE80)]) {
        canvas.save();
        canvas.translate(320 + dx, 167);
        canvas.rotate(rot);
        canvas.drawOval(const Rect.fromLTWH(-4, -8, 8, 16), Paint()..color = Color(c).withValues(alpha: p4));
        canvas.restore();
      }
      canvas.restore();
    }

    canvas.restore();
  }

  void _drawChalk(Canvas canvas, Color color) {
    final c = chalk.value;
    // Penghapus menyapu papan dulu (0 → 0.35), lalu kapur menggambar (0.35 → 1).
    final draw = ((c - 0.35) / 0.65).clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(16, 98, 238, 172));
    if (tab == 0) {
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(style: TextStyle(color: color.withValues(alpha: draw), fontFamily: 'PlusJakartaSans'), children: [
          TextSpan(text: '${greeting()},\n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          TextSpan(text: name.isEmpty ? 'Razarsa' : name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.25)),
        ]),
      )..layout(maxWidth: 200);
      tp.paint(canvas, const Offset(28, 108));
    } else {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color;
      final gold = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFCD34D);
      final parts = _chalkParts(tab, stroke, gold);
      for (var i = 0; i < parts.length; i++) {
        final start = i / parts.length * 0.7;
        final local = ((draw - start) / 0.3).clamp(0.0, 1.0);
        if (local <= 0) continue;
        _partial(canvas, parts[i].$1, local, parts[i].$2);
      }
    }
    if (c < 0.4) {
      final x = -28 + 284 * (c / 0.4);
      final alpha = c < 0.05 ? c / 0.05 : (c > 0.35 ? (0.4 - c) / 0.05 : 1.0);
      canvas.drawRRect(RRect.fromLTRBR(x, 106, x + 32, 164, const Radius.circular(6)),
          Paint()..color = const Color(0xFF8B6B45).withValues(alpha: alpha));
      canvas.drawRRect(RRect.fromLTRBR(x, 152, x + 32, 164, const Radius.circular(6)),
          Paint()..color = const Color(0xFFE5E7EB).withValues(alpha: alpha));
      canvas.drawRect(Rect.fromLTRB(x - 30, 106, x, 164),
          Paint()
            ..shader = ui.Gradient.linear(Offset(x - 30, 0), Offset(x, 0), [
              const Color(0x00F4F7F2),
              color.withValues(alpha: 0.25 * alpha),
            ]));
    }
    canvas.restore();
  }

  static Path _p(void Function(Path) f) {
    final p = Path();
    f(p);
    return p;
  }

  List<(Path, Paint)> _chalkParts(int tab, Paint chalk, Paint gold) {
    switch (tab) {
      case 1: // To-do: kotak centang
        return [
          for (final y in [112.0, 132.0, 152.0]) ...[
            (_p((p) => p.addRect(Rect.fromLTWH(30, y, 11, 11))), chalk),
            if (y < 150)
              (_p((p) => p
                ..moveTo(32, y + 6)
                ..lineTo(35, y + 9)
                ..lineTo(41, y + 2)), gold),
            (_p((p) => p
              ..moveTo(52, y + 6)
              ..lineTo(y == 132 ? 106 : (y == 112 ? 122 : 142), y + 6)), chalk),
          ],
        ];
      case 2: // Kalender: tabel tanggal
        return [
          (_p((p) => p.addRect(const Rect.fromLTWH(30, 106, 104, 58))), chalk),
          (_p((p) {
            for (final y in [120.0, 135.0, 149.0]) {
              p
                ..moveTo(30, y)
                ..lineTo(134, y);
            }
          }), chalk),
          (_p((p) {
            for (final x in [56.0, 82.0, 108.0]) {
              p
                ..moveTo(x, 106)
                ..lineTo(x, 164);
            }
          }), chalk),
          (_p((p) => p.addOval(Rect.fromCenter(center: const Offset(95, 142), width: 22, height: 16))), gold),
          (_p((p) => p
            ..moveTo(160, 120)
            ..lineTo(220, 120)
            ..moveTo(160, 138)
            ..lineTo(204, 138)), chalk),
        ];
      case 3: // Catatan: coretan & bintang
        Path wave(double y, int n) => _p((p) {
              p.moveTo(30, y);
              for (var i = 0; i < n; i++) {
                p.quadraticBezierTo(35 + i * 10, y - 7, 40 + i * 10, y);
              }
            });
        return [
          (wave(114, 8), chalk),
          (wave(132, 5), chalk),
          (_p((p) {
            const c = Offset(196, 128);
            for (var i = 0; i <= 10; i++) {
              final r = i.isEven ? 16.0 : 7.0;
              final a = -math.pi / 2 + i * math.pi / 5;
              final o = c + Offset(math.cos(a), math.sin(a)) * r;
              i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
            }
          }), gold),
          (_p((p) => p
            ..moveTo(30, 150)
            ..lineTo(126, 150)), gold),
        ];
      default: // Pengaturan: roda gigi & slider
        return [
          (_p((p) => p.addOval(Rect.fromCircle(center: const Offset(64, 135), radius: 13))), chalk),
          (_p((p) => p.addOval(Rect.fromCircle(center: const Offset(64, 135), radius: 5))), chalk),
          (_p((p) {
            for (var i = 0; i < 8; i++) {
              final a = i * math.pi / 4;
              final d = Offset(math.cos(a), math.sin(a));
              final a1 = const Offset(64, 135) + d * 15;
              final a2 = const Offset(64, 135) + d * 20;
              p
                ..moveTo(a1.dx, a1.dy)
                ..lineTo(a2.dx, a2.dy);
            }
          }), chalk),
          (_p((p) {
            for (final y in [120.0, 135.0, 150.0]) {
              p
                ..moveTo(110, y)
                ..lineTo(220, y);
            }
          }), chalk),
          (_p((p) {
            for (final (x, y) in [(150.0, 120.0), (190.0, 135.0), (136.0, 150.0)]) {
              p.addOval(Rect.fromCircle(center: Offset(x, y), radius: 4));
            }
          }), gold),
        ];
    }
  }

  void _partial(Canvas canvas, Path path, double t, Paint paint) {
    if (t >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    final out = Path();
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    var left = total * t;
    for (final m in metrics) {
      if (left <= 0) break;
      final len = math.min(left, m.length);
      out.addPath(m.extractPath(0, len), Offset.zero);
      left -= len;
    }
    canvas.drawPath(out, paint);
  }

  @override
  bool shouldRepaint(covariant _FrontPainter old) => old.night != night || old.tab != tab || old.name != name;
}
