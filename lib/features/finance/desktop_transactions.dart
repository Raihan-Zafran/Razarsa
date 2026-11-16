import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../shell/desktop_page.dart';
import '../../widgets/common.dart';
import '../saldo/saldo_page.dart' show walletIcon;
import '../settings/settings_page.dart' show exportCsvFile;
import 'add_transaction_page.dart';

enum _Kind { all, income, expense }

/// Transaksi untuk jendela lebar: daftar bertabel (cari, saring jenis dan sumber) dan panel rincian di kanan.
class DesktopTransactions extends StatefulWidget {
  const DesktopTransactions({super.key});

  @override
  State<DesktopTransactions> createState() => _DesktopTransactionsState();
}

class _DesktopTransactionsState extends State<DesktopTransactions> {
  _Kind _kind = _Kind.all;
  String _wallet = ''; // kosong = semua sumber
  String _q = '';
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final q = _q.trim().toLowerCase();
    final list = store.txns.where((t) {
      if (_kind == _Kind.income && t.isExpense) return false;
      if (_kind == _Kind.expense && !t.isExpense) return false;
      if (_wallet.isNotEmpty && t.wallet != _wallet) return false;
      if (q.isNotEmpty && !t.name.toLowerCase().contains(q) && !store.category(t.cat).label.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    Txn? selected;
    for (final t in store.txns) {
      if (t.id == _sel) selected = t;
    }
    final groups = <String, List<Txn>>{};
    for (final t in list) {
      groups.putIfAbsent(_dateKey(t.at), () => []).add(t);
    }

    final table = DCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Filters(
          store: store,
          kind: _kind,
          wallet: _wallet,
          onKind: (k) => setState(() => _kind = k),
          onWallet: (w) => setState(() => _wallet = w),
          onQuery: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 14),
        _HeadRow(z: z),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: EmptyState(icon: Icons.receipt_long_rounded, title: tr('Belum ada transaksi'), message: tr('Transaksi yang kamu catat akan muncul di sini.')),
          ),
        for (final e in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
            child: Text(e.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: z.text2)),
          ),
          for (final t in e.value)
            _Row(
              txn: t,
              store: store,
              selected: t.id == _sel,
              onTap: () => setState(() => _sel = t.id == _sel ? null : t.id),
            ),
        ],
      ]),
    );

    return DesktopPage(
      title: tr('Transaksi'),
      subtitle: trf('{0} transaksi tercatat', [store.txns.length]),
      action: FilledButton.icon(
        onPressed: () => pushPage(context, const AddTransactionPage(income: false)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(tr('Tambah transaksi'), style: const TextStyle(fontWeight: FontWeight.w800)),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
      ),
      children: [
        LayoutBuilder(builder: (context, box) {
          final side = box.maxWidth >= 900;
          final detail = _Detail(txn: selected, store: store, onGone: () => setState(() => _sel = null));
          if (!side) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [detail, const SizedBox(height: 20), table]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 7, child: table),
            const SizedBox(width: 20),
            Expanded(flex: 3, child: detail),
          ]);
        }),
      ],
    );
  }

  static String _dateKey(DateTime d) => DateFormat(L.en ? 'EEEE, MMMM d, y' : 'EEEE, d MMMM y', L.dateLocale).format(d);
}

class _Filters extends StatelessWidget {
  const _Filters({required this.store, required this.kind, required this.wallet, required this.onKind, required this.onWallet, required this.onQuery});

  final AppStore store;
  final _Kind kind;
  final String wallet;
  final ValueChanged<_Kind> onKind;
  final ValueChanged<String> onWallet;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final search = TextField(
      onChanged: onQuery,
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
    );
    final seg = Segmented<_Kind>(
      height: 44,
      items: [(_Kind.all, tr('Semua')), (_Kind.income, tr('Masuk')), (_Kind.expense, tr('Keluar'))],
      value: kind,
      onChanged: onKind,
    );
    final drop = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: z.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: z.chipBorder)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: wallet,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(Icons.expand_more_rounded, color: z.muted),
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: z.text, fontFamily: kFont),
          items: [
            DropdownMenuItem(value: '', child: Text(tr('Semua sumber'))),
            for (final w in store.wallets) DropdownMenuItem(value: w.id, child: Text(w.name)),
          ],
          onChanged: (v) => onWallet(v ?? ''),
        ),
      ),
    );
    final csv = OutlinedButton.icon(
      onPressed: () => exportCsvFile(context, store),
      icon: const Icon(Icons.download_rounded, size: 19),
      label: Text(tr('CSV'), style: const TextStyle(fontWeight: FontWeight.w800)),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 640) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          search,
          const SizedBox(height: 10),
          seg,
          const SizedBox(height: 10),
          Row(children: [Expanded(child: drop), const SizedBox(width: 10), csv]),
        ]);
      }
      return Row(children: [
        Expanded(child: search),
        const SizedBox(width: 10),
        SizedBox(width: 240, child: seg),
        const SizedBox(width: 10),
        drop,
        const SizedBox(width: 10),
        csv,
      ]);
    });
  }
}

