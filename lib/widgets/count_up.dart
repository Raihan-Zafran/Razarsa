import 'package:flutter/material.dart';

/// Angka yang menghitung naik dari 0 saat pertama tampil, dan bergeser dari nilai lama
/// ke nilai baru saat berubah. Mati (langsung nilai akhir) kalau animasi dimatikan.
/// Pembaca layar langsung mendengar nilai akhirnya, bukan angka yang sedang berjalan.
class CountUp extends StatelessWidget {
  /// Prototipe flowCount: mulai 140 ms sesudah halaman tampil, lalu naik selama 1 s (ease-out kubik).
  const CountUp({super.key, required this.value, required this.format, this.style, this.duration = const Duration(milliseconds: 1140)});

  final num value;
  final String Function(num) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return Text(format(value), style: style);
    return Semantics(
      label: format(value),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: duration,
        curve: const Interval(0.12, 1, curve: Curves.easeOutCubic),
        builder: (_, v, _) => Text(format(v.round()), style: style),
      ),
    );
  }
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
