import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import 'saldo_page.dart' show walletIcon;

/// Warna garis menurut jenis sumber (bank biru, e-wallet ungu, tunai kuning).
Color flowColor(String type) => switch (type) {
      'ewallet' => const Color(0xFFA78BFA),
      'cash' => const Color(0xFFF0C95C),
      _ => const Color(0xFF6C9BEF),
    };

/// Diagram aliran: sumber saldo di kiri, kategori di kanan, garis melengkung selebar jumlahnya.
/// Pemasukan digambar putus-putus hijau. Arahkan kursor ke satu kotak untuk menyorot garisnya.
class SaldoFlow extends StatefulWidget {
  const SaldoFlow({super.key, required this.store, required this.from, required this.to});

  final AppStore store;
  final DateTime from;
  final DateTime to;

  @override
  State<SaldoFlow> createState() => _SaldoFlowState();
}

class _Link {
  _Link(this.wallet, this.cat, this.income);

  final String wallet, cat;
  final bool income;
  int amount = 0, count = 0;
}

class _SaldoFlowState extends State<SaldoFlow> with SingleTickerProviderStateMixin {
  String? _hover; // 'w:<id>' atau 'c:<id>'
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_in.isAnimating || _in.value > 0) return;
    MediaQuery.disableAnimationsOf(context) ? _in.value = 1 : _in.forward();
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final z = ZColors.of(context);
    final links = <String, _Link>{};
    final wCount = <String, int>{}, cCount = <String, int>{}, cTotal = <String, int>{};
    for (final t in store.txns) {
      final d = dayOnly(t.at);
      if (d.isBefore(dayOnly(widget.from)) || !d.isBefore(dayOnly(widget.to))) continue;
      final k = '${t.wallet}|${t.cat}|${t.isExpense}';
      final l = links.putIfAbsent(k, () => _Link(t.wallet, t.cat, !t.isExpense));
      l.amount += t.amount.abs();
      l.count++;
      wCount[t.wallet] = (wCount[t.wallet] ?? 0) + 1;
      cCount[t.cat] = (cCount[t.cat] ?? 0) + 1;
      cTotal[t.cat] = (cTotal[t.cat] ?? 0) + t.amount.abs();
    }
    if (links.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(child: Text(tr('Belum ada transaksi di periode ini'), style: TextStyle(fontSize: 13.5, color: z.muted))),
      );
    }
    final wallets = [for (final w in store.wallets) if (wCount.containsKey(w.id)) w];
    final cats = cTotal.keys.toList()..sort((a, b) => cTotal[b]!.compareTo(cTotal[a]!));
    final maxAmt = links.values.map((l) => l.amount).reduce(math.max);
    const rowH = 56.0, nodeH = 40.0;
    final h = math.max(cats.length * rowH, wallets.length * 96.0).toDouble();
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final nodeW = math.min(210.0, (w - 80) / 2);
      double wy(int i) => wallets.length == 1 ? h / 2 : nodeH / 2 + i * ((h - nodeH) / (wallets.length - 1));
      double cy(int i) => nodeH / 2 + i * rowH;
      final wIdx = {for (var i = 0; i < wallets.length; i++) wallets[i].id: i};
      final cIdx = {for (var i = 0; i < cats.length; i++) cats[i]: i};
      bool on(_Link l) => _hover == null || _hover == 'w:${l.wallet}' || _hover == 'c:${l.cat}';
      Widget node({required String id, required Widget icon, required String label, required int n, required double top, required bool left}) {
        final active = _hover == id;
        return Positioned(
          top: top,
          left: left ? 0 : null,
          right: left ? null : 0,
          width: nodeW,
          height: nodeH,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = id),
            onExit: (_) => setState(() => _hover = null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: z.card,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: active ? z.primary : z.chipBorder, width: active ? 1.6 : 1),
              ),
              child: Row(children: [
                icon,
                const SizedBox(width: 9),
                Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                Text(trf('{0} trx', [n]), style: TextStyle(fontSize: 10.5, color: z.muted2)),
              ]),
            ),
          ),
        );
      }

      return SizedBox(
        height: h,
        child: Stack(children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _in,
              builder: (_, _) => CustomPaint(
                painter: _FlowPainter(
                  links: links.values.toList(),
                  wy: (id) => wy(wIdx[id]!),
                  cy: (id) => cy(cIdx[id]!),
                  nodeW: nodeW,
                  maxAmt: maxAmt.toDouble(),
                  typeOf: (id) => store.walletById(id)?.type ?? 'cash',
                  isOn: on,
                  income: z.chart('green'),
                  progress: Curves.easeOutCubic.transform(_in.value),
                ),
              ),
            ),
          ),
          for (var i = 0; i < wallets.length; i++)
            node(
              id: 'w:${wallets[i].id}',
              icon: Icon(walletIcon(wallets[i].type), size: 17, color: flowColor(wallets[i].type)),
              label: wallets[i].name,
              n: wCount[wallets[i].id]!,
              top: wy(i) - nodeH / 2,
              left: true,
            ),
          for (var i = 0; i < cats.length; i++)
            node(
              id: 'c:${cats[i]}',
              icon: Icon(store.category(cats[i]).icon, size: 17, color: z.chart(store.category(cats[i]).tone)),
              label: store.category(cats[i]).label,
              n: cCount[cats[i]]!,
              top: cy(i) - nodeH / 2,
              left: false,
            ),
        ]),
      );
    });
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.links,
    required this.wy,
    required this.cy,
    required this.nodeW,
    required this.maxAmt,
    required this.typeOf,
    required this.isOn,
    required this.income,
    required this.progress,
  });

  final List<_Link> links;
  final double Function(String) wy, cy;
  final double nodeW, maxAmt, progress;
  final String Function(String) typeOf;
  final bool Function(_Link) isOn;
  final Color income;

  @override
  void paint(Canvas canvas, Size size) {
    final x1 = nodeW, x2 = size.width - nodeW;
    // Garis yang disorot digambar paling akhir (di atas).
    final sorted = [...links]..sort((a, b) => (isOn(a) ? 1 : 0).compareTo(isOn(b) ? 1 : 0));
    for (final l in sorted) {
      final y1 = wy(l.wallet), y2 = cy(l.cat);
      final path = Path()
        ..moveTo(x1, y1)
        ..cubicTo(x1 + (x2 - x1) * 0.5, y1, x1 + (x2 - x1) * 0.5, y2, x2, y2);
      final on = isOn(l);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.2 + 3.6 * math.sqrt(l.amount / maxAmt)
        ..color = (l.income ? income : flowColor(typeOf(l.wallet))).withValues(alpha: on ? 0.85 : 0.15);
      final metrics = path.computeMetrics().first;
      final drawn = metrics.extractPath(0, metrics.length * progress);
      if (l.income) {
        var d = 0.0;
        while (d < metrics.length * progress) {
          canvas.drawPath(metrics.extractPath(d, math.min(d + 7, metrics.length * progress)), paint);
          d += 12;
        }
      } else {
        canvas.drawPath(drawn, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlowPainter old) => true;
}
