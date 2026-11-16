import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../shell/desktop_page.dart';
import '../../widgets/common.dart';
import '../../widgets/count_up.dart';
import '../saldo/saldo_page.dart';
import 'add_transaction_page.dart';
import 'goals_page.dart';
import 'home_page.dart';

/// Beranda desktop: ringkasan saldo, grafik, anggaran, transaksi terbaru, sumber saldo, target, dan tugas hari ini.
/// Kartu tersusun menurut lebar jendela.
class DesktopHome extends StatelessWidget {
  const DesktopHome({super.key, required this.onGo});

  /// Pindah halaman lewat nomor tujuan di sidebar (1 Transaksi, 2 Saldo, 3 Laporan, 4 Target, 6 Tugas).
  final void Function(int index) onGo;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    return DesktopPage(
      title: tr('Beranda'),
      subtitle: tr('Ringkasan uang dan kegiatanmu hari ini'),
      action: FilledButton.icon(
        onPressed: () => pushPage(context, const AddTransactionPage(income: false)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(tr('Tambah transaksi'), style: const TextStyle(fontWeight: FontWeight.w800)),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
      ),
      children: [
        _Hero(store: store),
        const SizedBox(height: 20),
        DCols(minChild: 340, flex: const [5, 3], children: [
          BalanceChartCard(
            series: store.balanceSeries(14),
            hidden: store.hideBalance,
            desktop: true,
            badge: _Pill(trf('{0} sumber', [store.wallets.length])),
          ),
          _BudgetCard(store: store),
        ]),
        const SizedBox(height: 20),
        DCols(minChild: 360, flex: const [7, 6], children: [
          _Recent(store: store, onAll: () => onGo(1)),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Quick(store: store),
            const SizedBox(height: 20),
            _Wallets(store: store, onMap: () => onGo(2)),
          ]),
        ]),
        const SizedBox(height: 20),
        DCols(minChild: 300, flex: const [4, 4, 3], children: [
          _Where(store: store, onAll: () => onGo(3)),
          _Goals(store: store, onAll: () => onGo(4)),
          _Today(store: store, onAll: () => onGo(6), tint: z.toneBg('amber')),
        ]),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: z.toneBg('green'), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: z.toneFg('green'))),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final name = store.userName.isEmpty ? '' : ', ${store.userName}';
    final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Flexible(
          child: Text('${greeting()}$name · ${trf('total saldo {0} sumber', [store.wallets.length])}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, color: z.heroMuted)),
        ),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: store.hideBalance ? tr('Tampilkan saldo') : tr('Sembunyikan saldo'),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => store.setSwitch('hide', !store.hideBalance),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.12)),
              child: Icon(store.hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 17, color: z.heroMuted),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: store.hideBalance
            ? Text(rpHidden, style: _big)
            : CountUp(value: store.balance.abs(), format: (n) => (store.balance < 0 ? '-' : '') + rp(n), style: _big),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 28, runSpacing: 6, children: [
        _Stat(icon: Icons.south_west_rounded, label: tr('Masuk bulan ini'), value: store.monthIncome(), hidden: store.hideBalance),
        _Stat(icon: Icons.north_east_rounded, label: tr('Keluar bulan ini'), value: store.monthExpense(), hidden: store.hideBalance),
      ]),
    ]);
    final buttons = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _HeroBtn(
        label: tr('Catat pengeluaran'),
        icon: Icons.remove_rounded,
        filled: true,
        onTap: () => pushPage(context, const AddTransactionPage(income: false)),
      ),
      const SizedBox(height: 12),
      _HeroBtn(
        label: tr('Catat pemasukan'),
        icon: Icons.add_rounded,
        filled: false,
        onTap: () => pushPage(context, const AddTransactionPage(income: true)),
      ),
    ]);
    return Semantics(
      container: true,
      label: tr('Total saldo'),
      child: GlassPane(
        hero: true,
        color: z.hero,
        color2: z.hero2,
        radius: 20,
        border: Border.all(color: z.heroBorder),
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 26),
        child: LayoutBuilder(builder: (context, box) {
          if (box.maxWidth < 680) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 18), buttons]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: left),
            const SizedBox(width: 24),
            SizedBox(width: 210, child: buttons),
          ]);
        }),
      ),
    );
  }

  static const _big = TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.6, height: 1.05);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, required this.hidden});

  final IconData icon;
  final String label;
  final num value;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 17, color: z.heroMuted),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 13.5, color: z.heroMuted)),
      const SizedBox(width: 8),
      Text(hidden ? rpHidden : rp(value), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white)),
    ]);
  }
}

