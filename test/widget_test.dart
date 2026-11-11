import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:razarsa/core/format.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/main.dart';
import 'package:razarsa/data/productive_models.dart';
import 'package:flutter/material.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/features/productive/calendar_page.dart';
import 'package:razarsa/features/productive/notes_page.dart';
import 'package:razarsa/features/productive/todo_page.dart';
import 'package:razarsa/features/settings/profile_page.dart';
import 'package:razarsa/features/settings/manage_pages.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  group('Format rupiah', () {
    test('titik ribuan', () {
      expect(rp(12580750), 'Rp 12.580.750');
      expect(rp(0), 'Rp 0');
      expect(rpSigned(-45000), '-Rp 45.000');
      expect(rpSigned(8500000), '+Rp 8.500.000');
    });

    test('bentuk singkat', () {
      expect(rpShort(3240600), 'Rp 3,2 jt');
      expect(rpShort(5000000), 'Rp 5 jt');
      expect(rpShort(25000), 'Rp 25 rb');
    });

    test('label hari', () {
      final now = DateTime(2026, 11, 6, 10);
      expect(dayLabel(DateTime(2026, 11, 6, 8), now: now), 'Hari ini');
      expect(dayLabel(DateTime(2026, 11, 5, 23), now: now), 'Kemarin');
      expect(dayLabel(DateTime(2026, 11, 3), now: now), '3 November 2026');
    });
  });

  group('Penyimpanan data', () {
    test('saldo, pemasukan, dan pengeluaran bulan ini', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      store.addTxn(name: 'Gaji', cat: 'salary', amount: 8500000);
      final kopi = store.addTxn(name: 'Kopi', cat: 'food', amount: -25000);
      expect(store.balance, 8475000);
      expect(store.monthIncome(), 8500000);
      expect(store.monthExpense(), 25000);
      store.removeTxn(kopi.id);
      expect(store.balance, 8500000);
    });

    test('data tersimpan dan bisa dibaca ulang', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = AppStore(prefs, vault: testVault);
      a.addTxn(name: 'Ojol', cat: 'transport', amount: -20000);
      a.addGoal('Dana darurat', 15000000);
      a.login(mail: 'budi@contoh.com');
      await Future<void>.delayed(Duration.zero);
      final b = AppStore(prefs, vault: testVault);
      expect(b.txns.single.name, 'Ojol');
      expect(b.goals.single.target, 15000000);
      expect(b.loggedIn, isTrue);
      expect(b.userName, 'budi');
    });

    test('kategori paling sering dipakai tampil duluan', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      store.addTxn(name: 'Bensin', cat: 'transport', amount: -30000);
      store.addTxn(name: 'Parkir', cat: 'transport', amount: -5000);
      expect(store.rankedCategories(income: false).first.id, 'transport');
    });
  });

  test('bahasa Inggris & dolar', () {
    L.lang = 'en';
    L.currency = 'USD';
    expect(tr('Pengeluaran'), 'Expense');
    expect(trf('Sisa {0}', [rp(1500)]), r'$1,500 left');
    expect(rpShort(3200000), r'$3.2M');
    L.lang = 'id';
    L.currency = 'IDR';
    expect(tr('Pengeluaran'), 'Pengeluaran');
  });

  test('awal bulan anggaran mengikuti tanggal gajian', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance(), vault: testVault);
    store.setMonthStart(25);
    final (from, to) = store.periodRange();
    expect(from.day, 25);
    expect(to.difference(from).inDays, inInclusiveRange(28, 31));
    expect(store.checkPin('1234'), isFalse);
    store.setPin('1234');
    expect(store.checkPin('1234'), isTrue);
  });

  test('PIN: format baru memakai salt acak dan menolak PIN salah', () async {
    SharedPreferences.setMockInitialValues({});
    final a = AppStore(await SharedPreferences.getInstance(), vault: testVault);
    a.setPin('1234');
    final first = a.pinHash;
    expect(first.startsWith(r'v2$'), isTrue);
    expect(a.checkPin('1234'), isTrue);
    expect(a.checkPin('4321'), isFalse);
    a.setPin('1234');
    expect(a.pinHash, isNot(first)); // salt beda -> hash beda
    a.setPin(null);
    expect(a.pinEnabled, isFalse);
    expect(a.checkPin('1234'), isFalse);
  });

  test('PIN: format lama (SHA-256 polos) tetap bisa dipakai lalu di-upgrade', () async {
    // sha256('razarsa:1234')
    SharedPreferences.setMockInitialValues({
      'pinHash': '2fc87f8286ffc6bc8a3696adbf13c104b100a04af525a96d93d665e99ecadf58',
    });
    final store = AppStore(await SharedPreferences.getInstance(), vault: testVault);
    expect(store.checkPin('0000'), isFalse);
    expect(store.pinHash.startsWith(r'v2$'), isFalse); // salah -> tidak di-upgrade
    expect(store.checkPin('1234'), isTrue);
    expect(store.pinHash.startsWith(r'v2$'), isTrue); // benar -> di-upgrade
    expect(store.checkPin('1234'), isTrue);
    expect(store.checkPin('0000'), isFalse);
  });

  testWidgets('aplikasi terbuka di layar awal (profil lokal)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance(), vault: testVault);
    await tester.pumpWidget(RazarsaApp(store: store));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('BUAT PROFIL'), findsOneWidget);
    expect(find.text('LEWATI DULU'), findsOneWidget);
    // Tidak ada yang berpura-pura jadi akun online.
    expect(find.textContaining('GOOGLE'), findsNothing);
    expect(find.textContaining('kata sandi', findRichText: true), findsNothing);

    await tester.tap(find.text('LEWATI DULU'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Transaksi Terbaru'), findsOneWidget);
    expect(find.text('Belum ada transaksi'), findsOneWidget);
  });

  group('Mode Produktif', () {
    test('tugas, agenda, catatan tersimpan', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = AppStore(prefs, vault: testVault);
      final t = a.addTodo('Kirim laporan', cat: 'Kerja', tone: 'orange', due: DateTime.now());
      a.toggleTodo(t.id);
      a.addAgenda('Minum obat', DateTime(2026, 11, 6, 7), reminder: true, daily: true);
      a.addNote(title: 'Ide', body: 'Isi');
      a.setMode('productive');
      await Future<void>.delayed(Duration.zero);
      final b = AppStore(prefs, vault: testVault);
      expect(b.mode, 'productive');
      expect(b.todos.single.done, isTrue);
      expect(b.agenda.single.occursOn(DateTime(2026, 12, 1)), isTrue);
      expect(b.agenda.single.occursOn(DateTime(2026, 11, 5)), isFalse);
      expect(b.notes.single.title, 'Ide');
      expect(b.streak, 1);
      expect(b.totalActivity, 3);
    });

    test('agenda sekali hanya muncul di harinya', () {
      final a = Agenda(id: '1', title: 'Rapat', at: DateTime(2026, 11, 6, 9, 30));
      expect(a.occursOn(DateTime(2026, 11, 6)), isTrue);
      expect(a.occursOn(DateTime(2026, 11, 7)), isFalse);
    });
  });

  testWidgets('pindah ke mode Produktif', (tester) async {
    SharedPreferences.setMockInitialValues({'loggedIn': true, 'mode': 'productive'});
    final store = AppStore(await SharedPreferences.getInstance(), vault: testVault);
    await tester.pumpWidget(RazarsaApp(store: store));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Fokus Hari Ini'), findsOneWidget);
    expect(find.text('Tambah Cepat'), findsOneWidget);
    store.setMode('finance');
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Transaksi Terbaru'), findsOneWidget);
  });

  testWidgets('halaman Produktif & Profil tampil tanpa error', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance(), vault: testVault);
    store.addTodo('Belajar', cat: 'Kuliah', tone: 'purple', due: DateTime.now());
    store.addAgenda('Rapat', DateTime.now(), reminder: true);
    store.addNote(title: 'Ide', body: 'Isi catatan');
    for (final dark in [false, true]) {
      for (final page in const [TodoPage(), CalendarPage(), NotesPage(), ProfilePage()]) {
        await tester.pumpWidget(StoreScope(
          store: store,
          child: MaterialApp(theme: buildTheme(dark ? Brightness.dark : Brightness.light), home: Scaffold(body: page)),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      }
    }
  });

  test('transaksi berulang & catat cepat', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = AppStore(prefs, vault: testVault);
    expect(a.financeBg, 'desert');
    expect(a.quickItems, isNotEmpty);
    final today = DateTime.now().day.clamp(1, 28);
    a.addRecurring(name: 'Netflix', cat: 'fun', amount: -54000, day: today);
    expect(a.txns.where((t) => t.name == 'Netflix').length, DateTime.now().day >= today ? 1 : 0);
    expect(a.postRecurring(), 0); // tidak dicatat dua kali di bulan yang sama
    a.setFinanceBg('sky');
    await Future<void>.delayed(Duration.zero);
    final b = AppStore(prefs, vault: testVault);
    expect(b.financeBg, 'sky');
    expect(b.recurring.single.name, 'Netflix');
  });

  testWidgets('halaman pengaturan baru tampil tanpa error', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance(), vault: testVault);
    store.addRecurring(name: 'Gaji', cat: 'salary', amount: 8500000, day: 25);
    for (final page in [const QuickItemsPage(), const RecurringPage(), const AboutPage(), LegalPage.privacy(), LegalPage.terms()]) {
      await tester.pumpWidget(StoreScope(store: store, child: MaterialApp(theme: buildTheme(Brightness.light), home: page)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }
  });
}
