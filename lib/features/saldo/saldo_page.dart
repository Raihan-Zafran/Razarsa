import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';
import 'graph_engine.dart';
import 'saldo_graph.dart';

/// Contoh sumber yang umum di Indonesia, dipilih dengan satu ketukan. Tanpa logo resmi: hanya ikon jenisnya.
const kWalletCatalog = <String, List<String>>{
  'bank': ['BRI', 'BCA', 'Mandiri', 'BNI', 'Sinarmas', 'BTN', 'BSI', 'CIMB Niaga', 'Permata', 'Danamon', 'Maybank', 'OCBC', 'Panin', 'Jago', 'SeaBank', 'Jenius', 'blu'],
  'ewallet': ['DANA', 'ShopeePay', 'GoPay', 'OVO', 'LinkAja', 'i.saku', 'Sakuku'],
  'cash': ['Tunai', 'Celengan'],
};

IconData walletIcon(String type) => switch (type) {
      'ewallet' => Icons.account_balance_wallet_rounded,
      'cash' => Icons.payments_rounded,
      _ => Icons.account_balance_rounded,
    };

String walletTone(String type) => switch (type) {
      'ewallet' => 'teal',
      'cash' => 'amber',
      _ => 'blue',
    };

String walletTypeLabel(String type) => switch (type) {
      'ewallet' => tr('E-wallet'),
      'cash' => tr('Tunai'),
      _ => tr('Bank'),
    };

/// "Saldo per sumber": graph bulat sumber → kategori → transaksi, lalu daftar sumber per jenis.
class SaldoPage extends StatefulWidget {
  const SaldoPage({super.key});

  @override
  State<SaldoPage> createState() => _SaldoPageState();
}

class _SaldoPageState extends State<SaldoPage> {
  int _q = 0;
  GNode? _sel;
  GraphData? _data;
  int _dataRev = -1, _dataQ = 0;
  String _dataDay = '';

  GraphData _graph(AppStore store) {
    final now = DateTime.now();
    final day = '${now.year}-${now.month}-${now.day}-${L.lang}';
    if (_data == null || _dataRev != store.revision || _dataQ != _q || _dataDay != day) {
      _data = buildGraphData(
        txns: store.txns,
        wallets: store.wallets,
        catLabel: (id) => store.category(id).label,
        now: now,
        quarterOffset: _q,
      );
      _dataRev = store.revision;
      _dataQ = _q;
      _dataDay = day;
    }
    return _data!;
  }

  String _period(GraphData d) {
    final a = DateTime(d.year, d.quarter * 3 + 1), b = DateTime(d.year, d.quarter * 3 + 3);
    return '${monthShort(a)}–${monthShort(b)} ${d.year}';
  }