class _HeroBtn extends StatelessWidget {
  const _HeroBtn({required this.label, required this.icon, required this.filled, required this.onTap});

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final fg = filled ? const Color(0xFF241A05) : Colors.white;
    return Material(
      color: filled ? z.hi : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: filled ? BorderSide.none : BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fg))),
          ]),
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final budget = store.monthlyBudget;
    final spent = store.monthExpense();
    final pct = budget > 0 ? spent / budget : 0.0;
    final (from, to) = store.periodRange();
    final today = dayOnly(DateTime.now());
    final daysLeft = (to.difference(today).inDays).clamp(1, 62);
    final elapsed = (today.difference(from).inDays + 1).clamp(1, 62);
    final left = budget - spent;
    String m(num v) => store.hideBalance ? rpHidden : rp(v);
    Widget row(String l, String v, {bool last = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: z.divider))),
          child: Row(children: [
            Expanded(child: Text(l, style: TextStyle(fontSize: 13, color: z.text2))),
            Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        );
    return DCard(
      title: tr('Anggaran bulan ini'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          DRing(
            value: pct,
            size: 110,
            stroke: 11,
            color: pct >= 0.9 ? z.warn : z.primary,
            center: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${(pct * 100).round()}%', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              Text(tr('terpakai'), style: TextStyle(fontSize: 11, color: z.muted2)),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(left >= 0 ? tr('Sisa') : tr('Lebih'), style: TextStyle(fontSize: 12, color: z.muted)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(m(left.abs()), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              ),
              Text(trf('dari {0}', [m(budget)]), style: TextStyle(fontSize: 12, color: z.muted2)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        row(tr('Terpakai'), m(spent)),
        row(tr('Rata-rata per hari'), m((spent / elapsed).round())),
        row(trf('Sisa per hari ({0} hari lagi)', [daysLeft]), m(left > 0 ? (left / daysLeft).round() : 0), last: true),
      ]),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.store, required this.onAll});

  final AppStore store;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final list = store.txns.take(8).toList();
    return DCard(
      title: tr('Transaksi terbaru'),
      link: tr('Lihat semua'),
      onLink: onAll,
      child: list.isEmpty
          ? EmptyState(icon: Icons.receipt_long_rounded, title: tr('Belum ada transaksi'), message: tr('Catat pengeluaran atau pemasukan pertamamu lewat tombol di atas.'))
          : Column(children: [
              for (var i = 0; i < list.length; i++)
                TxnRow(
                  category: store.category(list[i].cat),
                  title: list[i].name,
                  subtitle: '${dayLabel(list[i].at)}, ${timeLabel(list[i].at)} · ${store.walletName(list[i].wallet)}',
                  amountText: store.hideBalance ? rpHidden : rpSigned(list[i].amount),
                  isIncome: !list[i].isExpense,
                  showDivider: i < list.length - 1,
                ),
            ]),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return DCard(
      title: tr('Catat cepat'),
      leading: Icons.bolt_rounded,
      child: Wrap(spacing: 10, runSpacing: 10, children: [
        for (final q in store.quickItems) QuickChip(item: q, compact: true),
      ]),
    );
  }
}

