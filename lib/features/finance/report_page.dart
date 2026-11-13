import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../../core/i18n.dart';

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
        final start = StoreScope.read(context).weekStart(now);
        return (start, start.add(const Duration(days: 7)));
      case Period.year:
        return (DateTime(now.year), DateTime(now.year + 1));
      case Period.month:
        return StoreScope.read(context).periodRange();
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

    final daily = store.dailyExpense(14);

    return PageScroll(children: [
      PageTitle(tr('Laporan')),
      const SizedBox(height: 12),
      Segmented<Period>(
        height: 36,
        items: [(Period.week, tr('Minggu')), (Period.month, tr('Bulan')), (Period.year, tr('Tahun'))],
        value: _period,
        onChanged: (p) => setState(() => _period = p),
      ),
      const SizedBox(height: 16),
      // Kartu anggaran bulan ini
      GlassPane(
        hero: true,
        color: z.hero,
        radius: 24,
        border: Border.all(color: z.heroBorder),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Anggaran bulan ini'), style: TextStyle(fontSize: 13, color: z.heroMuted)),
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
              child: Text(tr('Ubah'), style: TextStyle(fontWeight: FontWeight.w700)),
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
            Expanded(child: Text(trf('Terpakai {0}', [rp(spentMonth)]), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: z.heroMuted))),
            Text(remain >= 0 ? trf('Sisa {0}', [rp(remain)]) : trf('Lebih {0}', [rp(remain)]),
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
                Text(tr('14 hari terakhir'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(trf('rata-rata {0}', [rpShort(daily.fold<int>(0, (a, b) => a + b) / 14)]),
                    style: TextStyle(fontSize: 11, color: z.muted2, fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(height: 22),
                SizedBox(height: scaledHeight(context, 104), child: _DailyBars(values: daily)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ZCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Per Kategori'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(tr('Pembagian belanja'), style: TextStyle(fontSize: 11, color: z.muted2)),
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
      SectionTitle(tr('Rincian per Kategori')),
      const SizedBox(height: 10),
      if (byCat.isEmpty)
        ZCard(child: EmptyState(title: tr('Belum ada pengeluaran'), message: tr('Rincian kategori muncul setelah kamu mencatat pengeluaran.')))
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
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Text('${(byCat[i].value / total * 100).round()}%  ',
                      style: TextStyle(fontSize: 12, color: z.muted2, fontWeight: FontWeight.w400)),
                  Text(rp(byCat[i].value),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
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
        ? (pct >= 1 ? tr('Anggaran bulan ini sudah habis') : tr('Anggaran bulan ini hampir habis'))
        : hasSpending
            ? tr('Pengeluaran masih aman')
            : tr('Belum ada pengeluaran bulan ini');
    final body = warn
        ? trf('Sudah terpakai {0}% dari anggaran. Coba tahan dulu belanja yang tidak penting, ya.', [(pct * 100).round()])
        : tr('Kerja bagus! Pertahankan pengeluaranmu di bawah 70% anggaran.');
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

/// Batang pengeluaran harian untuk 14 hari terakhir; hari ini berwarna hijau.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final maxV = values.fold<int>(0, math.max);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day - (values.length - 1));
    return Column(children: [
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: LayoutBuilder(builder: (_, c) {
                final v = values[i];
                final full = v == 0 ? 4.0 : math.max(6.0, (v / maxV * (c.maxHeight - 16)).roundToDouble());
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: reduce ? 1 : 0, end: 1),
                    duration: reduce ? Duration.zero : Duration(milliseconds: 500 + i * 30),
                    curve: const Cubic(0.22, 0.8, 0.3, 1),
                    builder: (_, k, _) => Container(
                      height: full * k,
                      decoration: BoxDecoration(
                        color: i == values.length - 1 ? z.primary : (v > 0 ? z['chipBorder'] : z.track),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${first.day} ${monthShort(first)}', style: TextStyle(fontSize: 10, color: z.muted2)),
        Text(tr('Hari ini'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: z.accentText)),
      ]),
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
      title: Text(tr('Anggaran bulanan')),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(prefixText: '$currencySymbol '),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Batal'))),
        FilledButton(
          onPressed: () => Navigator.pop(c, int.tryParse(ctrl.text.replaceAll(RegExp(r'\D'), ''))),
          child: Text(tr('Simpan')),
        ),
      ],
    ),
  );
  if (value != null && value > 0) store.setBudget(value);
}
