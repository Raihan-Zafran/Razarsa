import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../settings/profile_page.dart';
import 'add_transaction_page.dart';
import '../../widgets/mode_widgets.dart';
import '../../core/i18n.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final recent = store.txns.take(4).toList();

    return PageScroll(children: [
      // Header: logo, tombol mode, profil
      Row(children: [
        const Expanded(child: Align(alignment: Alignment.centerLeft, child: ModeSwitch())),
        const ThemeToggle(),
        const SizedBox(width: 8),
        RoundIconButton(
          icon: Icons.person_outline_rounded,
          tooltip: tr('Buka profil'),
          filled: true,
          onTap: () => pushPage(context, const ProfilePage()),
        ),
      ]),
      const SizedBox(height: 18),
      Text('${greeting()},', style: TextStyle(fontSize: 13, color: z.muted)),
      const SizedBox(height: 2),
      Text(
        store.userName.isEmpty ? tr('Yuk, atur uangmu!') : trf('Halo, {0}!', [store.userName]),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
      ),
      const SizedBox(height: 18),
      _BalanceCard(store: store),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _AddButton(
            label: tr('Pengeluaran'),
            filled: true,
            onTap: () => pushPage(context, const AddTransactionPage(income: false)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AddButton(
            label: tr('Pemasukan'),
            filled: false,
            onTap: () => pushPage(context, const AddTransactionPage(income: true)),
          ),
        ),
      ]),
      const SizedBox(height: 22),
      SectionTitle(tr('Catat Cepat'),
          trailing: Text(tr('Sekali tap langsung tercatat'), style: TextStyle(fontSize: 12, color: z.muted2))),
      const SizedBox(height: 10),
      SizedBox(
        height: scaledHeight(context, 52),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: store.quickItems.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) => _QuickChip(item: store.quickItems[i]),
        ),
      ),
      const SizedBox(height: 22),
      SectionTitle(tr('Transaksi Terbaru'),
          trailing: TextButton(
            onPressed: onSeeAll,
            child: Text(tr('Lihat semua'), style: TextStyle(color: z.accentText, fontWeight: FontWeight.w700)),
          )),
      const SizedBox(height: 6),
      if (recent.isEmpty)
        ZCard(
          child: EmptyState(
            title: tr('Belum ada transaksi'),
            message: tr('Catat pengeluaran atau pemasukan pertamamu lewat tombol di atas.'),
          ),
        )
      else
        ZCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < recent.length; i++)
              TxnRow(
                category: store.category(recent[i].cat),
                title: recent[i].name,
                subtitle: '${dayLabel(recent[i].at)}, ${timeLabel(recent[i].at)}',
                amountText: rpSigned(recent[i].amount),
                isIncome: !recent[i].isExpense,
                showDivider: i < recent.length - 1,
              ),
          ]),
        ),
    ]);
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return GlassPane(
      hero: true,
      color: z.hero,
      radius: 24,
      border: Border.all(color: z.heroBorder),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Total Saldo'), style: TextStyle(fontSize: 13, color: z.heroMuted)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  store.hideBalance ? rpHidden : (store.balance < 0 ? '-' : '') + rp(store.balance),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.6),
                ),
              ),
            ]),
          ),
          _BalanceSpark(series: store.balanceSeries(12), hidden: store.hideBalance),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _MiniStat(label: tr('Pemasukan'), value: rp(store.monthIncome()), up: false)),
          const SizedBox(width: 10),
          Expanded(child: _MiniStat(label: tr('Pengeluaran'), value: rp(store.monthExpense()), up: true)),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.up});

  final String label;
  final String value;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: z.heroInner, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 14, color: up ? const Color(0xFFFDBA74) : const Color(0xFF86EFAC)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: z.heroMuted)),
          ),
        ]),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ]),
    );
  }
}

/// Garis kecil saldo 12 hari terakhir di kartu saldo. Isinya data nyata (saldo akhir tiap hari).
/// Sentuh atau geser untuk melihat saldo per hari.
class _BalanceSpark extends StatefulWidget {
  const _BalanceSpark({required this.series, required this.hidden});

  final List<int> series;
  final bool hidden;

  @override
  State<_BalanceSpark> createState() => _BalanceSparkState();
}

