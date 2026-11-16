import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../shell/desktop_page.dart';
import '../../widgets/common.dart';
import '../../widgets/count_up.dart';
import '../settings/settings_page.dart' show exportCsvFile;
import 'add_transaction_page.dart';
import 'report_page.dart';

/// Laporan untuk jendela lebar: ringkasan angka, grafik harian, komposisi, dan tabel rincian per kategori.
class DesktopReport extends StatefulWidget {
  const DesktopReport({super.key});

  @override
  State<DesktopReport> createState() => _DesktopReportState();
}

class _DesktopReportState extends State<DesktopReport> {
  int _days = 0; // 7, 14, atau 0 = bulan anggaran ini

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final today = dayOnly(DateTime.now());
    final (pFrom, pTo) = store.periodRange();
    final from = _days == 0 ? pFrom : today.subtract(Duration(days: _days - 1));
    final to = _days == 0 ? pTo : today.add(const Duration(days: 1));
    final n = (today.difference(from).inDays + 1).clamp(1, 62);
    final flow = store.dailyFlow(n);
    final inRange = store.txns.where((t) {
      final d = dayOnly(t.at);
      return !d.isBefore(from) && d.isBefore(to);
    }).toList();
    final income = inRange.where((t) => !t.isExpense).fold(0, (a, t) => a + t.amount);
    final expense = inRange.where((t) => t.isExpense).fold(0, (a, t) => a - t.amount);
    final incN = inRange.where((t) => !t.isExpense).length;
    final expN = inRange.length - incN;
    final byCat = store.spentByCategory(from, to).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = byCat.fold<int>(0, (s, e) => s + e.value);
    final countBy = <String, int>{};
    for (final t in inRange) {
      if (t.isExpense) countBy[t.cat] = (countBy[t.cat] ?? 0) + 1;
    }
    String m(num v) => store.hideBalance ? rpHidden : rp(v);
    final diff = income - expense;

    Widget kpi(IconData icon, String tone, String label, String value, String sub, {Color? color}) => DCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconTile(icon: icon, tone: tone, size: 32, radius: 9),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: z.text2))),
            ]),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 12.5, color: z.muted2)),
          ]),
        );

    final head = Row(children: [
      SizedBox(
        width: 290,
        child: Segmented<int>(
          height: 40,
          items: [(7, tr('7 hari')), (14, tr('14 hari')), (0, tr('Bulan ini'))],
          value: _days,
          onChanged: (v) => setState(() => _days = v),
        ),
      ),
      const Spacer(),
      OutlinedButton.icon(
        onPressed: () => exportCsvFile(context, store),
        icon: const Icon(Icons.download_rounded, size: 19),
        label: Text(tr('Ekspor CSV'), style: const TextStyle(fontWeight: FontWeight.w800)),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ]);

    return DesktopPage(
      title: tr('Laporan'),
      subtitle: tr('Ringkasan pemasukan dan pengeluaran'),
      action: FilledButton.icon(
        onPressed: () => pushPage(context, const AddTransactionPage(income: false)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(tr('Tambah transaksi'), style: const TextStyle(fontWeight: FontWeight.w800)),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
      ),
      children: [
        head,
        const SizedBox(height: 20),
        DCols(minChild: 240, children: [
          kpi(Icons.south_west_rounded, 'green', tr('Pemasukan'), m(income), trf('{0} transaksi', [incN]), color: z.accentText),
          kpi(Icons.north_east_rounded, 'orange', tr('Pengeluaran'), m(expense), trf('{0} transaksi', [expN])),
          kpi(Icons.balance_rounded, 'blue', tr('Selisih'), store.hideBalance ? rpHidden : rpSigned(diff), diff >= 0 ? tr('Surplus') : tr('Defisit'), color: diff >= 0 ? z.accentText : z.warn),
          kpi(Icons.calendar_today_rounded, 'purple', tr('Rata-rata harian'), m((expense / n).round()), tr('Pengeluaran per hari')),
        ]),
        const SizedBox(height: 20),
        DCols(minChild: 380, flex: const [2, 1], children: [
          FlowChartCard(flow: flow, desktop: true),
          _Composition(parts: [for (final e in byCat) (store.category(e.key).label, e.value, z.chart(store.category(e.key).tone))], total: total, hidden: store.hideBalance),
        ]),
        const SizedBox(height: 20),
        DCard(
          title: tr('Rincian per kategori'),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
          child: byCat.isEmpty
              ? Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(tr('Belum ada pengeluaran'), style: TextStyle(color: z.muted)))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Row(children: [
                      const SizedBox(width: 56),
                      Expanded(flex: 2, child: Text(tr('Kategori'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: z.muted2))),
                      Expanded(flex: 5, child: Text(tr('Porsi'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: z.muted2))),
                      SizedBox(width: 130, child: Text(tr('Jumlah'), textAlign: TextAlign.end, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: z.muted2))),
                      SizedBox(width: 90, child: Text(tr('Transaksi'), textAlign: TextAlign.end, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: z.muted2))),
                    ]),
                  ),
                  for (final e in byCat)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: z.divider))),
                      child: Row(children: [
                        CategoryTile(category: store.category(e.key), size: 40),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: Text(store.category(e.key).label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 40),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: FillIn(
                                value: byCat.first.value == 0 ? 0 : e.value / byCat.first.value,
                                builder: (_, v) => LinearProgressIndicator(value: v, minHeight: 5, backgroundColor: z.track, color: z.chart(store.category(e.key).tone)),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 130, child: Text(m(e.value), textAlign: TextAlign.end, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]))),
                        SizedBox(width: 90, child: Text('${countBy[e.key] ?? 0}', textAlign: TextAlign.end, style: TextStyle(fontSize: 13, color: z.muted))),
                      ]),
                    ),
                ]),
        ),
      ],
    );
  }
}

class _Composition extends StatelessWidget {
  const _Composition({required this.parts, required this.total, required this.hidden});

  final List<(String, int, Color)> parts;
  final int total;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return DCard(
      title: tr('Komposisi'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: SizedBox(
            width: 190,
            height: 190,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => CustomPaint(
                painter: DonutPainter(parts: [for (final p in parts) (p.$2.toDouble(), p.$3)], empty: z.track, progress: v),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(tr('Total'), style: TextStyle(fontSize: 11.5, color: z.muted2)),
                    Text(hidden ? rpHidden : rp(total), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.2)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (parts.isEmpty)
          Text(tr('Belum ada pengeluaran'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: z.muted))
        else
          for (final p in parts.take(7))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.5),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: p.$3, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10),
                Expanded(child: Text(p.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                Text('${(p.$2 / total * 100).round()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ),
      ]),
    );
  }
}
