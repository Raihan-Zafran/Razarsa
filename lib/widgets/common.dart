import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';

class Assets {
  static const mascotCelebrate = 'assets/images/mascot_celebrate.webp';
  static const mascotThinking = 'assets/images/mascot_thinking.webp';
  static const mascotWorried = 'assets/images/mascot_worried.webp';
  static const mascotWallet = 'assets/images/mascot_wallet.webp';
  static const mountainDay = 'assets/images/mountain_day.webp';
  static const mountainNight = 'assets/images/mountain_night.webp';
}

/// Kartu dasar: putih di mode terang, hijau gelap bergaris di mode gelap.
class ZCard extends StatelessWidget {
  const ZCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 20});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: z.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: z.cardBorder),
      ),
      child: child,
    );
  }
}

/// Kotak ikon berwarna untuk kategori.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.tone, this.size = 42, this.radius = 14});

  final IconData icon;
  final String tone;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: z.toneBg(tone), borderRadius: BorderRadius.circular(radius)),
      child: Icon(icon, size: size * 0.48, color: z.toneFg(tone)),
    );
  }
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, this.size = 42});

  final Category category;
  final double size;

  @override
  Widget build(BuildContext context) =>
      IconTile(icon: category.icon, tone: category.tone, size: size, radius: size / 3);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        ?trailing,
      ],
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key, this.actions = const [], this.onBack, this.backIcon = Icons.arrow_back_rounded});

  final String text;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final IconData backIcon;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (onBack != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                onPressed: onBack,
                icon: Icon(backIcon, color: z.text),
                tooltip: 'Kembali',
                style: IconButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: onBack != null ? 18 : 22, fontWeight: FontWeight.w800)),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Tombol bulat 44px bergaris (untuk aksi di header).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onTap, required this.tooltip, this.filled = false});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? z.track : z.card,
        shape: CircleBorder(side: BorderSide(color: filled ? Colors.transparent : z.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 21, color: filled ? z.muted : z.text)),
        ),
      ),
    );
  }
}

/// Pilihan tersegmentasi (contoh: Pengeluaran | Pemasukan).
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.items, required this.value, required this.onChanged, this.height = 40});

  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: z.track, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final (v, label) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? z.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: v == value ? z.onPrimary : z.text2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ZChip extends StatelessWidget {
  const ZChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? z.primary : z.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? z.primary : z.chipBorder),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? z.onPrimary : z.text2),
        ),
      ),
    );
  }
}

/// Tampilan kosong dengan maskot.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message, this.image = Assets.mascotThinking, this.action});

  final String title;
  final String message;
  final String image;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        children: [
          Image.asset(image, width: 130),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: z.muted, height: 1.45)),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

/// Satu baris transaksi.
class TxnRow extends StatelessWidget {
  const TxnRow({
    super.key,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.amountText,
    required this.isIncome,
    this.showDivider = true,
    this.onLongPress,
  });

  final Category category;
  final String title;
  final String subtitle;
  final String amountText;
  final bool isIncome;
  final bool showDivider;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return InkWell(
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: showDivider ? z.divider : Colors.transparent)),
        ),
        child: Row(
          children: [
            CategoryTile(category: category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: z.muted2)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(amountText,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isIncome ? z.accentText : z.text)),
          ],
        ),
      ),
    );
  }
}

/// Bintang logo Zevra.
class StarLogo extends StatelessWidget {
  const StarLogo({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _StarPainter());
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final p = Path()
      ..moveTo(12 * s, 1 * s)
      ..cubicTo(13 * s, 8 * s, 16 * s, 11 * s, 23 * s, 12 * s)
      ..cubicTo(16 * s, 13 * s, 13 * s, 16 * s, 12 * s, 23 * s)
      ..cubicTo(11 * s, 16 * s, 8 * s, 13 * s, 1 * s, 12 * s)
      ..cubicTo(8 * s, 11 * s, 11 * s, 8 * s, 12 * s, 1 * s)
      ..close();
    canvas.drawPath(p, Paint()..color = const Color(0xFF4ADE80));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Snackbar yang muncul di atas dock.
void showZToast(BuildContext context, String text, {String? actionLabel, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Row(children: [
      Icon(Icons.check_rounded, color: ZColors.of(context)['toastAccent'], size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ]),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
    duration: const Duration(seconds: 4),
    action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
  ));
}