  void _nav(GraphData d, int dir) {
    if ((dir < 0 && !d.canPrev) || (dir > 0 && !d.canNext)) return;
    setState(() {
      _q = math.min(0, _q + dir);
      _sel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final pad = MediaQuery.of(context).padding;
    final d = _graph(store);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final hidden = store.hideBalance;
    String money(int v) => hidden ? rpHidden : rpNeg(v);
    final total = store.balance;

    return Scaffold(
      backgroundColor: z.bg,
      body: ListView(
        padding: EdgeInsets.only(top: pad.top + 12, bottom: pad.bottom + 40),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PageTitle(tr('Saldo per sumber'), onBack: () => Navigator.of(context).pop()),
          ),
          const SizedBox(height: 10),
          Stack(children: [
            SaldoGraph(
              key: ValueKey(_q),
              data: d,
              reduceMotion: reduce,
              emptyText: tr('Belum ada transaksi di periode ini'),
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              onSelected: (n) => setState(() => _sel = n),
              onManageWallet: (w) => _manage(context, store, w),
              onAddWallet: () => _add(context, store),
            ),
            if (_sel != null)
              Positioned(left: 14, right: 14, bottom: 8, child: _InfoCard(node: _sel!, store: store, hidden: hidden)),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 2),
              Stack(alignment: Alignment.center, children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(_q < 0 ? trf('Arsip · {0}/200', [d.count]) : '${d.count}/200',
                      style: TextStyle(fontSize: 11.5, color: z.muted)),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(
                    tooltip: tr('Kuartal sebelumnya'),
                    onPressed: d.canPrev ? () => _nav(d, -1) : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 26),
                  ),
                  SizedBox(
                    width: 132,
                    child: Text(_period(d), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: tr('Kuartal berikutnya'),
                    onPressed: d.canNext ? () => _nav(d, 1) : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 26),
                  ),
                ]),
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 12, runSpacing: 4, children: [
                _Legend(color: walletTypeColor('bank'), size: 10, label: tr('Bank')),
                _Legend(color: walletTypeColor('ewallet'), size: 10, label: tr('E-wallet')),
                _Legend(color: walletTypeColor('cash'), size: 10, label: tr('Tunai')),
                _Legend(color: const Color(0xFFF6EFE6), size: 6, label: tr('Kategori')),
                _Legend(color: const Color(0xFFE6DCD0), size: 4, label: tr('Transaksi')),
                _Legend(color: const Color(0xFF8E7F70), size: 3, label: tr('Riwayat')),
              ]),
              const SizedBox(height: 22),
              Text(tr('Total Saldo'), style: TextStyle(fontSize: 14, color: z.muted)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(money(total), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: tr('Sumber saldo'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    TextSpan(text: '  ${store.wallets.length}/${AppStore.maxWallets}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: z.muted)),
                  ])),
                ),
                FilledButton.icon(
                  onPressed: () => _add(context, store),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(tr('Tambah'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                    backgroundColor: z.primary,
                    foregroundColor: z.onPrimary,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              ZCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  for (final type in kWalletTypes)
                    if (store.wallets.any((w) => w.type == type)) _Group(type: type, store: store, hidden: hidden, onTap: (w) => _manage(context, store, w)),
                ]),
              ),
              const SizedBox(height: 14),
              Text(
                tr('Tiap 3 bulan rasi direset dan diganti yang baru; rasi sebelumnya tetap bisa dibuka dengan panah, dan semua riwayat transaksi tetap tersimpan. Graph menampilkan maksimal 10 sumber, 50 kategori, dan 200 transaksi terbaru. Makin banyak titik, makin kecil ukurannya. Ketuk titik untuk detail, geser untuk memindahkan, tekan lama titik sumber untuk mengelola.'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.5, color: z.muted),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ---------- Tambah sumber ----------
  Future<void> _add(BuildContext context, AppStore store) async {
    if (store.wallets.length >= AppStore.maxWallets) {
      showZToast(context, trf('Maksimal {0} sumber', [AppStore.maxWallets]));
      return;
    }
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _AddWalletSheet(store: store),
    );
    if (name != null && context.mounted) showZToast(context, trf('{0} ditambahkan', [name]));
  }

  // ---------- Kelola sumber ----------
  Future<void> _manage(BuildContext context, AppStore store, Wallet w) async {
    final act = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => _DarkSheet(
        title: w.name,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _SheetRow(icon: Icons.tune_rounded, label: tr('Atur saldo'), onTap: () => Navigator.pop(c, 'balance')),
          _SheetRow(icon: Icons.edit_rounded, label: tr('Ubah nama'), onTap: () => Navigator.pop(c, 'rename')),
          _SheetRow(icon: Icons.delete_outline_rounded, label: tr('Hapus'), danger: true, onTap: () => Navigator.pop(c, 'delete')),
        ]),
      ),
    );
    if (act == null || !context.mounted) return;
    switch (act) {
      case 'balance':
        await _setBalance(context, store, w);
      case 'rename':
        await _rename(context, store, w);
      case 'delete':
        await _delete(context, store, w);
    }
  }

  Future<void> _setBalance(BuildContext context, AppStore store, Wallet w) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => _BalanceDialog(store: store, wallet: w));
    if (ok == true && context.mounted) showZToast(context, trf('Saldo {0} diperbarui', [w.name]));
  }

  Future<void> _rename(BuildContext context, AppStore store, Wallet w) =>
      showDialog<void>(context: context, builder: (c) => _RenameDialog(store: store, wallet: w));

  Future<void> _delete(BuildContext context, AppStore store, Wallet w) async {
    final to = store.walletReceiving(w.id);
    if (to == null) {
      showZToast(context, tr('Minimal harus ada satu sumber'));
      return;
    }
    final n = store.walletTxnCount(w.id);
    await confirmDelete(
      context,
      w.name,
      () => store.deleteWallet(w.id),
      title: trf('Hapus {0}?', [w.name]),
      message: trf('{0} transaksi dan saldonya dipindah ke {1}.', [n, to.name]),
    );
  }
}

