import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/theme.dart';

// Warna titik "sumber" yang sama dengan graf Saldo dan wadah Target.
const _gold = Color(0xFFE8C86A);
const _cyan = Color(0xFF7FD6DE);
const _peach = Color(0xFFF4B79A);

/// Jam animasi untuk karya bentuk: detik berjalan selama widget hidup (maksimal 30 detik).
/// Kalau animasi dimatikan (kurangi efek / aksesibilitas) waktu dibekukan di keadaan akhir.
mixin _ArtClock<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  final time = ValueNotifier<double>(0);
  Ticker? _ticker;
  bool still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _ticker?.stop();
      time.value = 100; // keadaan akhir: wadah terisi, titik diam
    } else {
      _ticker ??= createTicker((e) {
        time.value = e.inMicroseconds / 1e6;
        // Gerak berhenti sendiri setelah 30 detik: hemat baterai, dan layar tidak "bergerak selamanya".
        if (time.value > 30) _ticker?.stop();
      });
      if (!_ticker!.isActive) _ticker!.start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    time.dispose();
    super.dispose();
  }
}

/// Ilustrasi sambutan dari bentuk saja: wadah air yang terisi dan bergelombang,
/// dikelilingi orbit titik-titik sumber yang berdenyut. Mengikuti warna tema.
class HeroArt extends StatefulWidget {
  const HeroArt({super.key, this.width = 360, this.color});

  final double width;

  /// Warna utama gambar; null = warna utama tema (di panel berlatar warna utama pakai warna teks di atasnya).
  final Color? color;

  @override
  State<HeroArt> createState() => _HeroArtState();
}

class _HeroArtState extends State<HeroArt> with SingleTickerProviderStateMixin, _ArtClock {
  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.width, widget.width * 320 / 360),
        painter: _HeroPainter(time, widget.color ?? z.primary),
      ),
    );
  }
}

Path _jarPath() => Path()
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

/// Satu lapis gelombang yang permukaannya di y = 0, lebar cukup untuk digeser 60 px tanpa celah.
Path _wavePath() {
  final p = Path()..moveTo(-60, 0);
  var up = true;
  for (var i = 0; i < 8; i++) {
    p.relativeQuadraticBezierTo(15, up ? -7 : 7, 30, 0);
    up = !up;
  }
  return p
    ..lineTo(180, 140)
    ..lineTo(-60, 140)
    ..close();
}

class _HeroPainter extends CustomPainter {
  _HeroPainter(this.time, this.primary) : super(repaint: time);

  final ValueNotifier<double> time;
  final Color primary;

  static final _jar = _jarPath();
  static final _wave = _wavePath();

