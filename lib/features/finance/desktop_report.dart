import 'dart:convert' show HtmlEscape;
import 'dart:io';

import 'package:flutter/foundation.dart';
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

    Widget kpi(IconData icon, String tone, String label, num value, String Function(num) fmt, String sub, {Color? color}) => DCard(
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
              child: Builder(builder: (context) {
                final style = TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: color, fontFeatures: const [FontFeature.tabularFigures()]);
                // Angka besar menghitung naik saat halaman dibuka (prototipe flowCount).
                return store.hideBalance ? Text(rpHidden, style: style) : CountUp(value: value, format: fmt, style: style);
              }),
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
      FilledButton.icon(
        onPressed: () => exportCsvFile(context, store),
        icon: const Icon(Icons.download_rounded, size: 19),
        label: Text(tr('Ekspor CSV')),
        style: FilledButton.styleFrom(backgroundColor: z.track, foregroundColor: z.text2),
      ),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ...[
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: () => _print(context, store, from, to, income, expense, byCat, countBy),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 19),
          label: Text(tr('Cetak laporan')),
          style: FilledButton.styleFrom(backgroundColor: z.track, foregroundColor: z.text2),
        ),
      ],
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
          kpi(Icons.south_west_rounded, 'green', tr('Pemasukan'), income, rp, trf('{0} transaksi', [incN]), color: z.accentText),
          kpi(Icons.north_east_rounded, 'orange', tr('Pengeluaran'), expense, rp, trf('{0} transaksi', [expN])),
          kpi(Icons.balance_rounded, 'blue', tr('Selisih'), diff, rpSigned, diff >= 0 ? tr('Surplus') : tr('Defisit'), color: diff >= 0 ? z.accentText : z.warn),
          kpi(Icons.calendar_today_rounded, 'purple', tr('Rata-rata harian'), (expense / n).round(), rp, tr('Pengeluaran per hari')),
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

/// Cetak laporan (Windows): halaman laporan siap cetak dibuka di peramban bawaan, yang langsung
/// menampilkan dialog cetak (pilih printer atau "Simpan sebagai PDF").
Future<void> _print(BuildContext context, AppStore store, DateTime from, DateTime to, int income, int expense,
    List<MapEntry<String, int>> byCat, Map<String, int> countBy) async {
  try {
    final html = reportHtml(store, from, to, income, expense, byCat, countBy);
    final f = File('${Directory.systemTemp.path}${Platform.pathSeparator}razarsa-laporan-${DateTime.now().millisecondsSinceEpoch}.html');
    await f.writeAsString(html);
    await Process.start('explorer.exe', [f.path]);
    if (context.mounted) showZToast(context, tr('Pilih printer atau “Simpan sebagai PDF”'));
  } catch (e) {
    debugPrint('Razarsa: laporan gagal dicetak: $e');
    if (context.mounted) showZToast(context, tr('Laporan gagal dibuka'));
  }
}