/// Mengubah teks seperti "-1.250.000" jadi -1250000. null kalau tidak ada angka. Dibatasi 13 digit.
int? parseSignedAmount(String raw) {
  final t = raw.trim();
  final digits = t.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  final capped = digits.length > 13 ? digits.substring(0, 13) : digits;
  final v = int.parse(capped);
  return RegExp(r'^[-−–]').hasMatch(t) ? -v : v;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.size, required this.label});

  final Color color;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      // Garis tipis supaya titik krem tetap terlihat di tema terang.
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: z.muted2.withValues(alpha: 0.5), width: 0.6))),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 11.5, color: z.muted)),
    ]);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.node, required this.store, required this.hidden});

  final GNode node;
  final AppStore store;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    String money(int v) => hidden ? rpHidden : rpNeg(v);
    late IconData icon;
    late String title, line;
    var color = const Color(0xFFE6E9ED);
    switch (node.kind) {
      case GKind.wallet:
        final w = node.wallet!;
        icon = walletIcon(w.type);
        title = w.name;
        line = '${money(store.walletBalance(w.id))} · ${trf('{0} transaksi', [store.walletTxnCount(w.id)])}';
      case GKind.category:
        final sum = store.txns.where((t) => node.cat == '_more' ? false : t.cat == node.cat).fold<int>(0, (s, t) => s + t.amount);
        icon = node.cat == '_more' ? Icons.more_horiz_rounded : store.category(node.cat).icon;
        title = node.label;
        line = '${trf('{0} transaksi', [node.cnt])}${node.cat == '_more' ? '' : ' · ${hidden ? rpHidden : rpSigned(sum)}'}';
      case GKind.txn:
        final t = node.txn!;
        icon = store.category(t.cat).icon;
        title = t.name;
        line = '${dayLabel(t.at)}, ${timeLabel(t.at)} · ${hidden ? rpHidden : rpSigned(t.amount)} · ${store.walletName(t.wallet)}';
        color = t.amount > 0 ? const Color(0xFF6EDEA0) : const Color(0xFFB9BDBB);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE6221913),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 1),
            Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xB3FFFFFF))),
          ]),
        ),
      ]),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.type, required this.store, required this.hidden, required this.onTap});

  final String type;
  final AppStore store;
  final bool hidden;
  final void Function(Wallet) onTap;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final ws = store.wallets.where((w) => w.type == type).toList();
    final sum = ws.fold<int>(0, (s, w) => s + store.walletBalance(w.id));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: walletTypeColor(type), shape: BoxShape.circle, border: Border.all(color: z.border))),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${walletTypeLabel(type).toUpperCase()} · ${ws.length}',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: z.muted)),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(hidden ? rpHidden : rpNeg(sum), style: TextStyle(fontSize: 12.5, color: z.muted)),
            ),
          ),
        ]),
      ),
      for (var i = 0; i < ws.length; i++)
        InkWell(
          onTap: () => onTap(ws[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i < ws.length - 1 ? z.divider : Colors.transparent))),
            child: Row(children: [
              IconTile(icon: walletIcon(type), tone: walletTone(type), size: 40, radius: 9),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ws[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('${walletTypeLabel(type)} · ${trf('{0} transaksi', [store.walletTxnCount(ws[i].id)])}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: z.muted2)),
                ]),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(hidden ? rpHidden : rpNeg(store.walletBalance(ws[i].id)),
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Lembar bawah bernuansa cokelat tua, seperti latar graph.
class _DarkSheet extends StatelessWidget {
  const _DarkSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF241A14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            child,
          ]),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = danger ? const Color(0xFFFF8A7A) : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(children: [
          Icon(icon, size: 22, color: c),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c)),
        ]),
      ),
    );
  }
}

class _AddWalletSheet extends StatefulWidget {
  const _AddWalletSheet({required this.store});

  final AppStore store;

  @override
  State<_AddWalletSheet> createState() => _AddWalletSheetState();
}