  /// Posisi dan ukuran titik pada orbit (sudut dalam derajat, jari-jari titik, warna).
  static const _nodes = [
    (200.0, 14.0, _gold),
    (262.0, 9.0, _cyan),
    (330.0, 17.0, _peach),
    (30.0, 10.0, _gold),
    (95.0, 13.0, _cyan),
    (150.0, 8.0, _peach),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    canvas.save();
    canvas.scale(size.width / 360);
    const c = Offset(180, 160);

    canvas.drawCircle(c, 148, Paint()..color = primary.withValues(alpha: 0.07));

    // Cincin titik-titik berputar pelan ke arah sebaliknya.
    final dots = Paint()
      ..color = primary.withValues(alpha: 0.3)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final rot = -t * 2 * math.pi / 140;
    for (var k = 0; k < 75; k++) {
      final a = rot + k * 2 * math.pi / 75;
      canvas.drawPoints(PointMode.points, [c + Offset(math.cos(a), math.sin(a)) * 132], dots);
    }

    // Orbit: cincin, tautan ke pusat, dan titik-titik yang berdenyut.
    final spin = t * 2 * math.pi / 80;
    canvas.drawCircle(c, 112, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = primary.withValues(alpha: 0.16));
    final link = Paint()..strokeWidth = 1.4..color = primary.withValues(alpha: 0.18);
    for (var i = 0; i < _nodes.length; i++) {
      final (deg, r, color) = _nodes[i];
      final a = deg * math.pi / 180 + spin;
      final p = c + Offset(math.cos(a), math.sin(a)) * 112;
      canvas.drawLine(c, p, link);
      final pulse = 1 + 0.18 * (0.5 - 0.5 * math.cos((t - i * 0.7) * 2 * math.pi / 3.6));
      canvas.drawCircle(p, r * pulse, Paint()..color = color);
      canvas.drawCircle(p, r + 6, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = color.withValues(alpha: 0.35));
    }

    // Wadah air.
    canvas.save();
    canvas.translate(131, 100);
    canvas.scale(0.98);
    canvas.drawPath(_jar, Paint()..color = primary.withValues(alpha: 0.08));
    canvas.save();
    canvas.clipPath(_jar);
    final p = ((t - 0.3) / 2.8).clamp(0.0, 1.0);
    final eased = 1 - math.pow(1 - p, 3).toDouble();
    final waterY = 48 + 80 * (1 - eased);
    canvas.translate(0, waterY);
    canvas.save();
    canvas.translate(-60 + (t % 5.4) / 5.4 * 60, 3);
    canvas.drawPath(_wave, Paint()..color = _gold.withValues(alpha: 0.7));
    canvas.restore();
    canvas.save();
    canvas.translate(-(t % 3.4) / 3.4 * 60, 0);
    canvas.drawPath(_wave, Paint()..color = primary.withValues(alpha: 0.92));
    canvas.restore();
    for (final (bx, by, br, delay) in const [(34.0, 86.0, 3.0, 0.0), (62.0, 96.0, 2.2, 1.4), (50.0, 78.0, 2.6, 2.6)]) {
      final q = (((t - delay) % 4.2) + 4.2) % 4.2 / 4.2;
      final op = q < 0.15 ? q / 0.15 * 0.7 : 0.7 * (1 - (q - 0.15) / 0.85);
      canvas.drawCircle(Offset(bx, by - 52 * q), br, Paint()..color = Colors.white.withValues(alpha: op));
    }
    canvas.restore();
    canvas.drawPath(_jar, Paint()..style = PaintingStyle.stroke..strokeWidth = 3.2..strokeJoin = StrokeJoin.round..color = primary);
    canvas.drawPath(
      Path()
        ..moveTo(17, 56)
        ..quadraticBezierTo(15, 44, 23, 38),
      Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeroPainter old) => old.primary != primary;
}

/// Lambang bulat dari bentuk: lingkaran konsentris, cincin putus-putus yang berputar,
/// denyut, dan tiga titik mengorbit. [child] ditaruh di inti (ikon gembok atau huruf inisial).
class ShapeEmblem extends StatefulWidget {
  const ShapeEmblem({super.key, this.size = 120, required this.child});

  final double size;
  final Widget child;

  @override
  State<ShapeEmblem> createState() => _ShapeEmblemState();
}

class _ShapeEmblemState extends State<ShapeEmblem> with SingleTickerProviderStateMixin, _ArtClock {
  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(alignment: Alignment.center, children: [
        RepaintBoundary(child: CustomPaint(size: Size(s, s), painter: _EmblemPainter(time, z.primary))),
        Container(
          width: s * 0.46,
          height: s * 0.46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: z.primary,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: z.primary.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10), spreadRadius: -10)],
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: z.onPrimary, fontWeight: FontWeight.w800, fontSize: s * 0.2, letterSpacing: -0.4),
            child: IconTheme.merge(data: IconThemeData(color: z.onPrimary, size: s * 0.22), child: widget.child),
          ),
        ),
      ]),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter(this.time, this.primary) : super(repaint: time);

  final ValueNotifier<double> time;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value, s = size.width, c = Offset(s / 2, s / 2);
    canvas.drawCircle(c, s / 2, Paint()..color = primary.withValues(alpha: 0.08));
    // Denyut keluar.
    final q = (t % 3) / 3;
    canvas.drawCircle(c, s * 0.4 * (0.7 + 0.48 * q),
        Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = primary.withValues(alpha: 0.5 * (1 - q)));
    // Cincin putus-putus berputar.
    final rot = t * 2 * math.pi / 36;
    final dash = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round..color = primary.withValues(alpha: 0.38);
    const n = 30;
    for (var k = 0; k < n; k++) {
      final a0 = rot + k * 2 * math.pi / n;
      canvas.drawArc(Rect.fromCircle(center: c, radius: s * 0.37), a0, 2 * math.pi / n * 0.5, false, dash);
    }
    // Tiga titik mengorbit.
    final spin = t * 2 * math.pi / 22;
    for (final (deg, color) in const [(-90.0, _gold), (23.0, _cyan), (151.0, _peach)]) {
      final a = deg * math.pi / 180 + spin;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (s * 0.45), s * 0.055, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter old) => old.primary != primary;
}
