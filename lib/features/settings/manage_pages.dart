import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';

const kAppVersion = '1.2.0';

InputDecoration _input(BuildContext context, String hint, {String? prefix}) {
  final z = ZColors.of(context);
  return InputDecoration(
    hintText: hint,
    prefixText: prefix,
    filled: true,
    fillColor: z.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: z.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: z.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: z.primary, width: 2)),
  );
}

Widget _label(BuildContext context, String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ZColors.of(context).muted)),
    );

Widget _saveButton(BuildContext context, VoidCallback onTap) {
  final z = ZColors.of(context);
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: z.primary,
        foregroundColor: z.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(tr('Simpan'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
    ),
  );
}

/// Pilihan kategori berbentuk chip.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.income, required this.value, required this.onPick});

  final bool income;
  final String value;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final c in store.rankedCategories(income: income)) ZChip(label: c.label, selected: c.id == value, onTap: () => onPick(c.id)),
    ]);
  }
}

int _digits(String s) => int.tryParse(s.replaceAll(RegExp(r'\D'), '')) ?? 0;

// ============================================================
// Catat Cepat
// ============================================================
class QuickItemsPage extends StatelessWidget {
  const QuickItemsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    return Scaffold(
      backgroundColor: z.bg,
      body: PageScroll(withDock: false, children: [
        PageTitle(tr('Catat Cepat'), onBack: () => Navigator.of(context).pop(), actions: [
          IconButton(tooltip: tr('Tambah tombol'), onPressed: () => _edit(context), icon: Icon(Icons.add_circle_rounded, color: z.primary, size: 30)),
        ]),
        const SizedBox(height: 6),
        Text(tr('Tombol di Beranda untuk mencatat pengeluaran rutin sekali tap. Ketuk untuk mengubah.'),
            style: TextStyle(fontSize: 13, color: z.muted, height: 1.45)),
        const SizedBox(height: 14),
        if (store.quickItems.isEmpty)
          ZCard(child: EmptyState(title: tr('Belum ada tombol'), message: tr('Tekan + untuk menambah tombol Catat Cepat.')))
        else
          ZCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < store.quickItems.length; i++)
                _QuickRow(index: i, item: store.quickItems[i], last: i == store.quickItems.length - 1, onTap: () => _edit(context, index: i)),
            ]),
          ),
      ]),
    );
  }

  static Future<void> _edit(BuildContext context, {int? index}) {
    final store = StoreScope.read(context);
    final old = index == null ? null : store.quickItems[index];
    final name = TextEditingController(text: old == null ? '' : tr(old.name));
    final amount = TextEditingController(text: old == null ? '' : dots(old.amount));
    var cat = old?.cat ?? 'food';
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(index == null ? tr('Tombol baru') : tr('Ubah tombol'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                if (index != null)
                  TextButton(
                    onPressed: () {
                      store.removeQuickItem(index);
                      Navigator.pop(ctx);
                    },
                    child: Text(tr('Hapus'), style: TextStyle(color: ZColors.of(ctx).warn, fontWeight: FontWeight.w800)),
                  ),
              ]),
              const SizedBox(height: 12),
              TextField(controller: name, textCapitalization: TextCapitalization.sentences, decoration: _input(ctx, tr('Nama, misal Kopi'))),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: _input(ctx, '0', prefix: '$currencySymbol '),
                onChanged: (v) {
                  final n = _digits(v);
                  final t = n == 0 ? '' : dots(n);
                  if (t != v) amount.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
                },
              ),
              _label(ctx, tr('Kategori')),
              _CategoryPicker(income: false, value: cat, onPick: (c) => set(() => cat = c)),
              const SizedBox(height: 18),
              _saveButton(ctx, () {
                final n = _digits(amount.text);
                if (name.text.trim().isEmpty || n <= 0) return;
                store.saveQuickItem(QuickEntry(name: name.text.trim(), cat: cat, amount: n), index: index);
                Navigator.pop(ctx);
              }),
            ]),
          ),
        );
      }),
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.index, required this.item, required this.last, required this.onTap});

  final int index;
  final QuickEntry item;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final z = ZColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: z.divider))),
        child: Row(children: [
          CategoryTile(category: store.category(item.cat), size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(item.name), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(store.category(item.cat).label, style: TextStyle(fontSize: 12, color: z.muted2)),
            ]),
          ),
          Text(rp(item.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          Icon(Icons.chevron_right_rounded, color: z.muted2),
        ]),
      ),
    );
  }
}