class _AddWalletSheetState extends State<_AddWalletSheet> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  String? _preset;
  String _type = 'bank';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  String _typeOfPreset(String p) => kWalletCatalog.entries.firstWhere((e) => e.value.contains(p)).key;

  void _submit() {
    final raw = _name.text.trim().isNotEmpty ? _name.text : (_preset ?? '');
    final name = AppStore.cleanWalletName(raw);
    if (name.isEmpty) {
      setState(() => _error = tr('Pilih atau isi nama sumber dulu'));
      return;
    }
    final type = _name.text.trim().isEmpty && _preset != null ? _typeOfPreset(_preset!) : _type;
    final r = widget.store.addWallet(name: name, type: type, opening: parseSignedAmount(_balance.text) ?? 0);
    switch (r) {
      case WalletResult.ok:
        Navigator.pop(context, name);
      case WalletResult.duplicate:
        setState(() => _error = trf('{0} sudah ada', [name]));
      case WalletResult.full:
        setState(() => _error = trf('Maksimal {0} sumber', [AppStore.maxWallets]));
      case WalletResult.invalid:
        setState(() => _error = tr('Pilih atau isi nama sumber dulu'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final have = widget.store.wallets.map((w) => w.name.toLowerCase()).toSet();
    List<String> left(String t) => [for (final n in kWalletCatalog[t]!) if (!have.contains(n.toLowerCase())) n];
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final groups = [
      ('bank', tr('Bank utama')),
      ('ewallet', tr('E-wallet utama')),
      ('cash', tr('Tunai')),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: _DarkSheet(
          title: tr('Sumber saldo baru'),
          child: Flexible(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final (t, label) in groups)
                      if (left(t).isNotEmpty) ...[
                        _SheetLabel(label),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final n in left(t))
                            _DarkChip(
                              label: n,
                              selected: _preset == n && _name.text.trim().isEmpty,
                              onTap: () => setState(() {
                                _preset = _preset == n ? null : n;
                                _name.clear();
                                _error = null;
                              }),
                            ),
                        ]),
                      ],
                    _SheetLabel(tr('Atau buat sendiri, pilih jenisnya')),
                    Wrap(spacing: 8, children: [
                      for (final t in kWalletTypes) _DarkChip(label: walletTypeLabel(t), selected: _type == t, onTap: () => setState(() => _type = t)),
                    ]),
                    const SizedBox(height: 12),
                    _DarkField(
                      controller: _name,
                      hint: tr('Nama sendiri (kosongkan kalau memilih di atas)'),
                      maxLength: AppStore.maxWalletName,
                      onChanged: (v) => setState(() {
                        if (v.trim().isNotEmpty) _preset = null;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    _DarkField(
                      controller: _balance,
                      hint: trf('Saldo sekarang ({0}), boleh minus', [currencySymbol]),
                      keyboard: const TextInputType.numberWithOptions(signed: true),
                      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\-.,]')), LengthLimitingTextInputFormatter(18)],
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ]),
                ),
              ),
              // Tombol dan pesan selalu terlihat, tidak ikut tergulir.
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Color(0xFFFF8A7A), fontSize: 13))),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFAF4EB), foregroundColor: const Color(0xFF1A130F)),
                  child: Text(tr('Tambah'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Color(0xB3FFFFFF))),
      );
}

class _DarkChip extends StatelessWidget {
  const _DarkChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFAF4EB) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? const Color(0xFFFAF4EB) : Colors.white.withValues(alpha: 0.14)),
            ),
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF1A130F) : Colors.white)),
          ),
        ),
      );
}

class _DarkField extends StatelessWidget {
  const _DarkField({required this.controller, required this.hint, this.keyboard, this.formatters, this.maxLength, this.onChanged});

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final int? maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: formatters,
        maxLength: maxLength,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0x80FFFFFF), fontSize: 13.5),
          counterText: '',
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFFAF4EB), width: 1.5)),
        ),
      );
}

/// Dialog atur saldo. Pengendali teks dimiliki dialog ini supaya dibuang bersamaan dengan animasi tutupnya.
class _BalanceDialog extends StatefulWidget {
  const _BalanceDialog({required this.store, required this.wallet});

  final AppStore store;
  final Wallet wallet;

  @override
  State<_BalanceDialog> createState() => _BalanceDialogState();
}

class _BalanceDialogState extends State<_BalanceDialog> {
  late final _ctl = TextEditingController(text: '${widget.store.walletBalance(widget.wallet.id)}');
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseSignedAmount(_ctl.text);
    if (v == null) {
      setState(() => _error = tr('Isi saldo dulu'));
      return;
    }
    if (!widget.store.setWalletBalance(widget.wallet.id, v)) {
      setState(() => _error = trf('Maksimal {0}', [rp(AppStore.maxAmount)]));
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wallet;
    return AlertDialog(
      title: Text(trf('Atur saldo {0}', [w.name])),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trf('Samakan dengan saldo sebenarnya di {0}.', [w.name]), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        TextField(
          controller: _ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\-.,]')), LengthLimitingTextInputFormatter(18)],
          decoration: InputDecoration(prefixText: '$currencySymbol ', labelText: tr('Saldo sekarang, boleh minus'), errorText: _error),
          onChanged: (_) => setState(() => _error = null),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Batal'))),
        TextButton(onPressed: _save, child: Text(tr('Simpan'))),
      ],
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.store, required this.wallet});

  final AppStore store;
  final Wallet wallet;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _ctl = TextEditingController(text: widget.wallet.name);
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _save() {
    final r = widget.store.renameWallet(widget.wallet.id, _ctl.text);
    switch (r) {
      case WalletResult.ok:
        Navigator.pop(context);
      case WalletResult.duplicate:
        setState(() => _error = trf('{0} sudah ada', [AppStore.cleanWalletName(_ctl.text)]));
      default:
        setState(() => _error = tr('Isi nama sumber dulu'));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(tr('Ubah nama')),
        content: TextField(
          controller: _ctl,
          autofocus: true,
          maxLength: AppStore.maxWalletName,
          decoration: InputDecoration(hintText: tr('Nama sumber'), counterText: '', errorText: _error),
          onChanged: (_) => setState(() => _error = null),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Batal'))),
          TextButton(onPressed: _save, child: Text(tr('Simpan'))),
        ],
      );
}