/// HTML laporan siap cetak: ringkasan, rincian per kategori, dan daftar transaksi pada periode itu.
@visibleForTesting
String reportHtml(AppStore store, DateTime from, DateTime to, int income, int expense, List<MapEntry<String, int>> byCat, Map<String, int> countBy) {
  const esc = HtmlEscape();
  final last = to.subtract(const Duration(days: 1));
  final txns = store.txns.where((t) => !t.at.isBefore(from) && t.at.isBefore(to)).toList()..sort((a, b) => a.at.compareTo(b.at));
  final total = byCat.fold<int>(0, (a, e) => a + e.value);
  final b = StringBuffer()
    ..write('<!doctype html><html lang="${L.en ? 'en' : 'id'}"><head><meta charset="utf-8"><title>${esc.convert(tr('Laporan'))} Razarsa</title><style>')
    ..write('body{font-family:"Segoe UI",Arial,sans-serif;color:#17130C;margin:32px;font-size:13px}h1{font-size:24px;margin:0}')
    ..write('.sub{color:#665F4F;margin:4px 0 20px}.kpi{display:flex;gap:12px;margin-bottom:22px}.kpi div{flex:1;border:1px solid #E6DFCF;border-radius:12px;padding:12px 14px}')
    ..write('.kpi b{display:block;font-size:18px;margin-top:4px}h2{font-size:15px;margin:22px 0 8px}table{width:100%;border-collapse:collapse}')
    ..write('th,td{text-align:left;padding:7px 6px;border-bottom:1px solid #EEE9DC}th{color:#665F4F;font-size:11.5px;text-transform:uppercase}')
    ..write('.r{text-align:right;font-variant-numeric:tabular-nums}.foot{margin-top:24px;color:#665F4F;font-size:11px}@media print{body{margin:12mm}}')
    ..write('</style></head><body>')
    ..write('<h1>${esc.convert(tr('Laporan'))} · Razarsa</h1>')
    ..write('<div class="sub">${esc.convert('${shortDate(from)} – ${shortDate(last)}')}${store.userName.isEmpty ? '' : ' · ${esc.convert(store.userName)}'}</div>')
    ..write('<div class="kpi"><div>${esc.convert(tr('Pemasukan'))}<b>${esc.convert(rp(income))}</b></div>')
    ..write('<div>${esc.convert(tr('Pengeluaran'))}<b>${esc.convert(rp(expense))}</b></div>')
    ..write('<div>${esc.convert(tr('Selisih'))}<b>${esc.convert(rpSigned(income - expense))}</b></div></div>')
    ..write('<h2>${esc.convert(tr('Rincian per kategori'))}</h2><table><tr><th>${esc.convert(tr('Kategori'))}</th><th class="r">${esc.convert(tr('Porsi'))}</th>')
    ..write('<th class="r">${esc.convert(tr('Jumlah'))}</th><th class="r">${esc.convert(tr('Transaksi'))}</th></tr>');
  for (final e in byCat) {
    final pct = total == 0 ? 0 : (e.value / total * 100).round();
    b.write('<tr><td>${esc.convert(store.category(e.key).label)}</td><td class="r">$pct%</td><td class="r">${esc.convert(rp(e.value))}</td><td class="r">${countBy[e.key] ?? 0}</td></tr>');
  }
  if (byCat.isEmpty) b.write('<tr><td colspan="4">${esc.convert(tr('Belum ada pengeluaran'))}</td></tr>');
  b.write('</table><h2>${esc.convert(tr('Transaksi'))}</h2><table><tr><th>${esc.convert(tr('Tanggal'))}</th><th>${esc.convert(tr('Nama'))}</th>'
      '<th>${esc.convert(tr('Kategori'))}</th><th>${esc.convert(tr('Sumber'))}</th><th class="r">${esc.convert(tr('Jumlah'))}</th></tr>');
  for (final t in txns) {
    b.write('<tr><td>${esc.convert('${shortDate(t.at)} ${timeLabel(t.at)}')}</td><td>${esc.convert(t.name)}</td><td>${esc.convert(store.category(t.cat).label)}</td>'
        '<td>${esc.convert(store.walletName(t.wallet))}</td><td class="r">${esc.convert(rpSigned(t.amount))}</td></tr>');
  }
  b
    ..write('</table><div class="foot">${esc.convert(trf('Dibuat {0} · data hanya di perangkat ini', ['${shortDate(DateTime.now())} ${timeLabel(DateTime.now())}']))}</div>')
    ..write('<script>window.addEventListener("load",function(){setTimeout(function(){window.print()},300)})</script></body></html>');
  return b.toString();
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
              // Prototipe ringIn: 1,3 s, tertunda 0,25 s.
              duration: const Duration(milliseconds: 1550),
              curve: const Interval(0.16, 1, curve: Cubic(0.22, 0.8, 0.3, 1)),
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
          for (final (i, p) in parts.take(7).indexed)
            RowIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.5),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: p.$3, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  Text('${(p.$2 / total * 100).round()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                ]),
              ),
            ),
      ]),
    );
  }
}
