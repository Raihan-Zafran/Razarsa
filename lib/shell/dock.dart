import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/store.dart';

class DockItem {
  const DockItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Pusat menu ke-[i] dari [n] pada bar selebar [w] (jarak sama, 54 px dari tepi).
double dockCenterOf(int i, int n, double w) => 54 + (w - 108) / (n - 1) * i;

/// Jalur bar dock selebar [size] dengan lekukan melingkar di titik [cx]. Lingkaran lekukan
/// sepusat dengan bola aktif (jari-jari 26, pusat 6 px di bawah tepi atas), jadi bola
/// duduk pas di dalamnya. Sudut bar membulat 20 px.
Path dockPath(Size size, double cx) {
  final w = size.width, h = size.height;
  const r = 26.0, c = 6.0;
  final xe = math.sqrt(r * r - c * c);
  final a0 = math.atan2(-c, -xe) + 2 * math.pi;
  const da = 0.42;
  Offset pt(double a) => Offset(cx + r * math.cos(a), c + r * math.sin(a));
  final l1 = pt(a0 - da);
  final r1 = Offset(2 * cx - l1.dx, l1.dy);
  return Path()
    ..moveTo(20, 0)
    ..lineTo(cx - xe - 9, 0)
    ..quadraticBezierTo(cx - xe, 0, l1.dx, l1.dy)
    ..arcToPoint(r1, radius: const Radius.circular(r), clockwise: false)
    ..quadraticBezierTo(cx + xe, 0, cx + xe + 9, 0)
    ..lineTo(w - 20, 0)
    ..arcToPoint(Offset(w, 20), radius: const Radius.circular(20))
    ..lineTo(w, h - 20)
    ..arcToPoint(Offset(w - 20, h), radius: const Radius.circular(20))
    ..lineTo(20, h)
    ..arcToPoint(Offset(0, h - 20), radius: const Radius.circular(20))
    ..lineTo(0, 20)
    ..arcToPoint(const Offset(20, 0), radius: const Radius.circular(20))
    ..close();
}

/// Menu bawah: bar kaca tipis dengan lekukan melingkar; bola aktif melompat ke menu yang dipilih.
class ZDock extends StatefulWidget {
  const ZDock({super.key, required this.items, required this.index, required this.onTap});

  final List<DockItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  State<ZDock> createState() => _ZDockState();
}

class _ZDockState extends State<ZDock> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520), value: 1);
  late int _from = widget.index;

  @override
  void didUpdateWidget(covariant ZDock old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _from = old.index;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const double barH = 52;
  static const double ball = 40;
  static const double top = 26; // ruang di atas bar untuk bola yang melompat

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final n = widget.items.length;
    final lite = context.dependOnInheritedWidgetOfExactType<StoreScope>()?.notifier?.lite ?? false;
    return SizedBox(
      height: barH + top,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final step = (w - 108) / (n - 1);
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(_c.value);
            final fromX = dockCenterOf(_from, n, w);
            final toX = dockCenterOf(widget.index, n, w);
            final cx = fromX + (toX - fromX) * t;
            final hop = (widget.index == _from) ? 0.0 : math.sin(math.pi * _c.value) * 14;
            final path = dockPath(Size(w, barH), cx);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: barH,
                  child: Stack(fit: StackFit.expand, children: [
                    CustomPaint(painter: _DockShadow(path, z['dockShadow'])),
                    ClipPath(
                      clipper: _PathClipper(path),
                      child: lite
                          ? ColoredBox(color: z.card)
                          : BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                              child: ColoredBox(color: z.card.withValues(alpha: 0.62)),
                            ),
                    ),
                    CustomPaint(painter: _DockStroke(path, z.border)),
                  ]),
                ),
                // Bola aktif: pusatnya sama dengan pusat lekukan (6 px di bawah tepi atas bar).
                Positioned(
                  left: cx - ball / 2,
                  bottom: barH - 26 + hop,
                  child: Container(
                    width: ball,
                    height: ball,
                    decoration: BoxDecoration(
                      color: z['ball'],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: z['ball'].withValues(alpha: 0.28), spreadRadius: 3),
                        BoxShadow(color: z['ballGlow'], blurRadius: 12, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Icon(widget.items[widget.index].icon, color: z['ballFg'], size: 20),
                  ),
                ),
                // Ikon-ikon (yang aktif disembunyikan karena sudah ada di dalam bola)
                for (var i = 0; i < n; i++)
                  Positioned(
                    left: dockCenterOf(i, n, w) - step / 2,
                    width: step,
                    bottom: 0,
                    height: barH,
                    child: Semantics(
                      button: true,
                      selected: i == widget.index,
                      label: widget.items[i].label,
                      child: InkResponse(
                        onTap: () => widget.onTap(i),
                        radius: 28,
                        child: SizedBox.expand(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: i == widget.index ? 0 : 1,
                            child: Icon(widget.items[i].icon, color: z.muted2, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      }),
    );
  }
}

class _PathClipper extends CustomClipper<Path> {
  _PathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(covariant _PathClipper old) => old.path != path;
}

class _DockShadow extends CustomPainter {
  _DockShadow(this.path, this.color);

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(path.shift(const Offset(0, 6)), Paint()..color = color.withValues(alpha: color.a * 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
  }

  @override
  bool shouldRepaint(covariant _DockShadow old) => old.path != path || old.color != color;
}

class _DockStroke extends CustomPainter {
  _DockStroke(this.path, this.color);

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = color);
  }

  @override
  bool shouldRepaint(covariant _DockStroke old) => old.path != path || old.color != color;
}
