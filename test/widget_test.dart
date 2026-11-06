import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zevra/core/format.dart';
import 'package:zevra/data/store.dart';
import 'package:zevra/main.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

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
      final store = AppStore(await SharedPreferences.getInstance());
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
      final a = AppStore(prefs);
      a.addTxn(name: 'Ojol', cat: 'transport', amount: -20000);
      a.addGoal('Dana darurat', 15000000);
      a.login(mail: 'raihan@contoh.com');
      await Future<void>.delayed(Duration.zero);
      final b = AppStore(prefs);
      expect(b.txns.single.name, 'Ojol');
      expect(b.goals.single.target, 15000000);
      expect(b.loggedIn, isTrue);
      expect(b.userName, 'raihan');
    });

    test('kategori paling sering dipakai tampil duluan', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(await SharedPreferences.getInstance());
      store.addTxn(name: 'Bensin', cat: 'transport', amount: -30000);
      store.addTxn(name: 'Parkir', cat: 'transport', amount: -5000);
      expect(store.rankedCategories(income: false).first.id, 'transport');
    });
  });

  testWidgets('aplikasi terbuka di halaman masuk', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(ZevraApp(store: store));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('MASUK DENGAN EMAIL'), findsOneWidget);
    expect(find.text('Lanjut tanpa akun'), findsOneWidget);

    await tester.tap(find.text('Lanjut tanpa akun'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Transaksi Terbaru'), findsOneWidget);
    expect(find.text('Belum ada transaksi'), findsOneWidget);
  });
}
