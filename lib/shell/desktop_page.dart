import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/count_up.dart';
import 'app_shell.dart';

/// Kerangka halaman desktop (prototipe `.hdr` + `.scroll`): kepala tetap setinggi 84 px berisi judul + keterangan
/// di kiri dan tombol aksi di kanan, lalu isi yang bisa digulir. Isi memenuhi lebar jendela (36 px di tepi),
/// tanpa batas lebar, jadi layar 1920 x 1080 terpakai penuh.
class DesktopPage extends StatelessWidget {
  const DesktopPage({super.key, required this.title, this.subtitle, this.action, required this.children});

  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;

  static const gutter = 36.0;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final page = PageStagger.of(context);
    final head = SizedBox(
      height: 84,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: gutter),
        child: Row(children: [
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TypingTitle(title, animate: page?.typeTitle ?? false, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.56, height: 1.15)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                _SubIn(
                  animate: page?.typeTitle ?? false,
                  child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: z.muted2)),
                ),
              ],
            ]),
          ),
          if (action != null) const SizedBox(width: 12),
          ?action,
        ]),
      ),
    );
    Widget body = ListView(
      padding: const EdgeInsets.fromLTRB(gutter, 2, gutter, gutter),
      children: staggered(context, children),
    );
    final leave = page?.leave;
    if (leave != null) body = _Leave(animation: leave, child: body);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, Expanded(child: body)]);
  }
}

/// Isi halaman keluar sebelum pindah halaman (prototipe `.pgin.leave`): pudar, naik 10 px, mengecil 0,992 dalam 170 ms.
/// Blur 2,5 px di prototipe sengaja tidak dipakai: berat untuk GPU laptop dan membuat animasi patah.
class _Leave extends StatelessWidget {
  const _Leave({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final t = Curves.ease.transform(animation.value);
        final k = 1 - 0.008 * t;
        return IgnorePointer(
          ignoring: t > 0,
          child: Opacity(
            opacity: 1 - t,
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.translationValues(0, -10 * t, 0)..scaleByDouble(k, k, 1, 1),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Judul halaman yang diketik ulang huruf demi huruf (38 ms per huruf) dengan kursor berkedip,
/// seperti prototipe saat pindah halaman. Tanpa animasi kalau "Kurangi efek" aktif.
class TypingTitle extends StatefulWidget {
  const TypingTitle(this.text, {super.key, required this.style, this.animate = true});

  final String text;
  final TextStyle style;
  final bool animate;

  @override
  State<TypingTitle> createState() => _TypingTitleState();
}

class _TypingTitleState extends State<TypingTitle> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  int _shown = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null || _shown >= 0) return;
    final n = widget.text.length;
    if (!widget.animate || n < 2 || MediaQuery.disableAnimationsOf(context)) {
      _shown = n;
      return;
    }
    // Huruf pertama langsung, sisanya mulai 60 ms kemudian, lalu kursor bertahan 450 ms.
    final typing = 60 + 38 * (n - 1);
    final c = AnimationController(vsync: this, duration: Duration(milliseconds: typing + 450));
    c.addListener(() {
      final ms = c.value * (typing + 450);
      final i = ms < 60 ? 1 : (2 + ((ms - 60) / 38).floor()).clamp(1, n);
      if (i != _shown) setState(() => _shown = i);
    });
    c.addStatusListener((st) {
      if (st == AnimationStatus.completed && mounted) setState(() {});
    });
    _shown = 1;
    _c = c..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final text = widget.text;
    final c = _c;
    final typing = c != null && c.status != AnimationStatus.completed;
    final shown = _shown < 0 || _shown > text.length ? text.length : _shown;
    final size = widget.style.fontSize ?? 28;
    return Semantics(
      label: text,
      header: true,
      child: ExcludeSemantics(
        child: Stack(children: [
          // Teks penuh yang tak terlihat menjaga tinggi dan lebar, jadi tata letak tidak bergoyang saat mengetik.
          Opacity(opacity: 0, child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: widget.style)),
          Positioned.fill(
            child: Row(children: [
              Flexible(child: Text(text.substring(0, shown), maxLines: 1, overflow: TextOverflow.clip, softWrap: false, style: widget.style)),
              if (typing)
                AnimatedBuilder(
                  animation: c,
                  builder: (context, _) {
                    // Kursor berkedip tiap 0,3 s (prototipe: caret .6s steps(1)).
                    final ms = (c.value * c.duration!.inMilliseconds).round();
                    final on = (ms ~/ 300).isEven;
                    return Container(
                      width: 3,
                      height: size * 0.9,
                      margin: const EdgeInsets.only(left: 3),
                      decoration: BoxDecoration(color: on ? z.primary : Colors.transparent, borderRadius: BorderRadius.circular(2)),
                    );
                  },
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Keterangan halaman muncul naik 6 px (prototipe `subIn` 0,5 s, tertunda 0,1 s) saat pindah halaman.
class _SubIn extends StatefulWidget {
  const _SubIn({required this.child, required this.animate});

  final Widget child;
  final bool animate;

  @override
  State<_SubIn> createState() => _SubInState();
}

class _SubInState extends State<_SubIn> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  Animation<double>? _a;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) return;
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _a = CurvedAnimation(parent: c, curve: const Interval(0.1 / 0.6, 1, curve: Cubic(0.22, 0.8, 0.3, 1)));
    _c = c..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    if (a == null) return widget.child;
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        child: widget.child,
        builder: (context, child) => Transform.translate(offset: Offset(0, 6 * (1 - a.value)), child: child),
      ),
    );
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
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), border: Border.all(color: border ?? z.border)),
        child: body,
      );
    }
    return ZCard(padding: padding, child: body);
  }
}

/// Susun kartu berdampingan selagi lebar cukup; kalau sempit, turun ke bawah (jumlah kolom menyesuaikan lebar).
/// [flex] menentukan lebar relatif tiap kartu saat semuanya muat dalam satu baris.
class DCols extends StatelessWidget implements StaggerGroup {
  const DCols({super.key, required this.children, this.flex, this.minChild = 320, this.gap = 20});

  final List<Widget> children;
  final List<int>? flex;
  final double minChild;
  final double gap;

  @override
  Widget build(BuildContext context) {
    // Grid langsung di halaman Windows: tiap kartu muncul sendiri, 0,12 s + 70 ms per kartu (prototipe).
    final page = PageStagger.of(context);
    final List<Widget> children = page != null && page.desktop && !StaggerItem.inside(context)
        ? [for (var j = 0; j < this.children.length; j++) StaggerItem(index: 0, lead: Duration(milliseconds: 120 + 70 * j), child: this.children[j])]
        : this.children;
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
      child: FillIn.ring(
        value: value.clamp(0.0, 1.0),
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
