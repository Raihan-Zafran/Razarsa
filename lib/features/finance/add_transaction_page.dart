import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../saldo/saldo_page.dart' show walletIcon;
import '../../core/i18n.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key, required this.income, this.edit});

  final bool income;

  /// Kalau diisi: mengubah transaksi ini, bukan membuat yang baru.
  final Txn? edit;

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  late bool _income = widget.edit != null ? !widget.edit!.isExpense : widget.income;
  late final _amount = TextEditingController(text: widget.edit == null ? '' : dots(widget.edit!.amount.abs()));
  late final _note = TextEditingController();
  final _newCat = TextEditingController();
  late String? _cat = widget.edit?.cat;
  bool _expanded = false;
  bool _showNewCat = false;
  late DateTime _date = widget.edit?.at ?? DateTime.now();
  late String? _wallet = widget.edit?.wallet;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      // Nama yang sama dengan nama kategori berarti catatan kosong.
      final cat = StoreScope.read(context).category(e.cat).label;
      _note.text = e.name == cat ? '' : e.name;
    }
  }

  int get _value => int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
  bool get _canSave => _value > 0 && _cat != null;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _newCat.dispose();
    super.dispose();
  }

  void _save(AppStore store) {
    if (!_canSave) return;
    final now = DateTime.now();
    final edit = widget.edit;
    final clock = edit?.at ?? now;
    final at = DateTime(_date.year, _date.month, _date.day, clock.hour, clock.minute, clock.second);
    final note = _note.text.trim();
    if (edit != null) {
      final ok = store.updateTxn(
        edit.id,
        name: note.isEmpty ? store.category(_cat!).label : note,
        cat: _cat!,
        amount: _income ? _value : -_value,
        at: at,
        wallet: _wallet ?? edit.wallet,
      );
      showZToast(context, ok ? tr('Transaksi diubah') : tr('Transaksi tidak ditemukan'));
      Navigator.of(context).pop();
      return;
    }
    final t = store.addTxn(
      name: note.isEmpty ? store.category(_cat!).label : note,
      cat: _cat!,
      amount: _income ? _value : -_value,
      at: at,
      wallet: _wallet ?? store.defaultWallet.id,
    );
    showZToast(
      context,
      trf('{0} {1} dicatat di {2}', [_income ? tr('Pemasukan') : tr('Pengeluaran'), rp(_value), store.walletName(t.wallet)]),
      actionLabel: tr('Batalkan'),
      onAction: () => store.removeTxn(t.id),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final ranked = store.rankedCategories(income: _income);
    var shown = ranked;
    if (!_income && !_expanded) {
      shown = ranked.take(7).toList();
      if (_cat != null && !shown.any((c) => c.id == _cat)) shown[6] = store.category(_cat!);
    }
    final today = dayOnly(DateTime.now());
    final picked = dayOnly(_date);
    final isToday = picked == today;
    final isYesterday = picked == today.subtract(const Duration(days: 1));

    return Scaffold(
      backgroundColor: z.bg,
      body: PageScroll(withDock: false, children: [
        PageTitle(widget.edit != null ? tr('Ubah transaksi') : tr('Tambah Transaksi'), onBack: () => Navigator.of(context).pop(), backIcon: Icons.close_rounded),
        const SizedBox(height: 6),
        Segmented<bool>(
          items: [(false, tr('Pengeluaran')), (true, tr('Pemasukan'))],
          value: _income,
          onChanged: (v) => setState(() {
            _income = v;
            _cat = null;
            _showNewCat = false;
          }),
        ),
        const SizedBox(height: 16),
        ZCard(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Jumlah'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: z.muted)),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(currencySymbol, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: z.muted, letterSpacing: -0.8)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ThousandsFormatter()],
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: z.text, letterSpacing: -0.8),
                  decoration: InputDecoration(
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    hintText: '0',
                    hintStyle: TextStyle(color: z.muted.withValues(alpha: 0.45)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 22),
        SectionTitle(tr('Kategori'),
            trailing: Text(
              _income ? tr('Sumber pemasukan') : (_expanded ? tr('Semua kategori') : tr('Paling sering dipakai')),
              style: TextStyle(fontSize: 12, color: z.muted2),
            )),
        const SizedBox(height: 10),
        GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: scaledHeight(context, 88)),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final c in shown)
              _CatButton(
                label: c.label,
                selected: _cat == c.id,
                tile: CategoryTile(category: c, size: 36),
                onTap: () => setState(() => _cat = c.id),
              ),
            if (!_income && !_expanded)
              _CatButton(
                label: tr('Semua'),
                selected: false,
                tile: _DashedTile(icon: Icons.apps_rounded),
                onTap: () => setState(() => _expanded = true),
              ),
            if (_income || _expanded)
              _CatButton(
                label: tr('Baru'),
                selected: _showNewCat,
                tile: _DashedTile(icon: Icons.add_rounded),
                onTap: () => setState(() => _showNewCat = !_showNewCat),
              ),
            if (!_income && _expanded)
              _CatButton(
                label: tr('Ringkas'),
                selected: false,
                tile: _DashedTile(icon: Icons.expand_less_rounded),
                onTap: () => setState(() {
                  _expanded = false;
                  _showNewCat = false;
                }),
              ),
          ],
        ),
        if (_showNewCat) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _newCat,
                maxLength: 16,
                onChanged: (_) => setState(() {}),
                decoration: _inputDeco(z, tr('Nama kategori, mis. Hobi')).copyWith(counterText: ''),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _newCat.text.trim().isEmpty
                  ? null
                  : () {
                      final before = store.customCats.length;
                      final c = store.addCustomCategory(_newCat.text, income: _income);
                      if (store.customCats.length == before) {
                        // Sudah ada (bawaan atau buatan sendiri): dipakai, tidak dibuat kembar.
                        showZToast(context, trf('Kategori "{0}" sudah ada, langsung dipilih', [c.label]));
                      }
                      setState(() {
                        _cat = c.id;
                        _newCat.clear();
                        _showNewCat = false;
                      });
                    },
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Text(tr('Tambah'), style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ],
        const SizedBox(height: 22),
        _WalletPicker(
          label: _income ? tr('Masuk ke') : tr('Bayar dari'),
          store: store,
          selected: _wallet ?? store.defaultWallet.id,
          onChanged: (id) => setState(() => _wallet = id),
        ),
        const SizedBox(height: 14),
        SectionTitle(tr('Tanggal')),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ZChip(label: tr('Hari ini'), selected: isToday, onTap: () => setState(() => _date = DateTime.now())),
          ZChip(
            label: tr('Kemarin'),
            selected: isYesterday,
            onTap: () => setState(() => _date = DateTime.now().subtract(const Duration(days: 1))),
          ),
          ZChip(
            label: !isToday && !isYesterday ? DateFormat('d MMM y', 'id_ID').format(_date) : tr('Pilih tanggal'),
            selected: !isToday && !isYesterday,
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
        ]),
        const SizedBox(height: 18),
        Text.rich(TextSpan(children: [
          TextSpan(text: tr('Catatan '), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          TextSpan(text: tr('(opsional)'), style: TextStyle(fontSize: 14, color: z.muted2)),
        ])),
        const SizedBox(height: 8),
        TextField(controller: _note, maxLength: 40, decoration: _inputDeco(z, tr('Contoh: makan siang')).copyWith(counterText: '')),
        const SizedBox(height: 18),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: _canSave ? () => _save(store) : null,
            style: FilledButton.styleFrom(
              backgroundColor: z.primary,
              foregroundColor: z.onPrimary,
              disabledBackgroundColor: z['disabledBg'],
              disabledForegroundColor: z['disabledFg'],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(widget.edit != null ? tr('Simpan perubahan') : (_canSave ? trf('Simpan {0}', [rp(_value)]) : tr('Simpan Transaksi')),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  InputDecoration _inputDeco(ZColors z, String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: z.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: z.chipBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: z.primary, width: 2)),
      );
}

/// Pilihan sumber saldo (bank, e-wallet, tunai) beserta saldonya, yang tinggal diketuk.
class _WalletPicker extends StatelessWidget {
  const _WalletPicker({required this.label, required this.store, required this.selected, required this.onChanged});

  final String label;
  final AppStore store;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final cur = store.walletById(selected) ?? store.defaultWallet;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle(
        label,
        trailing: Text(
          store.hideBalance ? rpHidden : trf('Saldo {0}', [rpNeg(store.walletBalance(cur.id))]),
          style: TextStyle(fontSize: 12, color: z.muted2),
        ),
      ),
      const SizedBox(height: 2),
      // Satu baris yang bisa digeser, supaya berapa pun jumlah sumbernya tetap rapi.
      SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: store.wallets.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final w = store.wallets[i];
            return ZChip(label: w.name, icon: walletIcon(w.type), selected: w.id == cur.id, onTap: () => onChanged(w.id));
          },
        ),
      ),
    ]);
  }
}

class _CatButton extends StatelessWidget {
  const _CatButton({required this.label, required this.selected, required this.tile, required this.onTap});

  final String label;
  final bool selected;
  final Widget tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: z.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? z.primary : Colors.transparent, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            tile,
            const SizedBox(height: 8),
            Text(label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.15, color: z.text2)),
          ]),
        ),
      ),
    );
  }
}

class _DashedTile extends StatelessWidget {
  const _DashedTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: z.track, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 19, color: z.text2),
    );
  }
}

/// Menambahkan titik ribuan saat mengetik: 25000 -> 25.000
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
    if (digits.length > 12) digits = digits.substring(0, 12);
    final text = digits.isEmpty ? '' : dots(int.parse(digits));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
