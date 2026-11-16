import 'package:flutter/material.dart';

/// Angka yang menghitung naik dari 0 saat pertama tampil, dan bergeser dari nilai lama
/// ke nilai baru saat berubah. Mati (langsung nilai akhir) kalau animasi dimatikan.
/// Pembaca layar langsung mendengar nilai akhirnya, bukan angka yang sedang berjalan.
///
/// Ukuran diambil dari teks nilai akhir; angka yang berjalan hanya DIGAMBAR (tanpa menata ulang
/// halaman tiap bingkai), jadi ringan walau berada di dalam baris kartu yang tingginya disamakan.
class CountUp extends StatefulWidget {
  /// Prototipe flowCount: mulai 140 ms sesudah halaman tampil, lalu naik selama 1 s (ease-out kubik).
  const CountUp({super.key, required this.value, required this.format, this.style, this.duration = const Duration(milliseconds: 1140)});

  final num value;
  final String Function(num) format;
  final TextStyle? style;
  final Duration duration;

  @override
  State<CountUp> createState() => CountUpState();
}

class CountUpState extends State<CountUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: const Interval(0.12, 1, curve: Curves.easeOutCubic));
  double _from = 0;
  bool _started = false;

  /// Teks yang sedang tampil (untuk tes).
  @visibleForTesting
  String get shown => widget.format((_from + (widget.value - _from) * _a.value).round());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void didUpdateWidget(CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      // Mulai dari angka yang sedang tampil, bukan dari 0.
      _from = _from + (oldWidget.value - _from) * _a.value;
      if (MediaQuery.disableAnimationsOf(context)) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finalText = widget.format(widget.value);
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return Semantics(
      label: finalText,
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: _CountPainter(
          animation: _a,
          text: () => shown,
          style: style,
          scaler: MediaQuery.textScalerOf(context),
          direction: Directionality.of(context),
        ),
        // Nilai akhir menentukan ukuran tetapi tidak digambar.
        child: Opacity(opacity: 0, child: Text(finalText, maxLines: 1, softWrap: false, style: widget.style)),
      ),
    );
  }
}

class _CountPainter extends CustomPainter {
  _CountPainter({required this.animation, required this.text, required this.style, required this.scaler, required this.direction}) : super(repaint: animation);

  final Animation<double> animation;
  final String Function() text;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(text: TextSpan(text: text(), style: style), textDirection: direction, textScaler: scaler, maxLines: 1)..layout();
    tp.paint(canvas, Offset(direction == TextDirection.rtl ? size.width - tp.width : 0, 0));
    tp.dispose();
  }

  @override
  bool shouldRepaint(_CountPainter old) => old.style != style || old.scaler != scaler || old.text() != text();
}

/// Isi yang tumbuh dari kosong ke [value] (0..1) saat pertama tampil: bar progres, cincin.
class FillIn extends StatelessWidget {
  /// Bawaan = garis progres prototipe (`fillW` 1,1 s, tertunda 0,3 s). Cincin: [FillIn.ring].
  const FillIn({super.key, required this.value, required this.builder, this.duration = const Duration(milliseconds: 1100), this.delay = const Duration(milliseconds: 300), this.curve = const Cubic(0.22, 0.8, 0.3, 1)});

  /// Cincin prototipe (`ringIn` 1,3 s, tertunda 0,25 s).
  const FillIn.ring({super.key, required this.value, required this.builder})
      : duration = const Duration(milliseconds: 1300),
        delay = const Duration(milliseconds: 250),
        curve = const Cubic(0.22, 0.8, 0.3, 1);

  final double value;
  final Widget Function(BuildContext context, double v) builder;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final total = delay + duration;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? value : 0, end: value),
      duration: still ? Duration.zero : total,
      curve: delay == Duration.zero ? curve : Interval(delay.inMicroseconds / total.inMicroseconds, 1, curve: curve),
      builder: (context, v, _) => builder(context, v),
    );
  }
}
