import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import 'add_transaction_page.dart';

enum TxnFilter { all, income, expense }

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  TxnFilter _filter = TxnFilter.all;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final shown = store.txns.where((t) {
      switch (_filter) {
        case TxnFilter.income:
          return !t.isExpense;
        case TxnFilter.expense:
          return t.isExpense;
        case TxnFilter.all:
          return true;
      }
    }).toList();

    // Kelompokkan per hari (urutan sudah terbaru dulu).
    final groups = <String, List<Txn>>{};
    for (final t in shown) {
      groups.putIfAbsent(dayLabel(t.at), () => []).add(t);
    }

    return PageScroll(children: [
      PageTitle('Transaksi', actions: [
        RoundIconButton(
          icon: Icons.add_rounded,
          tooltip: 'Tambah transaksi',
          onTap: () => pushPage(context, const AddTransactionPage(income: false)),
        ),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        ZChip(label: 'Semua', selected: _filter == TxnFilter.all, onTap: () => setState(() => _filter = TxnFilter.all)),
        ZChip(label: 'Pemasukan', selected: _filter == TxnFilter.income, onTap: () => setState(() => _filter = TxnFilter.income)),
        ZChip(label: 'Pengeluaran', selected: _filter == TxnFilter.expense, onTap: () => setState(() => _filter = TxnFilter.expense)),
      ]),
      const SizedBox(height: 8),
      if (groups.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 24),
          child: EmptyState(title: 'Belum ada transaksi', message: 'Transaksi yang kamu catat akan muncul di sini.'),
        ),
      for (final e in groups.entries) ...[
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(e.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: z.muted)),
        ),
        ZCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Column(children: [
            for (var i = 0; i < e.value.length; i++)
              TxnRow(
                category: store.category(e.value[i].cat),
                title: e.value[i].name,
                subtitle: '${store.category(e.value[i].cat).label} · ${timeLabel(e.value[i].at)}',
                amountText: rpSigned(e.value[i].amount),
                isIncome: !e.value[i].isExpense,
                showDivider: i < e.value.length - 1,
                onLongPress: () => _confirmDelete(context, store, e.value[i]),
              ),
          ]),
        ),
      ],
      if (groups.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text('Tekan lama transaksi untuk menghapus.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: z.muted2)),
        ),
    ]);
  }

  Future<void> _confirmDelete(BuildContext context, AppStore store, Txn t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: Text('${t.name} (${rpSigned(t.amount)}) akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) store.removeTxn(t.id);
  }
}
