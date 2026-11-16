import 'package:flutter/material.dart';

/// Wadah air untuk target tabungan: air naik dari kosong sampai terisi, gelombang bergerak,
/// dan gelembung kecil naik. Bentuk dan gerakannya mengikuti prototipe.
class WaterJar extends StatefulWidget {
  const WaterJar({
    super.key,
    required this.progress,
    required this.width,
    required this.back,
    required this.water,
    required this.outline,
    this.label,
  });

  /// 0..1. Nilai terlalu kecil tetap menampakkan sedikit air.
  final double progress;
  final double width;
  final Color back, water, outline;

  /// Teks di tengah (misalnya persen), opsional.
  final String? label;

  @override
  State<WaterJar> createState() => _WaterJarState();
}

class _WaterJarState extends State<WaterJar> with TickerProviderStateMixin {
  late final AnimationController _level = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 54));
  late Animation<double> _curve = const AlwaysStoppedAnimation(0);
  double _from = 0, _to = 0;
  bool _init = false;

  static double _clamp(double p) => p.isNaN ? 0.02 : p.clamp(0.02, 1.0).toDouble();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!_init) {
      _init = true;
      _to = _clamp(widget.progress);
      _from = reduce ? _to : 0;
      _bind();
      reduce ? _level.value = 1 : _level.forward();
    }
    if (reduce) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  void _bind() {
    _curve = CurvedAnimation(parent: _level, curve: const Cubic(0.22, 0.8, 0.3, 1));
  }

  @override
  void didUpdateWidget(covariant WaterJar old) {
    super.didUpdateWidget(old);
    final next = _clamp(widget.progress);
    if (next != _to) {
      _from = _from + (_to - _from) * _curve.value;
      _to = next;
      _level
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _level.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width, h = w * 124 / 100;
    return Semantics(
      label: '${(widget.progress * 100).round()}%',
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(alignment: Alignment.center, children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_level, _loop]),
              builder: (_, _) => CustomPaint(
                size: Size(w, h),
                painter: _JarPainter(
                  level: _from + (_to - _from) * _curve.value,
                  t: _loop.value * 54,
                  back: widget.back,
                  water: widget.water,
                  outline: widget.outline,
                  animate: !MediaQuery.disableAnimationsOf(context),
                ),
              ),
            ),
          ),
          if (widget.label != null)
            Positioned(
              left: 0,
              right: 0,
              top: h * 0.46 - 8,
              child: Text(
                widget.label!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: [Shadow(color: Color(0x73000000), blurRadius: 3, offset: Offset(0, 1))],
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _JarPainter extends CustomPainter {
  _JarPainter({required this.level, required this.t, required this.back, required this.water, required this.outline, required this.animate});

  final double level, t;
  final Color back, water, outline;
  final bool animate;

  static Path _jar() => Path()
    ..moveTo(22, 8)
    ..lineTo(78, 8)
    ..lineTo(78, 18)
    ..quadraticBezierTo(78, 22, 82, 26)
    ..quadraticBezierTo(94, 34, 94, 52)
    ..lineTo(94, 106)
    ..quadraticBezierTo(94, 120, 80, 120)
    ..lineTo(20, 120)
    ..quadraticBezierTo(6, 120, 6, 106)
    ..lineTo(6, 52)
    ..quadraticBezierTo(6, 34, 18, 26)
    ..quadraticBezierTo(22, 22, 22, 18)
    ..close();

  /// Gelombang selebar 300 satuan, tepi atas bergelombang, bagian bawah rata sampai 160.
  static Path _wave() {
    final p = Path()..moveTo(0, 0);
    for (var i = 0; i < 12; i++) {
      p.quadraticBezierTo(i * 25 + 12.5, i.isOdd ? 5 : -5, i * 25 + 25, 0);
    }
    return p
      ..lineTo(300, 160)
      ..lineTo(0, 160)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 124);
    final jar = _jar();
    canvas.save();
    canvas.clipPath(jar);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 124), Paint()..color = back);
    final jy = 14 + 102 * (1 - level);
    canvas.save();
    canvas.translate(0, jy);
    final wave = _wave();
    // Gelombang belakang: lebih lambat, arah berlawanan, transparan.
    final dxB = animate ? ((t / 5.4) % 1) * 100 : 0.0;
    canvas.save();
    canvas.translate(-130 + dxB, 2);
    canvas.drawPath(wave, Paint()..color = water.withValues(alpha: 0.4));
    canvas.restore();
    final dxA = animate ? ((t / 3.6) % 1) * 100 : 0.0;
    canvas.save();
    canvas.translate(-dxA, 0);
    canvas.drawPath(wave, Paint()..color = water.withValues(alpha: 0.9));
    canvas.restore();
    // Gelembung naik pelan.
    if (animate && level > 0.12) {
      for (final (cx, cy, r, delay) in const [(32.0, 42.0, 2.4, 0.0), (62.0, 54.0, 1.9, 1.5)]) {
        final k = (((t - delay) / 4.2) % 1 + 1) % 1;
        final op = k < 0.15 ? k / 0.15 * 0.7 : 0.7 * (1 - (k - 0.15) / 0.85);
        canvas.drawCircle(Offset(cx, cy - 70 * k * k + 0), r, Paint()..color = Colors.white.withValues(alpha: op.clamp(0.0, 0.7)));
      }
    }
    canvas.restore();
    canvas.restore();
    canvas.drawPath(
      jar,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _JarPainter old) => old.level != level || old.t != t || old.back != back || old.water != water || old.outline != outline;
}
