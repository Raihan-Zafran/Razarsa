import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/store.dart';

/// Tombol terang/gelap: satu tombol bulat berisi matahari (terang) atau bulan (gelap).
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      toggled: dark,
      label: dark ? tr('Ganti ke mode terang') : tr('Ganti ke mode gelap'),
      child: Material(
        color: z.card,
        shape: CircleBorder(side: BorderSide(color: z.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => store.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
          child: SizedBox(
            width: 44,
            height: 44,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween(begin: 0.75, end: 1.0).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                key: ValueKey(dark),
                size: 24,
                color: dark ? const Color(0xFFA5B4FC) : const Color(0xFFD97706),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Informasi satu mode Razarsa.
class AppMode {
  const AppMode(this.id, this.name, this.desc, this.icon, this.tone, {this.ready = true});

  final String id;
  final String name;
  final String desc;
  final IconData icon;
  final String tone;
  final bool ready;
}

List<AppMode> get kModes => [
      AppMode('finance', tr('Keuangan'), tr('Catat uang, laporan, target tabungan'), Icons.account_balance_wallet_outlined, 'green'),
      AppMode('productive', tr('Produktif'), tr('Tugas, kalender, pengingat, catatan'), Icons.task_alt_rounded, 'blue'),
    ];

/// Titik asal animasi ganti mode: tengah tombol mode yang terakhir diketuk.
class ModeReveal {
  static Offset? origin;
}

/// Tombol mode di kiri atas: dua ikon (dompet = Keuangan, centang = Produktif) dalam satu pil.
/// Satu ketukan langsung ganti mode, tanpa lembar pilihan dan tanpa teks.
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    return Semantics(
      container: true,
      label: tr('Mode aplikasi'),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: z.card,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: z.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _ModeSegment(id: 'finance', wallet: true, label: tr('Mode Keuangan'), tip: tr('Keuangan'), active: store.mode == 'finance'),
          const SizedBox(width: 4),
          _ModeSegment(id: 'productive', wallet: false, label: tr('Mode Produktif'), tip: tr('Produktif'), active: store.mode == 'productive'),
        ]),
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({required this.id, required this.wallet, required this.label, required this.tip, required this.active});

  final String id;
  final bool wallet;
  final String label;
  final String tip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final fg = active ? z.onPrimary : z.muted;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: tip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (active) return;
            final box = context.findRenderObject();
            if (box is RenderBox && box.hasSize) ModeReveal.origin = box.localToGlobal(box.size.center(Offset.zero));
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            StoreScope.read(context).setMode(id);
          },
          // Area ketuk 52x44 (minimal 44 px), tampilannya 52x36.
          child: SizedBox(
            width: 52,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 52,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: active ? z.primary : Colors.transparent, borderRadius: BorderRadius.circular(99)),
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: fg),
                  duration: const Duration(milliseconds: 200),
                  builder: (_, c, _) => CustomPaint(
                    size: const Size.square(24),
                    painter: ModeIconPainter(wallet: wallet, color: c ?? fg, dot: z.card),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ikon mode: dompet (Keuangan) dan centang dalam lingkaran (Produktif), keduanya dengan percikan.
/// Digambar dari bentuk yang sama dengan desain (kotak 48 x 48, garis 4,5, ujung bulat).
class ModeIconPainter extends CustomPainter {
  ModeIconPainter({required this.wallet, required this.color, required this.dot});

  final bool wallet;
  final Color color;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48;
    canvas.save();
    canvas.scale(s);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    final spark = Path();
    if (wallet) {
      canvas.drawLine(const Offset(10, 14.5), const Offset(26, 8.5), line);
      canvas.drawRRect(RRect.fromLTRBR(4, 14, 40, 39, const Radius.circular(7)), line);
      canvas.drawRRect(RRect.fromLTRBR(26, 22.5, 40.5, 32, const Radius.circular(4.75)), fill);
      canvas.drawCircle(const Offset(31.5, 27.25), 1.9, Paint()..color = dot);
      spark
        ..moveTo(40, 2.5)
        ..quadraticBezierTo(40.7, 6.8, 44.5, 8)
        ..quadraticBezierTo(40.7, 9.2, 40, 13.5)
        ..quadraticBezierTo(39.3, 9.2, 35.5, 8)
        ..quadraticBezierTo(39.3, 6.8, 40, 2.5)
        ..close();
    } else {
      final ring = Path()
        ..moveTo(37.5, 21.9)
        ..arcToPoint(const Offset(26.1, 10.5), radius: const Radius.circular(16), largeArc: true, clockwise: true);
      canvas.drawPath(ring, line);
      final tick = Path()
        ..moveTo(15, 26)
        ..lineTo(20.5, 31.5)
        ..lineTo(30, 20.5);
      canvas.drawPath(tick, line);
      spark
        ..moveTo(38, 3.5)
        ..quadraticBezierTo(38.8, 8.6, 43.5, 10)
        ..quadraticBezierTo(38.8, 11.4, 38, 16.5)
        ..quadraticBezierTo(37.2, 11.4, 32.5, 10)
        ..quadraticBezierTo(37.2, 8.6, 38, 3.5)
        ..close();
    }
    canvas.drawPath(spark, fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ModeIconPainter old) => old.wallet != wallet || old.color != color || old.dot != dot;
}
