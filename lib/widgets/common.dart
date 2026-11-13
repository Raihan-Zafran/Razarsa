import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../core/i18n.dart';

class Assets {
  static const mascotCelebrate = 'assets/images/mascot_celebrate.webp';
  static const mascotThinking = 'assets/images/mascot_thinking.webp';
  static const mascotWorried = 'assets/images/mascot_worried.webp';
  static const mascotWallet = 'assets/images/mascot_wallet.webp';
  static const sceneDay = 'assets/images/scene_day.webp';
  static const sceneNight = 'assets/images/scene_night.webp';
  static const dragonHappy = 'assets/images/dragon_happy.webp';
  static const dragonWin = 'assets/images/dragon_win.webp';
  static const dragonCurious = 'assets/images/dragon_curious.webp';
  static const logo = 'assets/images/logo.png';
}

/// Tingkat efek kaca dari pengaturan (0 mati, 1 halus, 2 kuat). Tanpa store (misalnya di tes) dianggap mati.
int glassLevelOf(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<StoreScope>()?.notifier?.glassLevel ?? 0;

/// Permukaan kartu: warna biasa, atau kaca (tembus pandang + buram) kalau efek kaca menyala,
/// supaya latar bergerak di belakangnya tetap terlihat.
///
/// [hero] dipakai untuk kartu hijau tua (lebih pekat agar teks putih tetap terbaca).
class GlassPane extends StatelessWidget {
  const GlassPane({
    super.key,
    required this.color,
    required this.child,
    this.radius = 12,
    this.border,
    this.padding,
    this.hero = false,
    this.circle = false,
    this.color2,
  });

  final Color color;

  /// Warna kedua: kalau diisi, permukaan berupa gradasi diagonal dari [color] ke [color2].
  final Color? color2;
  final Widget child;
  final double radius;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;
  final bool hero;
  final bool circle;

  Gradient? _gradient(double alpha) => color2 == null
      ? null
      : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: color.a * alpha), color2!.withValues(alpha: color2!.a * alpha)],
        );

  @override
  Widget build(BuildContext context) {
    final level = glassLevelOf(context);
    final shape = circle ? BoxShape.circle : BoxShape.rectangle;
    final br = circle ? null : BorderRadius.circular(radius);
    if (level == 0) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(color: color2 == null ? color : null, gradient: _gradient(1), shape: shape, borderRadius: br, border: border),
        child: child,
      );
    }
    final alpha = hero ? (level == 1 ? 0.82 : 0.58) : (level == 1 ? 0.80 : 0.52);
    final sigma = level == 1 ? 5.0 : 10.0;
    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color2 == null ? color.withValues(alpha: color.a * alpha) : null,
        gradient: _gradient(alpha),
        shape: shape,
        borderRadius: br,
        border: border,
      ),
      child: child,
    );
    final blur = BackdropFilter(filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: inner);
    return circle ? ClipOval(child: blur) : ClipRRect(borderRadius: br!, child: blur);
  }
}

/// Kartu dasar: putih di mode terang, hijau gelap bergaris di mode gelap.
class ZCard extends StatelessWidget {
  const ZCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 12});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return GlassPane(
      color: z.card,
      radius: radius,
      border: Border.all(color: z.cardBorder),
      padding: padding,
      child: child,
    );
  }
}

/// Kotak ikon berwarna untuk kategori.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.tone, this.size = 42, this.radius = 9});

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
      IconTile(icon: category.icon, tone: category.tone, size: size, radius: size * 0.21);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
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
                tooltip: tr('Kembali'),
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
      child: GlassPane(
        color: filled ? z.track : z.card,
        circle: true,
        border: Border.all(color: filled ? Colors.transparent : z.border),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 21, color: filled ? z.muted : z.text)),
          ),
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
    return GlassPane(
      color: z.track,
      radius: 9,
      padding: const EdgeInsets.all(4),
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
                    borderRadius: BorderRadius.circular(7),
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
      child: selected
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: z.primary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: z.primary),
              ),
              child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: z.onPrimary)),
            )
          : GlassPane(
              color: z.card,
              radius: 999,
              border: Border.all(color: z.chipBorder),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: z.text2)),
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
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: z.muted2)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(amountText,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isIncome ? z.accentText : z.text)),
          ],
        ),
      ),
    );
  }
}

/// Logo Razarsa (huruf R hijau).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/images/logo.png', width: size, height: size, filterQuality: FilterQuality.medium);
}

/// Bintang logo Razarsa.
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
/// Tinggi dasar [base] yang ikut membesar mengikuti ukuran font sistem (maksimal 1,8x),
/// untuk wadah berukuran tetap yang berisi teks supaya tidak terpotong di font besar.
double scaledHeight(BuildContext context, double base) =>
    MediaQuery.textScalerOf(context).scale(base).clamp(base, base * 1.8).toDouble();

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
    duration: const Duration(seconds: 2),
    // Flutter 3.29+ membuat SnackBar yang punya tombol aksi menetap selamanya (persist = action != null).
    // Pop up kita harus hilang sendiri, termasuk yang punya tombol "Batalkan".
    persist: false,
    action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
  ));
}

/// Dialog konfirmasi hapus yang seragam di seluruh aplikasi (judul, tombol, dan urutannya sama).
/// [title] dan [message] boleh diganti; bawaannya "Hapus?" dan "\"{nama}\" akan dihapus.".
Future<bool> confirmDelete(BuildContext context, String name, VoidCallback onDelete, {String? title, String? message}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title ?? tr('Hapus?')),
      content: Text(message ?? trf('"{0}" akan dihapus.', [name])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Batal'))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Hapus'))),
      ],
    ),
  );
  if (ok == true) onDelete();
  return ok == true;
}