// ============================================================
// Transaksi berulang
// ============================================================
class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final list = [...store.recurring]..sort((a, b) => a.day.compareTo(b.day));
    return Scaffold(
      backgroundColor: z.bg,
      body: PageScroll(withDock: false, children: [
        PageTitle(tr('Transaksi berulang'), onBack: () => Navigator.of(context).pop(), actions: [
          IconButton(tooltip: tr('Tambah'), onPressed: () => _add(context), icon: Icon(Icons.add_circle_rounded, color: z.primary, size: 30)),
        ]),
        const SizedBox(height: 6),
        Text(tr('Gaji, kos, cicilan, atau langganan tercatat otomatis setiap bulan pada tanggalnya.'),
            style: TextStyle(fontSize: 13, color: z.muted, height: 1.45)),
        const SizedBox(height: 14),
        if (list.isEmpty)
          ZCard(child: EmptyState(title: tr('Belum ada transaksi berulang'), message: tr('Tekan + untuk menambah, misalnya gaji tanggal 25.')))
        else
          ZCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < list.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(border: i == list.length - 1 ? null : Border(bottom: BorderSide(color: z.divider))),
                  child: Row(children: [
                    CategoryTile(category: store.category(list[i].cat), size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(list[i].name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(trf('Setiap tanggal {0}', [list[i].day]), style: TextStyle(fontSize: 12, color: z.muted2)),
                      ]),
                    ),
                    Text(rpSigned(list[i].amount),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: list[i].isExpense ? z.text : z.accentText)),
                    IconButton(
                      tooltip: tr('Hapus'),
                      onPressed: () => store.removeRecurring(list[i].id),
                      icon: Icon(Icons.delete_outline_rounded, color: z.muted2, size: 20),
                    ),
                  ]),
                ),
            ]),
          ),
        const SizedBox(height: 12),
        Text(tr('Aktifkan "Pengingat tagihan" di Pengaturan untuk diingatkan sehari sebelumnya.'),
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: z.muted2)),
      ]),
    );
  }

  static Future<void> _add(BuildContext context) {
    final store = StoreScope.read(context);
    final name = TextEditingController();
    final amount = TextEditingController();
    var income = false;
    var cat = 'bills';
    var day = DateTime.now().day.clamp(1, 28);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final z = ZColors.of(ctx);
        final startsNext = DateTime.now().day > day;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Transaksi berulang baru'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Segmented<bool>(
                items: [(false, tr('Pengeluaran')), (true, tr('Pemasukan'))],
                value: income,
                onChanged: (v) => set(() {
                  income = v;
                  cat = v ? 'salary' : 'bills';
                }),
              ),
              const SizedBox(height: 12),
              TextField(controller: name, textCapitalization: TextCapitalization.sentences, decoration: _input(ctx, income ? tr('Misal Gaji') : tr('Misal Kos atau Netflix'))),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: _input(ctx, '0', prefix: '$currencySymbol '),
                onChanged: (v) {
                  final n = _digits(v);
                  final t = n == 0 ? '' : dots(n);
                  if (t != v) amount.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
                },
              ),
              _label(ctx, tr('Kategori')),
              _CategoryPicker(income: income, value: cat, onPick: (c) => set(() => cat = c)),
              _label(ctx, tr('Tanggal setiap bulan')),
              Row(children: [
                IconButton.filledTonal(onPressed: () => set(() => day = day > 1 ? day - 1 : 28), icon: const Icon(Icons.remove_rounded)),
                Expanded(
                  child: Text(trf('Tanggal {0}', [day]), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                IconButton.filledTonal(onPressed: () => set(() => day = day < 28 ? day + 1 : 1), icon: const Icon(Icons.add_rounded)),
              ]),
              const SizedBox(height: 6),
              Text(startsNext ? tr('Tanggal ini sudah lewat, jadi mulai tercatat bulan depan.') : tr('Akan tercatat bulan ini pada tanggal tersebut.'),
                  style: TextStyle(fontSize: 12, color: z.muted2)),
              const SizedBox(height: 18),
              _saveButton(ctx, () {
                final n = _digits(amount.text);
                if (name.text.trim().isEmpty || n <= 0) return;
                store.addRecurring(name: name.text.trim(), cat: cat, amount: income ? n : -n, day: day);
                Navigator.pop(ctx);
                showZToast(context, tr('Transaksi berulang disimpan'));
              }),
            ]),
          ),
        );
      }),
    );
  }
}