class _Wallets extends StatelessWidget {
  const _Wallets({required this.store, required this.onMap});

  final AppStore store;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return DCard(
      title: tr('Sumber saldo'),
      link: tr('Peta saldo'),
      onLink: onMap,
      child: Column(children: [
        for (final w in store.wallets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              IconTile(icon: walletIcon(w.type), tone: walletTone(w.type), size: 36, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text(walletTypeLabel(w.type), style: TextStyle(fontSize: 11.5, color: z.muted2)),
                ]),
              ),
              Text(store.hideBalance ? rpHidden : rpNeg(store.walletBalance(w.id)),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
            ]),
          ),
      ]),
    );
  }
}

class _Where extends StatelessWidget {
  const _Where({required this.store, required this.onAll});

  final AppStore store;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final (from, to) = store.periodRange();
    final top = (store.spentByCategory(from, to).entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();
    final max = top.isEmpty ? 1 : top.first.value;
    return DCard(
      title: tr('Ke mana uangnya'),
      link: tr('Laporan'),
      onLink: onAll,
      child: top.isEmpty
          ? Text(tr('Belum ada pengeluaran bulan ini'), style: TextStyle(fontSize: 13, color: z.muted))
          : Column(children: [
              for (final e in top)
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Column(children: [
                    Row(children: [
                      Icon(store.category(e.key).icon, size: 18, color: z.chart(store.category(e.key).tone)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(store.category(e.key).label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                      Text(store.hideBalance ? rpHidden : rp(e.value), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: FillIn(
                        value: e.value / max,
                        builder: (_, v) => LinearProgressIndicator(value: v, minHeight: 4, backgroundColor: z.track, color: z.chart(store.category(e.key).tone)),
                      ),
                    ),
                  ]),
                ),
            ]),
    );
  }
}

class _Goals extends StatelessWidget {
  const _Goals({required this.store, required this.onAll});

  final AppStore store;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return DCard(
      title: tr('Target tabungan'),
      link: tr('Kelola'),
      onLink: onAll,
      child: store.goals.isEmpty
          ? Text(tr('Belum ada target'), style: TextStyle(fontSize: 13, color: z.muted))
          : Column(children: [
              for (final g in store.goals.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    IconTile(icon: GoalsPage.iconFor(g.name), tone: g.tone, size: 40, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(children: [
                        Row(children: [
                          Expanded(child: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                          Text('${(g.progress * 100).round()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: FillIn(value: g.progress, builder: (_, v) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: z.track, color: z.primary)),
                        ),
                      ]),
                    ),
                  ]),
                ),
            ]),
    );
  }
}

class _Today extends StatelessWidget {
  const _Today({required this.store, required this.onAll, required this.tint});

  final AppStore store;
  final VoidCallback onAll;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final todos = store.todayTodos;
    final done = todos.where((t) => t.done).length;
    final waiting = todos.length - done;
    final agenda = store.agendaOn(DateTime.now()).take(3).toList();
    return DCard(
      title: tr('Hari ini'),
      link: tr('Tugas'),
      onLink: onAll,
      color: tint,
      border: z.toneFg('amber').withValues(alpha: 0.28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          DRing(
            value: todos.isEmpty ? 0 : done / todos.length,
            size: 54,
            stroke: 6,
            color: z.primary,
            track: z.track,
            center: const SizedBox.shrink(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trf('{0} tugas menunggu', [waiting]), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              Text(trf('{0}/{1} selesai', [done, todos.length]), style: TextStyle(fontSize: 12.5, color: z.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        for (final a in agenda)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: z.divider))),
            child: Row(children: [
              Icon(a.reminder ? Icons.notifications_none_rounded : Icons.event_outlined, size: 17, color: z.accentText),
              const SizedBox(width: 10),
              Expanded(child: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              Text(timeLabel(a.at), style: TextStyle(fontSize: 12.5, color: z.muted)),
            ]),
          ),
      ]),
    );
  }
}
