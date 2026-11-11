import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

class DockItem {
  const DockItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Menu bawah: bar gelap dengan lekukan; bola hijau melompat ke menu yang dipilih.
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

  static const double barH = 66;
  static const double ball = 58;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final n = widget.items.length;
    return SizedBox(
      height: barH + 26,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        // Ujung kiri/kanan diberi jarak supaya lekukan tidak memotong sudut bar.
        const pad = 32.0;
        final slot = (w - pad * 2) / n;
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(_c.value);
            final fromX = pad + slot * (_from + 0.5);
            final toX = pad + slot * (widget.index + 0.5);
            final cx = fromX + (toX - fromX) * t;
            final hop = (widget.index == _from) ? 0.0 : math.sin(math.pi * _c.value) * 16;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: barH,
                  child: CustomPaint(painter: _DockPainter(cx: cx, color: z['dock'], shadow: z['dockShadow'])),
                ),
                // Bola aktif
                Positioned(
                  left: cx - ball / 2,
                  bottom: barH - 34 + hop,
                  child: Container(
                    width: ball,
                    height: ball,
                    decoration: BoxDecoration(
                      color: z['ball'],
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: z['ball'].withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    child: Icon(widget.items[widget.index].icon, color: z['ballFg'], size: 24),
                  ),
                ),
                // Ikon-ikon
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: barH,
                  child: Row(
                    children: [
                      const SizedBox(width: pad),
                      for (var i = 0; i < n; i++)
                        Expanded(
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
                                  child: Icon(widget.items[i].icon, color: z['dockMuted'], size: 23),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: pad),
                    ],
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

class _DockPainter extends CustomPainter {
  _DockPainter({required this.cx, required this.color, required this.shadow});

  final double cx;
  final Color color;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)));
    // Lekukan halus (bentuk sama dengan desain).
    final notch = Path()
      ..moveTo(cx - 56, -1)
      ..lineTo(cx - 56, 0)
      ..cubicTo(cx - 43, 0, cx - 39, 5, cx - 35.5, 13)
      ..cubicTo(cx - 27, 32, cx - 17, 44, cx, 44)
      ..cubicTo(cx + 17, 44, cx + 27, 32, cx + 35.5, 13)
      ..cubicTo(cx + 39, 5, cx + 43, 0, cx + 56, 0)
      ..lineTo(cx + 56, -1)
      ..close();
    final shape = Path.combine(PathOperation.difference, bar, notch);
    canvas.drawShadow(shape, shadow, 10, false);
    canvas.drawPath(shape, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DockPainter old) => old.cx != cx || old.color != color;
}
