import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../../shell/layout.dart';
import '../saldo/saldo_page.dart' show walletIcon;
import 'add_transaction_page.dart';
import 'desktop_transactions.dart';
import '../../core/i18n.dart';

enum TxnFilter { all, income, expense }

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  TxnFilter _filter = TxnFilter.all;
  String _wallet = ''; // kosong = semua sumber
  String _q = '';

  @override
  Widget build(BuildContext context) {
    if (isWide(context)) return const DesktopTransactions();
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final q = _q.trim().toLowerCase();
    final shown = store.txns.where((t) {
      if (_wallet.isNotEmpty && t.wallet != _wallet) return false;
      if (q.isNotEmpty && !t.name.toLowerCase().contains(q) && !store.category(t.cat).label.toLowerCase().contains(q)) return false;
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
      PageTitle(tr('Transaksi'), actions: [
        RoundIconButton(
          icon: Icons.add_rounded,
          tooltip: tr('Tambah transaksi'),
          onTap: () => pushPage(context, const AddTransactionPage(income: false)),
        ),
      ]),
      const SizedBox(height: 12),
      TextField(
        onChanged: (v) => setState(() => _q = v),
        decoration: InputDecoration(
          hintText: tr('Cari nama atau kategori'),
          isDense: true,
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: z.muted2),
          filled: true,
          fillColor: z.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: z.chipBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: z.primary, width: 2)),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        ZChip(label: tr('Semua'), selected: _filter == TxnFilter.all, onTap: () => setState(() => _filter = TxnFilter.all)),
        ZChip(label: tr('Pemasukan'), selected: _filter == TxnFilter.income, onTap: () => setState(() => _filter = TxnFilter.income)),
        ZChip(label: tr('Pengeluaran'), selected: _filter == TxnFilter.expense, onTap: () => setState(() => _filter = TxnFilter.expense)),
      ]),
      if (store.wallets.length > 1)
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            ZChip(label: tr('Semua sumber'), selected: _wallet.isEmpty, onTap: () => setState(() => _wallet = '')),
            for (final w in store.wallets) ...[
              const SizedBox(width: 8),
              ZChip(label: w.name, icon: walletIcon(w.type), selected: _wallet == w.id, onTap: () => setState(() => _wallet = w.id)),
            ],
          ]),
        ),
      const SizedBox(height: 8),
      if (groups.isEmpty)
        Padding(
          padding: EdgeInsets.only(top: 24),
          child: EmptyState(icon: Icons.receipt_long_rounded, title: tr('Belum ada transaksi'), message: tr('Transaksi yang kamu catat akan muncul di sini.')),
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
                subtitle: '${store.category(e.value[i].cat).label} · ${timeLabel(e.value[i].at)}${store.walletName(e.value[i].wallet).isEmpty ? '' : ' · ${store.walletName(e.value[i].wallet)}'}',
                amountText: rpSigned(e.value[i].amount),
                isIncome: !e.value[i].isExpense,
                showDivider: i < e.value.length - 1,
                onTap: () => _options(context, store, e.value[i]),
                onLongPress: () => _confirmDelete(context, store, e.value[i]),
              ),
          ]),
        ),
      ],
      if (groups.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(tr('Ketuk transaksi untuk mengubah, tekan lama untuk menghapus.'),
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: z.muted2)),
        ),
    ]);
  }

  /// Ketuk: ubah atau hapus transaksi.
  Future<void> _options(BuildContext context, AppStore store, Txn t) async {
    final act = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(tr('Ubah transaksi'), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(c, 'edit'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: Text(tr('Hapus'), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(c, 'delete'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (act == 'edit') {
      await pushPage(context, AddTransactionPage(income: !t.isExpense, edit: t));
    } else if (act == 'delete') {
      await _confirmDelete(context, store, t);
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppStore store, Txn t) => confirmDelete(
        context,
        t.name,
        () => store.removeTxn(t.id),
        title: tr('Hapus transaksi?'),
        message: trf('{0} ({1}) akan dihapus.', [t.name, rpSigned(t.amount)]),
      );
}
