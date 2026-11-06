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
        const ModeButton(),
        const Spacer(),
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
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: kQuickItems.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) => _QuickChip(item: kQuickItems[i]),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: z.hero,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: z.heroBorder),
      ),
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
          const SizedBox(width: 84, height: 48, child: CustomPaint(painter: _SparkPainter())),
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

class _SparkPainter extends CustomPainter {
  const _SparkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 96, sy = size.height / 56;
    const pts = [Offset(2, 48), Offset(18, 38), Offset(32, 42), Offset(48, 24), Offset(62, 30), Offset(78, 12), Offset(94, 6)];
    final p = Path()..moveTo(pts.first.dx * sx, pts.first.dy * sy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx * sx, o.dy * sy);
    }
    final paint = Paint()
      ..color = const Color(0xFF86EFAC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(p, paint);
    canvas.drawCircle(Offset(94 * sx, 6 * sy), 4, Paint()..color = const Color(0xFF86EFAC));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
            Text(label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: filled ? z.onPrimary : z.accentText)),
          ]),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.item});

  final QuickItem item;

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
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          child: Row(children: [
            CategoryTile(category: cat, size: 36),
            const SizedBox(width: 8),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(item.name), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(rpShort(item.amount), style: TextStyle(fontSize: 11, color: z.muted2)),
            ]),
          ]),
        ),
      ),
    );
  }
}
