import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'desert_art.dart';

/// Latar mode Keuangan: gurun (sesuai desain di kanvas).
/// Setiap pindah halaman seekor kadal berlari ke atas batu, dan isi gurun bertambah:
/// kaktus → agave, rumput kering & tumbleweed → oasis & pohon kurma → tebing batu.
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
  late final AnimationController _lizard = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _reduce = false;
  bool _lizardShown = false;

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
      _lizardShown = true;
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
        final h = DesertBackground.heightFor(w);
        return SizedBox(
          width: w,
          height: h,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0, 0.74, 1],
            ).createShader(r),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              child: _Scene(
                key: ValueKey(widget.dark),
                dark: widget.dark,
                w: w,
                h: h,
                time: _time,
                level: _level,
                lizard: _lizard,
                lizardShown: _lizardShown,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Scene extends StatelessWidget {
  const _Scene({
    super.key,
    required this.dark,
    required this.w,
    required this.h,
    required this.time,
    required this.level,
    required this.lizard,
    required this.lizardShown,
  });

  final bool dark;
  final double w;
  final double h;
  final ValueNotifier<double> time;
  final Animation<double> level;
  final Animation<double> lizard;
  final bool lizardShown;

  static final Map<String, String> _cache = {};

  String _fill(String tpl) {
    final key = '$dark|$tpl';
    return _cache.putIfAbsent(key, () {
      final pal = dark ? kDesertNight : kDesertDay;
      return tpl.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
        final k = m.group(1)!;
        if (k == 'dayOp') return dark ? '0' : '1';
        return pal[k] ?? '#000000';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = w / 780; // satuan desain → piksel
    final layers = {for (final (n, svg) in kDesertLayers) n: _fill(svg)};

    Widget svg(String name) => Positioned.fill(child: SvgPicture.string(layers[name]!, fit: BoxFit.fill));

    // Lapisan yang muncul bertahap sesuai halaman.
    Widget pop(int n, Widget child) => Positioned.fill(
          child: AnimatedBuilder(
            animation: level,
            builder: (context, c) {
              final p = (level.value - (n - 1)).clamp(0.0, 1.0);
              if (p <= 0) return const SizedBox.shrink();
              return Opacity(opacity: p, child: Transform.translate(offset: Offset(0, (1 - p) * 20 * s), child: c));
            },
            child: child,
          ),
        );

    // Lapisan yang bergoyang di sekitar titik [ox, oy] (satuan desain).
    Widget sway(String name, double ox, double oy, double period, double from, double to, double phase) =>
        Positioned.fill(
          child: ValueListenableBuilder<double>(
            valueListenable: time,
            builder: (context, t, c) {
              final k = 0.5 + 0.5 * math.sin((t / period + phase) * 2 * math.pi);
              final a = (from + (to - from) * k) * math.pi / 180;
              final m = Matrix4.identity()
                ..translateByDouble(ox * s, oy * s, 0, 1)
                ..rotateZ(a)
                ..translateByDouble(-ox * s, -oy * s, 0, 1);
              return Transform(transform: m, child: c);
            },
            child: SvgPicture.string(layers[name]!, fit: BoxFit.fill),
          ),
        );

    final pal = dark ? kDesertNight : kDesertDay;
    return Stack(clipBehavior: Clip.hardEdge, children: [
      Positioned.fill(child: CustomPaint(painter: _SkyPainter(time: time, dark: dark, s: s))),
      pop(4, Stack(children: [svg('p4')])),
      svg('base1'),
      pop(1, Stack(children: [svg('p1far')])),
      svg('base2'),
      pop(3, Stack(children: [
        sway('palmSmall', 408, 372, 4.6, -2, 2.5, 0.2),
        svg('p3'),
        Positioned.fill(child: CustomPaint(painter: _GlintPainter(time: time, s: s, dark: dark))),
        sway('palmBig', 600, 380, 4, -2, 2.5, 0),
      ])),
      svg('base3'),
      pop(2, Stack(children: [
        svg('p2'),
        sway('grass0', 300, 420, 2.6, -6, 10, 0),
        sway('grass1', 512, 420, 3, -6, 10, 0.3),
        sway('grass2', 712, 428, 2.8, -6, 10, 0.5),
      ])),
      pop(1, Stack(children: [svg('p1')])),
      svg('rocks'),
      // Tumbleweed menggelinding (muncul bersama rumput kering).
      pop(2, Stack(children: [_Tumbleweed(time: time, s: s, svg: _fill(kTumbleweed), shadow: Color(int.parse(_rgbaHex(pal['shadow'] ?? '#000'), radix: 16)))])),
      if (dark) pop(3, Stack(children: [Positioned.fill(child: CustomPaint(painter: _FirefliesPainter(time: time, s: s)))])),
      if (lizardShown) _Lizard(anim: lizard, s: s, svg: _fill(kLizard)),
    ]);
  }

  /// Ubah 'rgba(r,g,b,a)' atau '#rrggbb' menjadi 'AARRGGBB'.
  static String _rgbaHex(String c) {
    final m = RegExp(r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)').firstMatch(c);
    if (m != null) {
      String h(int v) => v.toRadixString(16).padLeft(2, '0');
      final a = (double.parse(m.group(4)!) * 255).round();
      return h(a) + h(int.parse(m.group(1)!)) + h(int.parse(m.group(2)!)) + h(int.parse(m.group(3)!));
    }
    return 'FF${c.replaceAll('#', '').padLeft(6, '0')}';
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.time, required this.dark, required this.s}) : super(repaint: time);

  final ValueNotifier<double> time;
  final bool dark;
  final double s;

  static final _stars = () {
    final r = math.Random(3);
    return List.generate(30, (_) => (r.nextDouble() * 780, r.nextDouble() * 250, 1.6 + r.nextDouble() * 2, r.nextDouble() * 6));
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    canvas.save();
    canvas.scale(s);
    final rect = const Rect.fromLTWH(0, 0, 780, 600);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF120F2E), Color(0xFF2A1F4A), Color(0xFF3A2A55)]
              : const [Color(0xFFC4EBDA), Color(0xFFD9F3E6), Color(0xFFEAF7EF)],
          stops: const [0, 0.45, 0.75],
        ).createShader(rect),
    );
    const sun = Offset(646, 130);
    if (dark) {
      for (final (x, y, r, ph) in _stars) {
        final a = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 1.7 + ph));
        canvas.drawCircle(Offset(x, y), r, Paint()..color = const Color(0xFFFFF6D6).withValues(alpha: a));
      }
      canvas.drawCircle(
        sun,
        106,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x38F4EFC6), Color(0x00F4EFC6)])
              .createShader(Rect.fromCircle(center: sun, radius: 106)),
      );
      final moon = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: sun, radius: 40))
        ..addOval(Rect.fromCircle(center: sun + const Offset(18, -12), radius: 34));
      canvas.drawPath(moon, Paint()..color = const Color(0xFFF4EFC6));
    } else {
      canvas.drawCircle(sun, 50, Paint()..color = const Color(0xFFF9CB57));
    }
    // Awan bergerak
    final cloud = Paint()..color = dark ? const Color(0xFF3B3266).withValues(alpha: 0.55) : const Color(0xFFFBFBF2).withValues(alpha: 0.95);
    for (final (y, sc, speed, off) in [(36.0, 1.0, 9.0, 0.0), (140.0, 0.64, 6.5, 420.0)]) {
      final x = (t * speed + off) % 1100 - 240;
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(sc * 2);
      final p = Path()
        ..moveTo(4, 40)
        ..quadraticBezierTo(4, 30, 16, 30)
        ..quadraticBezierTo(18, 18, 32, 20)
        ..quadraticBezierTo(40, 4, 60, 8)
        ..quadraticBezierTo(74, 2, 82, 18)
        ..quadraticBezierTo(100, 14, 104, 28)
        ..quadraticBezierTo(118, 28, 118, 40)
        ..close();
      canvas.drawPath(p, cloud);
      canvas.restore();
    }
    // Hembusan angin
    final wind = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..color = dark ? const Color(0x80BFB4E6) : const Color(0xCCFFFFFF);
    for (final (y, period, ph) in [(196.0, 6.0, 0.0), (240.0, 8.0, 0.4)]) {
      final k = ((t / period) + ph) % 1;
      final x = -180 + 1040 * k;
      final a = k < 0.15 ? k / 0.15 : (k > 0.85 ? (1 - k) / 0.15 : 1.0);
      canvas.drawPath(
        Path()
          ..moveTo(x, y + 16)
          ..cubicTo(x + 40, y + 4, x + 80, y + 28, x + 120, y + 16)
          ..quadraticBezierTo(x + 140, y + 8, x + 132, y),
        wind..color = wind.color.withValues(alpha: (dark ? 0.5 : 0.8) * a),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.dark != dark || old.s != s;
}

class _GlintPainter extends CustomPainter {
  _GlintPainter({required this.time, required this.s, required this.dark}) : super(repaint: time);

  final ValueNotifier<double> time;
  final double s;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    canvas.save();
    canvas.scale(s);
    const glints = [(380.0, 374.0, 12.0, 1.6), (424.0, 386.0, 12.0, 2.1), (470.0, 392.0, 10.0, 1.8), (494.0, 370.0, 12.0, 2.3), (550.0, 384.0, 10.0, 1.7)];
    for (var i = 0; i < glints.length; i++) {
      final (x, y, w, d) = glints[i];
      final a = 0.5 + 0.5 * math.sin((t / d + i * 0.3) * 2 * math.pi);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + w, y),
        Paint()
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = (dark ? const Color(0xFFFFF6C9) : Colors.white).withValues(alpha: a),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlintPainter old) => old.dark != dark || old.s != s;
}

