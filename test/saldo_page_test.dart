import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/models.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/finance/add_transaction_page.dart';
import 'package:razarsa/features/finance/home_page.dart';
import 'package:razarsa/features/saldo/graph_engine.dart';
import 'package:razarsa/features/saldo/saldo_graph.dart';
import 'package:razarsa/features/saldo/saldo_page.dart';
import 'package:razarsa/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

Future<void> show(WidgetTester t, AppStore s, Widget home, {Size size = const Size(390, 844)}) async {
  t.view.physicalSize = Size(size.width * 2, size.height * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(StoreScope(store: s, child: MaterialApp(theme: buildTheme(Brightness.light), home: home)));
  await t.pump(const Duration(milliseconds: 900));
}

/// Simulasi dilepas dulu supaya titik diam dan posisi bisa dibaca.
SaldoGraphState graphState(WidgetTester t) => t.state<SaldoGraphState>(find.byType(SaldoGraph));

Offset toScreen(WidgetTester t, GNode n) {
  final box = t.getRect(find.byType(SaldoGraph));
  final rx = (n.x - kGraphW / 2) * kGraphZoom + kGraphW / 2, ry = (n.y - kGraphH / 2) * kGraphZoom + kGraphH / 2;
  return Offset(box.left + rx * box.width / kGraphW, box.top + ry * box.height / kGraphH);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
  });
  setUp(() => L.lang = 'id');

  testWidgets('Beranda: mengetuk Total Saldo membuka halaman Saldo per sumber', (t) async {
    final s = await newStore();
    await show(t, s, HomePage(onSeeAll: () {}));
    await t.tap(find.text('Total Saldo'));
    await t.pumpAndSettle();
    expect(find.text('Saldo per sumber'), findsOneWidget);
    expect(find.byType(SaldoGraph), findsOneWidget);
    expect(find.bySemanticsLabel('Belum ada transaksi di periode ini'), findsOneWidget);
  });

  testWidgets('daftar sumber dikelompokkan per jenis dengan subtotal; total = jumlah sumber', (t) async {
    final s = await newStore();
    s.addWallet(name: 'BRI', type: 'bank', opening: 1000000);
    s.addWallet(name: 'DANA', type: 'ewallet', opening: 250000);
    s.setWalletBalance('cash', -50000);
    await show(t, s, const SaldoPage());
    await t.drag(find.byType(ListView), const Offset(0, -700));
    await t.pump();
    expect(find.text('BANK · 1'), findsOneWidget);
    expect(find.text('E-WALLET · 1'), findsOneWidget);
    expect(find.text('TUNAI · 1'), findsOneWidget);
    expect(find.text('Rp 1.200.000'), findsOneWidget); // total
    expect(find.text('-Rp 50.000'), findsWidgets); // saldo minus tampil dengan tanda
  });

  testWidgets('tambah sumber dari katalog: BRI muncul, BRI hilang dari katalog, ganda ditolak', (t) async {
    final s = await newStore();
    await show(t, s, const SaldoPage());
    await t.drag(find.byType(ListView), const Offset(0, -700));
    await t.pump();
    await t.tap(find.text('Tambah'));
    await t.pumpAndSettle();
    expect(find.text('Sumber saldo baru'), findsOneWidget);
    expect(find.text('Bank utama'), findsOneWidget);
    expect(find.text('Sinarmas'), findsOneWidget);
    expect(find.text('Celengan'), findsOneWidget); // "Tunai" sudah ada, jadi hanya Celengan yang ditawarkan
    await t.tap(find.text('BRI'));
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Tambah').last);
    await t.pumpAndSettle();
    expect(s.wallets.map((w) => w.name), ['Tunai', 'BRI']);
    expect(s.wallets.last.type, 'bank');
    // sheet kedua: BRI sudah tidak ditawarkan
    await t.tap(find.text('Tambah'));
    await t.pumpAndSettle();
    expect(find.text('BRI'), findsOneWidget); // hanya baris di daftar; BRI tidak lagi ditawarkan di katalog
    // nama sendiri yang sama dengan sumber yang ada (beda huruf) ditolak
    await t.enterText(find.byType(TextField).first, 'bri');
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Tambah').last);
    await t.pump();
    expect(find.text('bri sudah ada'), findsOneWidget);
    expect(s.wallets.length, 2);
  });

  testWidgets('tambah sumber tanpa pilihan/nama: ditolak dengan pesan', (t) async {
    final s = await newStore();
    await show(t, s, const SaldoPage());
    await t.drag(find.byType(ListView), const Offset(0, -700));
    await t.pump();
    await t.tap(find.text('Tambah'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Tambah').last);
    await t.pump();
    expect(find.text('Pilih atau isi nama sumber dulu'), findsOneWidget);
    expect(s.wallets.length, 1);
  });

  testWidgets('sudah 10 sumber: tombol Tambah menolak dengan pesan', (t) async {
    final s = await newStore();
    for (var i = 1; i < 10; i++) {
      s.addWallet(name: 'Bank $i', type: 'bank');
    }
    await show(t, s, const SaldoPage());
    await t.scrollUntilVisible(find.text('Tambah'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Tambah'));
    await t.pump();
    expect(find.text('Maksimal 10 sumber'), findsOneWidget);
    expect(s.wallets.length, 10);
  });

  testWidgets('atur saldo: kosong ditolak; minus diterima; angka raksasa ditolak', (t) async {
    final s = await newStore();
    await show(t, s, const SaldoPage());
    await t.drag(find.byType(ListView), const Offset(0, -700));
    await t.pump();
    await t.tap(find.text('Tunai').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Atur saldo'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '');
    await t.tap(find.text('Simpan'));
    await t.pump();
    expect(find.text('Isi saldo dulu'), findsOneWidget);
    await t.enterText(find.byType(TextField), '-250.000');
    await t.tap(find.text('Simpan'));
    await t.pumpAndSettle();
    expect(s.balance, -250000);
  });

  testWidgets('atur saldo: 13 digit lewat batas ditolak, tidak merusak', (t) async {
    final s = await newStore();
    await show(t, s, const SaldoPage());
    await t.drag(find.byType(ListView), const Offset(0, -700));
    await t.pump();
    await t.tap(find.text('Tunai').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Atur saldo'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '9999999999999');
    await t.tap(find.text('Simpan'));
    await t.pump();
    expect(find.textContaining('Maksimal Rp'), findsOneWidget);
    expect(s.balance, 0);
  });

  testWidgets('ubah nama: nama sama dengan sumber lain ditolak; nama baru diterima', (t) async {
    final s = await newStore();
    s.addWallet(name: 'BCA', type: 'bank');
    await show(t, s, const SaldoPage());
    await t.drag(find.byType(ListView), const Offset(0, -700));
    await t.pump();
    await t.tap(find.text('BCA').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Ubah nama'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'TUNAI');
    await t.tap(find.text('Simpan'));
    await t.pump();
    expect(find.text('TUNAI sudah ada'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'BCA Utama');
    await t.tap(find.text('Simpan'));
    await t.pumpAndSettle();
    expect(s.wallets.last.name, 'BCA Utama');
  });

  testWidgets('hapus sumber: transaksi dipindah, total tetap; sumber terakhir tidak bisa dihapus', (t) async {
    final s = await newStore();
    s.addWallet(name: 'BNI', type: 'bank', opening: 100000);
    s.addTxn(name: 'Belanja', cat: 'shopping', amount: -30000, wallet: s.wallets.last.id);
    final before = s.balance;
    await show(t, s, const SaldoPage());
    await t.drag(find.byType(ListView), const Offset(0, -700));
    await t.pump();
    await t.tap(find.text('BNI').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Hapus'));
    await t.pumpAndSettle();
    expect(find.textContaining('1 transaksi dan saldonya dipindah ke Tunai'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Hapus'));
    await t.pumpAndSettle();
    expect(s.wallets.length, 1);
    expect(s.balance, before);
    // sumber terakhir
    await t.tap(find.text('Tunai').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Hapus'));
    await t.pump();
    expect(find.text('Minimal harus ada satu sumber'), findsOneWidget);
    expect(s.wallets.length, 1);
  });

  testWidgets('panah kuartal: arsip hanya bisa mundur selama ada data; tombol maju nonaktif di kuartal berjalan', (t) async {
    final s = await newStore();
    final now = DateTime.now();
    s.addTxn(name: 'Lama', cat: 'food', amount: -1000, at: DateTime(now.year - 1, 2, 3, 9));
    s.addTxn(name: 'Baru', cat: 'food', amount: -2000);
    await show(t, s, const SaldoPage());
    expect(find.text('1/200'), findsOneWidget);
    IconButton btn(String tip) => t.widget<IconButton>(find.ancestor(of: find.byTooltip(tip), matching: find.byType(IconButton)));
    expect(btn('Kuartal berikutnya').onPressed, isNull);
    await t.tap(find.byTooltip('Kuartal sebelumnya'));
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.textContaining('Arsip'), findsOneWidget);
    expect(btn('Kuartal berikutnya').onPressed, isNotNull);
    await t.tap(find.byTooltip('Kuartal berikutnya'));
    await t.pumpAndSettle();
    expect(find.text('1/200'), findsOneWidget);
  });

  testWidgets('ketuk titik sumber: kartu info muncul; ketuk ruang kosong: hilang', (t) async {
    final s = await newStore();
    s.addWallet(name: 'DANA', type: 'ewallet', opening: 5000);
    s.addTxn(name: 'Bakso', cat: 'food', amount: -20000, wallet: s.wallets.last.id);
    await show(t, s, const SaldoPage());
    final g = graphState(t);
    final dana = g.sim!.byId['w:${s.wallets.last.id}']!;
    await t.tapAt(toScreen(t, dana));
    await t.pump(const Duration(milliseconds: 100));
    expect(g.selected, dana.id);
    expect(find.text('DANA'), findsWidgets);
    expect(find.textContaining('1 transaksi'), findsWidgets);
    await t.tapAt(t.getRect(find.byType(SaldoGraph)).topLeft + const Offset(8, 8));
    await t.pump(const Duration(milliseconds: 100));
    expect(g.selected, isNull);
    await t.pumpAndSettle(const Duration(milliseconds: 50));
  });

  testWidgets('tekan lama titik sumber membuka menu kelola', (t) async {
    final s = await newStore();
    s.addTxn(name: 'Kopi', cat: 'food', amount: -1000);
    await show(t, s, const SaldoPage());
    final cash = graphState(t).sim!.byId['w:cash']!;
    final gesture = await t.startGesture(toScreen(t, cash));
    await t.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await t.pumpAndSettle();
    expect(find.text('Atur saldo'), findsOneWidget);
    expect(find.text('Ubah nama'), findsOneWidget);
  });

  testWidgets('tekan lama ruang kosong membuka tambah sumber', (t) async {
    final s = await newStore();
    await show(t, s, const SaldoPage());
    final p = t.getRect(find.byType(SaldoGraph)).topLeft + const Offset(10, 10);
    final gesture = await t.startGesture(p);
    await t.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await t.pumpAndSettle();
    expect(find.text('Sumber saldo baru'), findsOneWidget);
  });

  testWidgets('geser di ruang kosong menggulir halaman; geser tepat di titik memindahkan titik, halaman diam', (t) async {
    final s = await newStore();
    for (var i = 0; i < 5; i++) {
      s.addTxn(name: 'T$i', cat: 'food', amount: -1000 * (i + 1));
    }
    await show(t, s, const SaldoPage());
    final list = find.byType(ListView);
    double offset() => t.widget<ListView>(list).controller?.offset ?? t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    final empty = t.getRect(find.byType(SaldoGraph)).topLeft + const Offset(8, 200);
    final y0 = offset();
    await t.dragFrom(empty, const Offset(0, -150));
    await t.pump();
    expect(offset(), greaterThan(y0 + 50), reason: 'ruang kosong harus menggulir halaman');
    await t.dragFrom(const Offset(0, 0), Offset.zero); // no-op
    // kembali ke atas
    await t.drag(list, const Offset(0, 400));
    await t.pumpAndSettle();
    final cash = graphState(t).sim!.byId['w:cash']!;
    final start = toScreen(t, cash);
    final y1 = offset();
    final before = Offset(cash.x, cash.y);
    await t.dragFrom(start, const Offset(0, -60));
    await t.pump(const Duration(milliseconds: 50));
    expect((offset() - y1).abs(), lessThan(1), reason: 'drag di titik tidak boleh menggulir halaman');
    expect((Offset(cash.x, cash.y) - before).distance, greaterThan(5));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
  });

  testWidgets('beban maksimum tampil tanpa galat dan menyala', (t) async {
    final s = await newStore();
    for (var i = 1; i < 10; i++) {
      s.addWallet(name: 'S$i', type: kWalletTypes[i % 3]);
    }
    for (var i = 0; i < 230; i++) {
      s.addTxn(name: 'T$i', cat: i < 150 ? 'food' : 'other', amount: -(i + 1) * 1000, wallet: s.wallets[i % 10].id);
    }
    for (var c = 0; c < 55; c++) {
      s.addCustomCategory('Kat $c', income: false);
    }
    await show(t, s, const SaldoPage());
    expect(find.text('200/200'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(t.takeException(), isNull);
    // setelah diam, tidak ada frame yang terus dijadwalkan (hemat baterai)
    await t.pumpAndSettle(const Duration(milliseconds: 50));
  });

  testWidgets('Tambah transaksi: pilih sumber; saldo sumber tampil; transaksi masuk ke sumber itu; terakhir diingat', (t) async {
    final s = await newStore();
    s.addWallet(name: 'GoPay', type: 'ewallet', opening: 100000);
    await show(t, s, const AddTransactionPage(income: false));
    expect(find.text('Bayar dari'), findsOneWidget);
    expect(find.text('GoPay'), findsOneWidget);
    await t.tap(find.text('GoPay'));
    await t.pump();
    expect(find.text('Saldo Rp 100.000'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, '25000');
    await t.pump();
    await t.tap(find.text('Makan & Minum'));
    await t.pump();
    await t.tap(find.textContaining('Simpan Rp'));
    await t.pumpAndSettle();
    expect(s.txns.single.wallet, s.wallets.last.id);
    expect(s.lastWallet, s.wallets.last.id);
    expect(s.walletBalance(s.wallets.last.id), 75000);
  });

  testWidgets('Tambah pemasukan memakai kata "Masuk ke"', (t) async {
    final s = await newStore();
    await show(t, s, const AddTransactionPage(income: true));
    expect(find.text('Masuk ke'), findsOneWidget);
  });

  testWidgets('Pengaturan: ada Palet warna, tidak ada Tes notifikasi', (t) async {
    final s = await newStore();
    await show(t, s, const Scaffold(body: SettingsPage()));
    await t.scrollUntilVisible(find.text('Palet warna'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Zamrud & champagne'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Pengingat tagihan'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Tes notifikasi'), findsNothing);
  });

  testWidgets('Pengaturan: memilih palet mengubah warna tema dan tersimpan', (t) async {
    final s = await newStore();
    await show(t, s, const Scaffold(body: SettingsPage()));
    await t.scrollUntilVisible(find.text('Palet warna'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Palet warna'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tengah malam & emas'));
    await t.pumpAndSettle();
    expect(s.palette, 2);
  });
}
