import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../../widgets/count_up.dart';
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

    final flow = store.dailyFlow(14);

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
        radius: 14,
        border: Border.all(color: z.heroBorder),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(tr('Anggaran bulan ini'), style: TextStyle(fontSize: 14, color: z.heroMuted))),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => editBudget(context, store),
              child: Semantics(
                button: true,
                label: tr('Ubah'),
                child: SizedBox(
                  height: 34,
                  child: OverflowBox(
                    maxHeight: 44,
                    fit: OverflowBoxFit.deferToChild,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
                      ),
                        child: Text(tr('Ubah'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(rp(budget), style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: FillIn(
              value: pct.clamp(0, 1).toDouble(),
              builder: (_, v) => LinearProgressIndicator(
                value: v,
                minHeight: 9,
                backgroundColor: z.heroInner,
                color: pct >= 0.9 ? const Color(0xFFFDBA74) : z.hi,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text(trf('Terpakai {0}', [rp(spentMonth)]), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white))),
            Text(remain >= 0 ? trf('Sisa {0}', [rp(remain)]) : trf('Lebih {0}', [rp(remain)]),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      _FlowChartCard(flow: flow),
      const SizedBox(height: 12),
      _CompositionCard(
        key: ValueKey(_period),
        parts: [for (final e in byCat) (store.category(e.key).label, e.value, z.chart(store.category(e.key).tone))],
        total: total,
      ),
      const SizedBox(height: 22),
      SectionTitle(tr('Rincian per Kategori')),
      const SizedBox(height: 10),
      if (byCat.isEmpty)
        ZCard(child: EmptyState(icon: Icons.donut_small_rounded, title: tr('Belum ada pengeluaran'), message: tr('Rincian kategori muncul setelah kamu mencatat pengeluaran.')))
      else
        ZCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Column(children: [
            for (var i = 0; i < byCat.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
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
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  Text('${(byCat[i].value / total * 100).round()}%  ',
                      style: TextStyle(fontSize: 13, color: z.muted2, fontWeight: FontWeight.w400)),
                  Text(rp(byCat[i].value),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                ]),
              ),
          ]),
        ),
    ]);
  }
}

String _axis(num n) {
  final a = n.abs();
  if (a >= 1000000) {
    final x = a / 1e6;
    return '${x.toStringAsFixed(1).replaceAll('.', ',').replaceAll(RegExp(r',0$'), '')} jt';
  }
  if (a >= 1000) return '${(a / 1000).round()} rb';
  return a.round().toString();
}

double _niceTop(num maxV) {
  if (maxV <= 0) return 400000;
  final m = maxV / 4;
  final p = math.pow(10, (math.log(m) / math.ln10).floor()).toDouble();
  final f = m / p;
  final k = f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10;
  return k * p * 4;
}

/// Kartu "Masuk dan keluar": batang pengeluaran (oranye) dan pemasukan (hijau) 14 hari terakhir,
/// garis putus-putus rata-rata pengeluaran, dan tooltip saat disentuh.
class _FlowChartCard extends StatefulWidget {
  const _FlowChartCard({required this.flow});

  final List<({int exp, int inc, int n})> flow;

  @override
  State<_FlowChartCard> createState() => _FlowChartCardState();
}

class _FlowChartCardState extends State<_FlowChartCard> {
  int? _hover;