class _FirefliesPainter extends CustomPainter {
  _FirefliesPainter({required this.time, required this.s}) : super(repaint: time);

  final ValueNotifier<double> time;
  final double s;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    canvas.save();
    canvas.scale(s);
    const flies = [(392.0, 336.0, 7.0, 0.0), (496.0, 324.0, 9.0, 3.0), (560.0, 340.0, 8.0, 5.0)];
    for (final (x, y, period, ph) in flies) {
      final k = (t + ph) * 2 * math.pi / period;
      final o = Offset(x + 28 * math.sin(k) - 12 * math.sin(2 * k), y - 24 * (1 - math.cos(k)) / 2);
      final g = 0.2 + 0.8 * (0.5 + 0.5 * math.sin(t * 2.6 + ph));
      canvas.drawCircle(o, 10, Paint()..color = const Color(0xFFBEF264).withValues(alpha: 0.3 * g));
      canvas.drawCircle(o, 4, Paint()..color = const Color(0xFFE3FF9E).withValues(alpha: g));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FirefliesPainter old) => old.s != s;
}

class _Tumbleweed extends StatelessWidget {
  const _Tumbleweed({required this.time, required this.s, required this.svg, required this.shadow});

  final ValueNotifier<double> time;
  final double s;
  final String svg;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    final px = s * 2; // 1 piksel desain = 2 satuan
    final picture = SvgPicture.string(svg, width: 26 * px, height: 26 * px);
    return Positioned.fill(
      child: ValueListenableBuilder<double>(
        valueListenable: time,
        builder: (context, t, _) {
          final x = (-40 + 460 * ((t / 11) % 1)) * px;
          final b = math.sin(((t / 0.9) % 1) * math.pi); // 0..1..0
          return Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: x,
              top: 210 * px,
              child: Transform.scale(
                scale: 1 - 0.3 * b,
                child: Container(
                  width: 26 * px,
                  height: 6 * px,
                  decoration: BoxDecoration(color: shadow, borderRadius: BorderRadius.circular(99)),
                ),
              ),
            ),
            Positioned(
              left: x,
              top: (188 - 9 * b) * px,
              child: Transform.rotate(angle: t / 1.3 * 2 * math.pi, child: picture),
            ),
          ]);
        },
      ),
    );
  }
}

class _Lizard extends StatelessWidget {
  const _Lizard({required this.anim, required this.s, required this.svg});

  final Animation<double> anim;
  final double s;
  final String svg;

  @override
  Widget build(BuildContext context) {
    final px = s * 2;
    final picture = SvgPicture.string(svg, width: 40 * px, height: 14 * px);
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) {
          final v = anim.value;
          double dx, dy;
          if (v < 0.35) {
            dx = -90 + 60 * (v / 0.35);
            dy = 20;
          } else if (v < 0.5) {
            final k = (v - 0.35) / 0.15;
            dx = -30 + 30 * k;
            dy = 20 - 20 * k;
          } else {
            dx = 0;
            dy = v < 0.88 ? -3 * math.sin(((v - 0.5) / 0.12) * math.pi).abs() : 0;
          }
          return Stack(clipBehavior: Clip.none, children: [
            Positioned(left: (37 + dx) * px, top: (186 + dy) * px, child: picture),
          ]);
        },
      ),
    );
  }
}
