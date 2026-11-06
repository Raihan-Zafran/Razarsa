import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key, required this.income});

  final bool income;

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  late bool _income = widget.income;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _newCat = TextEditingController();
  String? _cat;
  bool _expanded = false;
  bool _showNewCat = false;
  DateTime _date = DateTime.now();

  int get _value => int.tryParse(_amount.text.replaceAll('.', '')) ?? 0;
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
    final at = DateTime(_date.year, _date.month, _date.day, now.hour, now.minute, now.second);
    final note = _note.text.trim();
    store.addTxn(
      name: note.isEmpty ? store.category(_cat!).label : note,
      cat: _cat!,
      amount: _income ? _value : -_value,
      at: at,
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
        PageTitle('Tambah Transaksi', onBack: () => Navigator.of(context).pop(), backIcon: Icons.close_rounded),
        const SizedBox(height: 14),
        Segmented<bool>(
          items: const [(false, 'Pengeluaran'), (true, 'Pemasukan')],
          value: _income,
          onChanged: (v) => setState(() {
            _income = v;
            _cat = null;
            _showNewCat = false;
          }),
        ),
        const SizedBox(height: 16),
        ZCard(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Jumlah', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: z.muted)),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text('Rp', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: z.muted)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ThousandsFormatter()],
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: z.text, letterSpacing: -0.8),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: TextStyle(color: z.muted.withValues(alpha: 0.45)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        SectionTitle('Kategori',
            trailing: Text(
              _income ? 'Sumber pemasukan' : (_expanded ? 'Semua kategori' : 'Paling sering dipakai'),
              style: TextStyle(fontSize: 12, color: z.muted2),
            )),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.9,
          children: [
            for (final c in shown)
              _CatButton(
                label: c.label,
                selected: _cat == c.id,
                tile: CategoryTile(category: c, size: 38),
                onTap: () => setState(() => _cat = c.id),
              ),
            if (!_income && !_expanded)
              _CatButton(
                label: 'Semua',
                selected: false,
                tile: _DashedTile(icon: Icons.grid_view_rounded),
                onTap: () => setState(() => _expanded = true),
              ),
            if (_income || _expanded)
              _CatButton(
                label: 'Baru',
                selected: _showNewCat,
                tile: _DashedTile(icon: Icons.add_rounded),
                onTap: () => setState(() => _showNewCat = !_showNewCat),
              ),
            if (!_income && _expanded)
              _CatButton(
                label: 'Ringkas',
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
                decoration: _inputDeco(z, 'Nama kategori, mis. Hobi').copyWith(counterText: ''),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _newCat.text.trim().isEmpty
                  ? null
                  : () {
                      final c = store.addCustomCategory(_newCat.text, income: _income);
                      setState(() {
                        _cat = c.id;
                        _newCat.clear();
                        _showNewCat = false;
                      });
                    },
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ],
        const SizedBox(height: 18),
        const SectionTitle('Tanggal'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ZChip(label: 'Hari ini', selected: isToday, onTap: () => setState(() => _date = DateTime.now())),
          ZChip(
            label: 'Kemarin',
            selected: isYesterday,
            onTap: () => setState(() => _date = DateTime.now().subtract(const Duration(days: 1))),
          ),
          ZChip(
            label: !isToday && !isYesterday ? DateFormat('d MMM y', 'id_ID').format(_date) : 'Pilih tanggal',
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
          const TextSpan(text: 'Catatan ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          TextSpan(text: '(opsional)', style: TextStyle(fontSize: 14, color: z.muted2)),
        ])),
        const SizedBox(height: 8),
        TextField(controller: _note, maxLength: 40, decoration: _inputDeco(z, 'Contoh: makan siang').copyWith(counterText: '')),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(_canSave ? 'Simpan ${rp(_value)}' : 'Simpan Transaksi',
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
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: z.chipBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: z.primary, width: 2)),
      );
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? z.primary : z.cardBorder, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            tile,
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: z.text2)),
            ),
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
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: z.chipBorder, width: 1.5),
      ),
      child: Icon(icon, size: 19, color: z.muted),
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
