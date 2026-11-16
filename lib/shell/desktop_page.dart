import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/count_up.dart';
import 'app_shell.dart';
import 'layout.dart';

/// Lebar isi paling besar di desktop; jendela yang lebih lebar menyisakan ruang di kiri-kanan.
const kDesktopMaxContent = 1320.0;

/// Kerangka halaman desktop: judul + keterangan di kiri, tombol aksi di kanan, lalu isi yang bisa digulir.
/// Lebar isi menyesuaikan jendela (28 px di tepi, maksimal [kDesktopMaxContent]).
class DesktopPage extends StatelessWidget {
  const DesktopPage({super.key, required this.title, this.subtitle, this.action, required this.children, this.maxWidth = kDesktopMaxContent});

  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return LayoutBuilder(builder: (context, box) {
      final gutter = sideGutter(box.maxWidth, maxWidth + 56, min: 28);
      final head = Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.15)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: TextStyle(fontSize: 13.5, color: z.muted)),
            ],
          ]),
        ),
        if (action != null) const SizedBox(width: 16),
        ?action,
      ]);
      return ListView(
        padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 40),
        children: staggered(context, [
          head,
          const SizedBox(height: 18),
          ...children,
        ]),
      );
    });
  }
}

/// Kartu desktop: judul di kiri, tautan kecil di kanan, lalu isi.
class DCard extends StatelessWidget {
  const DCard({super.key, this.title, this.link, this.onLink, this.leading, this.trailing, required this.child, this.padding = const EdgeInsets.fromLTRB(22, 20, 22, 20), this.color, this.border});

  final String? title;
  final String? link;
  final VoidCallback? onLink;
  final IconData? leading;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final Widget? head = title == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              if (leading != null) ...[Icon(leading, size: 20, color: z.text2), const SizedBox(width: 8)],
              Expanded(child: Text(title!, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: -0.1))),
              ?trailing,
              if (link != null)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onLink,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(link!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: z.accentText)),
                  ),
                ),
            ]),
          );
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [?head, child]);
    if (color != null) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), border: Border.all(color: border ?? z.cardBorder)),
        child: body,
      );
    }
    return ZCard(padding: padding, child: body);
  }
}

/// Susun kartu berdampingan selagi lebar cukup; kalau sempit, turun ke bawah (jumlah kolom menyesuaikan lebar).
/// [flex] menentukan lebar relatif tiap kartu saat semuanya muat dalam satu baris.
class DCols extends StatelessWidget {
  const DCols({super.key, required this.children, this.flex, this.minChild = 320, this.gap = 20});

  final List<Widget> children;
  final List<int>? flex;
  final double minChild;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final n = children.length;
      final fit = ((box.maxWidth + gap) / (minChild + gap)).floor().clamp(1, n);
      final rows = <List<int>>[];
      for (var i = 0; i < n; i += fit) {
        rows.add([for (var k = i; k < i + fit && k < n; k++) k]);
      }
      Widget row(List<int> idx) {
        if (idx.length == 1 && fit == 1) return children[idx.first];
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var j = 0; j < idx.length; j++) ...[
              if (j > 0) SizedBox(width: gap),
              Expanded(flex: fit == n && flex != null ? flex![idx[j]] : 1, child: children[idx[j]]),
            ],
          ]),
        );
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: gap),
          row(rows[r]),
        ],
      ]);
    });
  }
}

/// Cincin persentase kecil (anggaran, tugas) dengan teks di tengah.
class DRing extends StatelessWidget {
  const DRing({super.key, required this.value, required this.size, required this.center, this.stroke = 10, this.color, this.track});

  final double value;
  final double size;
  final Widget center;
  final double stroke;
  final Color? color;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: FillIn(
        value: value.clamp(0.0, 1.0),
        duration: const Duration(milliseconds: 1300),
        builder: (_, v) => CustomPaint(
          painter: _RingPainter(v, stroke, color ?? z.primary, track ?? z.track),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.color, this.track);

  final double v, stroke;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(r, 0, 6.2831853, false, p);
    if (v <= 0) return;
    canvas.drawArc(r, -1.5707963, 6.2831853 * v, false, p..color = color..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v || old.color != color || old.track != track;
}