class _HeadRow extends StatelessWidget {
  const _HeadRow({required this.z});

  final ZColors z;

  @override
  Widget build(BuildContext context) {
    final st = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: z.muted2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: Row(children: [
        const SizedBox(width: 56),
        Expanded(flex: 5, child: Text(tr('Transaksi'), style: st)),
        Expanded(flex: 3, child: Text(tr('Sumber'), style: st)),
        Expanded(flex: 2, child: Text(tr('Jam'), style: st)),
        Expanded(flex: 3, child: Text(tr('Jumlah'), textAlign: TextAlign.end, style: st)),
      ]),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.txn, required this.store, required this.selected, required this.onTap});

  final Txn txn;
  final AppStore store;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final t = widget.txn;
    final cat = widget.store.category(t.cat);
    final bg = widget.selected ? z.toneBg('green') : (_hover ? z.track : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: true,
        selected: widget.selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              CategoryTile(category: cat, size: 40),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(cat.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: z.muted2)),
                ]),
              ),
              Expanded(flex: 3, child: Text(widget.store.walletName(t.wallet), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: z.text2))),
              Expanded(flex: 2, child: Text(timeLabel(t.at), style: TextStyle(fontSize: 13, color: z.muted))),
              Expanded(
                flex: 3,
                child: Text(
                  widget.store.hideBalance ? rpHidden : rpSigned(t.amount),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.isExpense ? z.text : z.accentText, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.txn, required this.store, required this.onGone});

  final Txn? txn;
  final AppStore store;
  final VoidCallback onGone;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final t = txn;
    if (t == null) {
      return DCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(children: [
          Icon(Icons.receipt_long_outlined, size: 44, color: z.text2),
          const SizedBox(height: 14),
          Text(tr('Pilih transaksi'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(tr('Rinciannya muncul di sini, lengkap dengan tombol ubah dan hapus.'), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: z.muted, height: 1.4)),
        ]),
      );
    }
    final cat = store.category(t.cat);
    Widget line(String l, Widget v) => Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: z.divider))),
          child: Row(children: [
            Text(l, style: TextStyle(fontSize: 13, color: z.muted)),
            const Spacer(),
            v,
          ]),
        );
    final val = const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700);
    return DCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CategoryTile(category: cat, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text(cat.label, style: TextStyle(fontSize: 12.5, color: z.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Text(store.hideBalance ? rpHidden : rpSigned(t.amount),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: t.isExpense ? z.text : z.accentText)),
        const SizedBox(height: 8),
        line(tr('Tanggal'), Text(_DesktopTransactionsState._dateKey(t.at), style: val)),
        line(tr('Jam'), Text(timeLabel(t.at), style: val)),
        line(tr('Sumber'), Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(walletIcon(store.walletById(t.wallet)?.type ?? 'cash'), size: 16, color: z.text2),
          const SizedBox(width: 6),
          Text(store.walletName(t.wallet), style: val),
        ])),
        line(tr('Jenis'), Text(t.isExpense ? tr('Pengeluaran') : tr('Pemasukan'), style: val)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => pushPage(context, AddTransactionPage(income: !t.isExpense, edit: t)),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(tr('Ubah'), style: const TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => confirmDelete(
                context,
                t.name,
                () {
                  store.removeTxn(t.id);
                  onGone();
                },
                title: tr('Hapus transaksi?'),
                message: trf('{0} ({1}) akan dihapus.', [t.name, rpSigned(t.amount)]),
              ),
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: z.warn),
              label: Text(tr('Hapus'), style: TextStyle(fontWeight: FontWeight.w800, color: z.warn)),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), side: BorderSide(color: z.warn.withValues(alpha: 0.5))),
            ),
          ),
        ]),
      ]),
    );
  }
}
