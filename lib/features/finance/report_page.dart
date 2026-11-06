import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';

enum Period { week, month, year }

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  Period _period = Period.month;

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    switch (_period) {
      case Period.week:
        final start = dayOnly(now).subtract(const Duration(days: 6));
        return (start, dayOnly(now).add(const Duration(days: 1)));
      case Period.year:
        return (DateTime(now.year), DateTime(now.year + 1));
      case Period.month:
        return (DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final spentMonth = store.monthExpense();
    final budget = store.monthlyBudget;
    final pct = budget > 0 ? spentMonth / budget : 0.0;
    final remain = budget - spentMonth;

    final (from, to) = _range();
    final byCat = store.spentByCategory(from, to).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = byCat.fold<int>(0, (s, e) => s + e.value);

    final months = store.lastMonths(6);
    final last = months[4].value, cur = months[5].value;
    String trend;
    Color trendColor;
    if (last == 0) {
      trend = 'Belum ada data bulan lalu';
      trendColor = z.muted2;
    } else {
      final d = (cur - last) / last * 100;
      trend = '${d <= 0 ? 'Turun' : 'Naik'} ${d.abs().toStringAsFixed(1).replaceAll('.', ',')}% dari ${monthLong(months[4].key)}';
      trendColor = d <= 0 ? z.accentText : z.warn;
    }

    return PageScroll(children: [
      const PageTitle('Laporan'),
      const SizedBox(height: 12),
      Segmented<Period>(
        height: 36,
        items: const [(Period.week, 'Minggu'), (Period.month, 'Bulan'), (Period.year, 'Tahun')],
        value: _period,
        onChanged: (p) => setState(() => _period = p),
      ),
      const SizedBox(height: 16),
      // Kartu anggaran bulan ini
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: z.hero, borderRadius: BorderRadius.circular(24), border: Border.all(color: z.heroBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Anggaran bulan ini', style: TextStyle(fontSize: 13, color: z.heroMuted)),
                const SizedBox(height: 4),
                Text(rp(budget), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ),
            OutlinedButton(
              onPressed: () => editBudget(context, store),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: z.heroInner,
                side: BorderSide(color: z['heroMuted'].withValues(alpha: 0.4)),
                shape: const StadiumBorder(),
              ),
              child: const Text('Ubah', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: pct.clamp(0, 1).toDouble()),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: z.heroInner,
                color: pct >= 0.9 ? const Color(0xFFFDBA74) : const Color(0xFF86EFAC),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text('Terpakai ${rp(spentMonth)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: z.heroMuted))),
            Text(remain >= 0 ? 'Sisa ${rp(remain)}' : 'Lebih ${rp(remain)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: z.heroMuted)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      // Tren + donut berdampingan
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: ZCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tren', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(trend, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: trendColor, height: 1.35)),
                const SizedBox(height: 10),
                SizedBox(height: 124, child: _Bars(months: months)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ZCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Per Kategori', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Pembagian belanja', style: TextStyle(fontSize: 11, color: z.muted2)),
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    width: 124,
                    height: 124,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_period),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => CustomPaint(
                        painter: _DonutPainter(
                          parts: [for (final e in byCat) (e.value.toDouble(), z.chart(store.category(e.key).tone))],
                          empty: z.track,
                          progress: v,
                        ),
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(rpShort(total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            Text('terpakai', style: TextStyle(fontSize: 10, color: z.muted2)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      _BudgetMood(pct: pct, hasSpending: spentMonth > 0),
      const SizedBox(height: 18),
      const SectionTitle('Rincian per Kategori'),
      const SizedBox(height: 10),
      if (byCat.isEmpty)
        const ZCard(child: EmptyState(title: 'Belum ada pengeluaran', message: 'Rincian kategori muncul setelah kamu mencatat pengeluaran.'))
      else
        ZCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Column(children: [
            for (var i = 0; i < byCat.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: i < byCat.length - 1 ? z.divider : Colors.transparent)),
                ),
                child: Row(children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: z.chart(store.category(byCat[i].key).tone), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(store.category(byCat[i].key).label,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  Text('${(byCat[i].value / total * 100).round()}%  ',
                      style: TextStyle(fontSize: 12, color: z.muted2, fontWeight: FontWeight.w600)),
                  Text(rp(byCat[i].value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ]),
              ),
          ]),
        ),
    ]);
  }
}

class _BudgetMood extends StatelessWidget {
  const _BudgetMood({required this.pct, required this.hasSpending});

  final double pct;
  final bool hasSpending;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final warn = pct >= 0.9;
    final title = warn
        ? (pct >= 1 ? 'Anggaran bulan ini sudah habis' : 'Anggaran bulan ini hampir habis')
        : hasSpending
            ? 'Pengeluaran masih aman'
            : 'Belum ada pengeluaran bulan ini';
    final body = warn
        ? 'Sudah terpakai ${(pct * 100).round()}% dari anggaran. Coba tahan dulu belanja yang tidak penting, ya.'
        : 'Kerja bagus! Pertahankan pengeluaranmu di bawah 70% anggaran.';
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      decoration: BoxDecoration(
        color: warn ? z['warnBg'] : z['tipBg'],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warn ? z['warnBorder'] : z['tipBorder']),
      ),
      child: Row(children: [
        Image.asset(warn ? Assets.mascotWorried : Assets.mascotCelebrate, width: 76),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: warn ? z['warnTitle'] : z['tipTitle'])),
            const SizedBox(height: 4),
            Text(body, style: TextStyle(fontSize: 13, height: 1.45, color: warn ? z['warnText'] : z['tipText'])),
          ]),
        ),
      ]),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.months});

  final List<MapEntry<DateTime, int>> months;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final maxV = months.map((e) => e.value).fold<int>(0, math.max);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < months.length; i++)
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: maxV == 0 ? 0 : months[i].value / maxV),
              duration: Duration(milliseconds: 500 + i * 60),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Container(
                width: 14,
                height: math.max(6, 98 * v),
                decoration: BoxDecoration(
                  color: i == months.length - 1 ? z.primary : z['barMuted'],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(monthShort(months[i].key),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: i == months.length - 1 ? FontWeight.w800 : FontWeight.w500,
                  color: i == months.length - 1 ? z.accentText : z.muted2,
                )),
          ]),
        ),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.parts, required this.empty, required this.progress});

  final List<(double, Color)> parts;
  final Color empty;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = empty;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    final total = parts.fold<double>(0, (s, p) => s + p.$1);
    if (total <= 0) return;
    var start = -math.pi / 2;
    final sweepAll = math.pi * 2 * progress;
    for (final (v, color) in parts) {
      final sweep = v / total * sweepAll;
      canvas.drawArc(rect, start, sweep, false, base..color = color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}

/// Dialog untuk mengubah anggaran bulanan.
Future<void> editBudget(BuildContext context, AppStore store) async {
  final ctrl = TextEditingController(text: dots(store.monthlyBudget));
  final value = await showDialog<int>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Anggaran bulanan'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(prefixText: 'Rp ', hintText: '5000000'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(c, int.tryParse(ctrl.text.replaceAll('.', ''))),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
  if (value != null && value > 0) store.setBudget(value);
}