  void _touch(double dx, double w) {
    final n = widget.flow.length;
    final k = (dx / w * n).floor().clamp(0, n - 1);
    if (k != _hover) setState(() => _hover = k);
  }

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final f = widget.flow;
    final n = f.length;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final top = _niceTop(f.fold<int>(0, (m, e) => math.max(m, math.max(e.exp, e.inc))));
    final avg = f.fold<int>(0, (a, e) => a + e.exp) / n;
    final today = dayOnly(DateTime.now());
    DateTime dayAt(int i) => DateTime(today.year, today.month, today.day - (n - 1 - i));
    final hv = _hover;
    const axisW = 46.0;
    return Semantics(
      container: true,
      label: tr('Masuk dan keluar'),
      child: ZCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(tr('Masuk dan keluar'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.15)),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: tr('14 hari · rata-rata keluar '), style: TextStyle(fontSize: 11.5, color: z.muted2)),
                  TextSpan(
                      text: rpShort(avg),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: z.muted, fontFeatures: const [FontFeature.tabularFigures()])),
                ]),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 26),
          LayoutBuilder(builder: (context, box) {
            final plotW = box.maxWidth - axisW;
            const h = 170.0;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _touch(d.localPosition.dx - axisW, plotW),
              onTapUp: (_) => setState(() => _hover = null),
              onTapCancel: () => setState(() => _hover = null),
              onPanStart: (d) => _touch(d.localPosition.dx - axisW, plotW),
              onPanUpdate: (d) => _touch(d.localPosition.dx - axisW, plotW),
              onPanEnd: (_) => setState(() => _hover = null),
              onPanCancel: () => setState(() => _hover = null),
              child: SizedBox(
                height: h,
                child: Stack(clipBehavior: Clip.none, children: [
                  for (var i = 0; i < 5; i++)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: h - h * i / 4 - 0.5,
                      height: 1,
                      child: Stack(clipBehavior: Clip.none, children: [
                        Positioned.fill(left: axisW, child: CustomPaint(painter: _DashPainter(z.divider))),
                        Positioned(
                          left: 0,
                          top: -8,
                          child: Text(i == 0 ? '0' : _axis(top * i / 4),
                              style: TextStyle(fontSize: 10.5, color: z.muted2, fontFeatures: const [FontFeature.tabularFigures()])),
                        ),
                      ]),
                    ),
                  Positioned(
                    left: axisW,
                    right: 0,
                    bottom: (avg / top * h).clamp(0, h).toDouble(),
                    child: Opacity(opacity: 0.6, child: SizedBox(height: 2, child: CustomPaint(painter: _DashPainter(z.muted, width: 1.5, dash: 4, gap: 3)))),
                  ),
                  Positioned(
                    left: axisW,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Row(children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: hv == i ? z.primary.withValues(alpha: 0.10) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                              _Bar(value: f[i].exp / top * h, color: z.chart('orange'), index: i, reduce: reduce),
                              const SizedBox(width: 1.5),
                              _Bar(value: f[i].inc / top * h, color: z.chart('green'), index: i, reduce: reduce),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                  if (hv != null)
                    Positioned(
                      left: (axisW + (hv + 0.5) / n * plotW - 62).clamp(0.0, box.maxWidth - 124),
                      top: -8,
                      child: FractionalTranslation(
                        translation: const Offset(0, -1),
                        child: Container(
                          width: 124,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: z.text,
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6))],
                          ),
                          child: DefaultTextStyle(
                            style: TextStyle(fontSize: 11.5, height: 1.45, color: z.bg),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              Text('${dayAt(hv).day} ${monthShort(dayAt(hv))}', style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${tr('Keluar')} ${rpShort(f[hv].exp)}'),
                              Text('${tr('Masuk')} ${rpShort(f[hv].inc)}'),
                              Text(trf('{0} transaksi', [f[hv].n])),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            );
          }),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: axisW),
            child: Row(children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: Text(
                    (i % 2 == 1 || i == n - 1) ? '${dayAt(i).day}' : '',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 9.5, color: z.muted2, fontWeight: i == n - 1 ? FontWeight.w800 : FontWeight.w600),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 4, children: [
            _Legend(color: z.chart('orange'), label: tr('Keluar')),
            _Legend(color: z.chart('green'), label: tr('Masuk')),
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 14, height: 2, child: CustomPaint(painter: _DashPainter(z.muted, width: 1.5, dash: 3, gap: 2))),
              const SizedBox(width: 5),
              Text(tr('Rata-rata'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: z.muted)),
            ]),
          ]),
        ]),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color, required this.index, required this.reduce});

  final double value;
  final Color color;
  final int index;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final h = value <= 0 ? 0.0 : math.max(value, 3.0);
    return Flexible(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduce ? 1 : 0, end: 1),
        duration: reduce ? Duration.zero : Duration(milliseconds: 900 + index * 35),
        curve: const Cubic(0.22, 0.8, 0.3, 1),
        builder: (_, k, _) => Container(
          height: h * k,
          constraints: const BoxConstraints(maxWidth: 9),
          decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(2.5))),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: z.muted)),
    ]);
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color, {this.width = 1, this.dash = 4, this.gap = 3});

  final Color color;
  final double width, dash, gap;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = width;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + dash, size.width), 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color || old.width != width;
}

/// Kartu "Komposisi": cincin pengeluaran per kategori dengan legenda persentase.
class _CompositionCard extends StatelessWidget {
  const _CompositionCard({super.key, required this.parts, required this.total});

  final List<(String, int, Color)> parts;
  final int total;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return ZCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        SizedBox(
          width: 132,
          height: 132,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CustomPaint(
              painter: _DonutPainter(parts: [for (final p in parts) (p.$2.toDouble(), p.$3)], empty: z.track, progress: v),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(rpShort(total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  Text(tr('terpakai'), style: TextStyle(fontSize: 11, color: z.muted2)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Komposisi'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.15)),
            const SizedBox(height: 2),
            Text(tr('Pembagian pengeluaran'), style: TextStyle(fontSize: 12, color: z.muted2)),
            const SizedBox(height: 8),
            if (parts.isEmpty)
              Text(tr('Belum ada pengeluaran'), style: TextStyle(fontSize: 12.5, color: z.muted))
            else
              for (final p in parts.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: p.$3, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))),
                    Text('${(p.$2 / total * 100).round()}%',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                  ]),
                ),
          ]),
        ),
      ]),
    );
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
  bool shouldRepaint(covariant _DonutPainter old) => old.progress != progress || old.parts != parts || old.empty != empty;
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