// ============================================================
// Tentang, Kebijakan Privasi, Syarat & Ketentuan
// ============================================================
const kRepoUrl = 'https://github.com/Raihan-Zafran/Razarsa';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    Widget row(IconData icon, String tone, String label, String? sub, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              IconTile(icon: icon, tone: tone, size: 34, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  if (sub != null) Text(sub, style: TextStyle(fontSize: 12, color: z.muted2)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: z.muted2),
            ]),
          ),
        );
    Future<void> copy(String text, String msg) async {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) showZToast(context, msg);
    }

    return Scaffold(
      backgroundColor: z.bg,
      body: PageScroll(withDock: false, children: [
        PageTitle(tr('Tentang'), onBack: () => Navigator.of(context).pop()),
        const SizedBox(height: 16),
        Center(child: Image.asset('assets/images/logo.png', width: 84)),
        const SizedBox(height: 10),
        const Center(child: Text('Razarsa', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
        Center(child: Text(trf('Versi {0}', [kAppVersion]), style: TextStyle(fontSize: 13, color: z.muted2))),
        const SizedBox(height: 16),
        ZCard(
          child: Text(
            tr('Razarsa adalah satu aplikasi untuk mengatur hidup: mode Keuangan untuk mencatat uang, dan mode Produktif untuk tugas, kalender, pengingat, dan catatan. Semua data tersimpan di HP-mu sendiri.'),
            style: TextStyle(fontSize: 13.5, height: 1.55, color: z.text2),
          ),
        ),
        const SizedBox(height: 12),
        ZCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            row(Icons.shield_outlined, 'green', tr('Kebijakan privasi'), null, () => pushPage(context, LegalPage.privacy())),
            Divider(height: 1, color: z.divider),
            row(Icons.description_outlined, 'gray', tr('Syarat & ketentuan'), null, () => pushPage(context, LegalPage.terms())),
            Divider(height: 1, color: z.divider),
            row(Icons.chat_bubble_outline_rounded, 'blue', tr('Kirim masukan'), tr('Salin link halaman masukan'),
                () => copy('$kRepoUrl/issues', tr('Link disalin. Tempel di browser untuk mengirim masukan.'))),
            Divider(height: 1, color: z.divider),
            row(Icons.system_update_alt_rounded, 'amber', tr('Versi terbaru'), tr('Salin link halaman unduhan'),
                () => copy('$kRepoUrl/releases', tr('Link disalin. Tempel di browser untuk melihat versi terbaru.'))),
          ]),
        ),
        const SizedBox(height: 18),
        Text(tr('Dibuat oleh Raihan Zafran Syaddat'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: z.muted)),
        const SizedBox(height: 2),
        Text(tr('Nama Razarsa berasal dari RAihan ZAfran SyAddat'), textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: z.muted2)),
        const SizedBox(height: 4),
        Text(tr('Font Plus Jakarta Sans · SIL Open Font License'), textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: z.muted2)),
      ]),
    );
  }
}

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.title, required this.sections});

  factory LegalPage.privacy() => LegalPage(title: tr('Kebijakan privasi'), sections: [
        (tr('Ringkasnya'), tr('Razarsa tidak mengirim datamu ke server mana pun. Semua catatan keuangan, tugas, agenda, dan catatan disimpan hanya di HP ini.')),
        (tr('Data yang disimpan'), tr('Nama tampilan dan email yang kamu isi saat masuk, transaksi, anggaran, target tabungan, tugas, agenda, catatan, dan pengaturan aplikasi. Semua tersimpan di penyimpanan lokal HP.')),
        (tr('Izin yang dipakai'), tr('Notifikasi: untuk pengingat harian, pengingat kalender, peringatan anggaran, dan pengingat tagihan. Sidik jari: hanya untuk membuka kunci aplikasi; data sidik jari tidak pernah dibaca atau disimpan oleh Razarsa, semuanya diurus oleh sistem Android.')),
        (tr('PIN'), tr('PIN disimpan dalam bentuk acak (hash), bukan angka aslinya.')),
        (tr('Backup & ekspor'), tr('File backup dan CSV dibuat hanya saat kamu memintanya dan disimpan di lokasi yang kamu pilih. Simpan file itu dengan aman karena isinya tidak dienkripsi.')),
        (tr('Menghapus data'), tr('Kamu bisa menghapus semua data lewat Pengaturan → Hapus semua data, atau dengan menghapus aplikasi.')),
        (tr('Perubahan'), tr('Kebijakan ini bisa berubah saat ada fitur baru, misalnya login online. Perubahan akan dicantumkan di catatan rilis.')),
      ]);

  factory LegalPage.terms() => LegalPage(title: tr('Syarat & ketentuan'), sections: [
        (tr('Penggunaan'), tr('Razarsa gratis untuk dipakai pribadi. Gunakan sebagai alat bantu mencatat dan mengatur, bukan sebagai nasihat keuangan profesional.')),
        (tr('Tanggung jawab data'), tr('Karena data hanya ada di HP ini, kehilangan HP atau menghapus aplikasi bisa menghapus data. Buat backup secara berkala.')),
        (tr('Versi beta & pembaruan'), tr('Beberapa fitur masih dikembangkan dan bisa berubah. Pasang versi baru di atas versi lama agar data tetap aman.')),
        (tr('Akun'), tr('Login di versi ini masih lokal dan kata sandi belum diperiksa ke server. Jangan pakai kata sandi penting.')),
        (tr('Tanpa jaminan'), tr('Aplikasi disediakan apa adanya. Pembuat tidak bertanggung jawab atas kerugian akibat kesalahan pencatatan atau kehilangan data.')),
      ]);

  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Scaffold(
      backgroundColor: z.bg,
      body: PageScroll(withDock: false, children: [
        PageTitle(title, onBack: () => Navigator.of(context).pop()),
        const SizedBox(height: 4),
        Text(trf('Berlaku sejak versi {0}', [kAppVersion]), style: TextStyle(fontSize: 12, color: z.muted2)),
        const SizedBox(height: 12),
        for (final (h, body) in sections) ...[
          ZCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(body, style: TextStyle(fontSize: 13.5, height: 1.55, color: z.text2)),
            ]),
          ),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}