class _BalanceSparkState extends State<_BalanceSpark> with TickerProviderStateMixin {
  static const _w = 84.0, _h = 48.0;
  // Garis menggambar dirinya (1,1 dtk, mulai setelah 0,1 dtk); titik akhir berdenyut beberapa kali.
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  bool _started = false;
  int? _hover;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _draw.value = 1;
    } else {
      _draw.forward();
      _pulse.repeat(count: 4);
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _pulse.dispose();
    super.dispose();
  }

  List<Offset> get _pts {
    final v = widget.series;
    final lo = v.reduce(math.min), hi = v.reduce(math.max);
    final span = (hi - lo) == 0 ? 1 : (hi - lo);
    return [for (var i = 0; i < v.length; i++) Offset(3 + i / (v.length - 1) * 78, 4 + 40 * (1 - (v[i] - lo) / span))];
  }

  void _touch(Offset local) {
    final n = widget.series.length;
    final k = (local.dx / _w).clamp(0.0, 1.0);
    final i = (k * (n - 1)).round();
    if (i != _hover) setState(() => _hover = i);
  }

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final n = widget.series.length;
    final hv = _hover;
    final today = dayOnly(DateTime.now());
    String? tip;
    if (hv != null) {
      final d = DateTime(today.year, today.month, today.day - (n - 1 - hv));
      tip = '${d.day} ${monthShort(d)} · ${widget.hidden ? rpHidden : rp(widget.series[hv])}';
    }
    return Semantics(
      container: true,
      label: tr('Saldo 12 hari terakhir'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _touch(d.localPosition),
        onTapUp: (_) => setState(() => _hover = null),
        onTapCancel: () => setState(() => _hover = null),
        onPanStart: (d) => _touch(d.localPosition),
        onPanUpdate: (d) => _touch(d.localPosition),
        onPanEnd: (_) => setState(() => _hover = null),
        onPanCancel: () => setState(() => _hover = null),
        child: SizedBox(
          width: _w,
          height: _h,
          child: Stack(clipBehavior: Clip.none, children: [
            AnimatedBuilder(
              animation: Listenable.merge([_draw, _pulse]),
              builder: (_, _) => CustomPaint(
                size: const Size(_w, _h),
                painter: _SparkPainter(
                  pts: _pts,
                  draw: Interval(0.083, 1, curve: const Cubic(0.22, 0.8, 0.3, 1)).transform(_draw.value),
                  pulse: _pulse.isAnimating ? _pulse.value : null,
                  hover: hv,
                ),
              ),
            ),
            if (tip != null)
              Positioned(
                top: -34,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Text(tip, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: z.hero)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({required this.pts, required this.draw, required this.pulse, required this.hover});

  final List<Offset> pts;
  final double draw;
  final double? pulse;
  final int? hover;

  static const _green = Color(0xFF86EFAC);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    final paint = Paint()
      ..color = _green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * draw), paint);
    }
    final end = pts.last;
    if (pulse != null) {
      canvas.drawCircle(end, 4 * (1 + 2 * pulse!), Paint()..color = _green.withValues(alpha: 0.55 * (1 - pulse!)));
    }
    canvas.drawCircle(end, 4, Paint()..color = _green);
    if (hover != null) canvas.drawCircle(pts[hover!], 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.draw != draw || old.pulse != pulse || old.hover != hover || old.pts != pts;
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.filled, required this.onTap});

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Material(
      color: filled ? z.primary : z.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: filled ? BorderSide.none : BorderSide(color: z.primary, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_rounded, size: 20, color: filled ? z.onPrimary : z.accentText),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: filled ? z.onPrimary : z.accentText)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.item});

  final QuickEntry item;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final z = ZColors.of(context);
    final cat = store.category(item.cat);
    return Material(
      color: z.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: z.cardBorder)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final t = store.addTxn(name: item.name, cat: item.cat, amount: -item.amount);
          showZToast(context, trf('{0} {1} dicatat', [tr(item.name), rp(item.amount)]),
              actionLabel: tr('Batalkan'), onAction: () => store.removeTxn(t.id));
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
          child: Row(children: [
            CategoryTile(category: cat, size: 36),
            const SizedBox(width: 10),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(item.name), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(rpShort(item.amount), style: TextStyle(fontSize: 11, color: z.muted2)),
            ]),
            const SizedBox(width: 14),
            // Penanda "tambah" kecil; seluruh chip tetap satu tombol.
            ExcludeSemantics(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: z.primary, shape: BoxShape.circle),
                child: Icon(Icons.add_rounded, size: 16, color: z.onPrimary),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
