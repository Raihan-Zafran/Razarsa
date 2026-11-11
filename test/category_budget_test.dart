import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/notifications.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/settings/manage_pages.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'helpers.dart';

Future<AppStore> newStore([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
  });
  setUp(() => L.lang = 'id');

  group('Anggaran per kategori (data)', () {
    test('pasang, ubah, hapus batas; hanya kategori pengeluaran yang ada', () async {
      final s = await newStore();
      expect(s.setCategoryBudget('food', 500000), isTrue);
      expect(s.catBudgets['food'], 500000);
      expect(s.setCategoryBudget('food', 700000), isTrue);
      expect(s.catBudgets['food'], 700000);
      expect(s.setCategoryBudget('salary', 1000), isFalse); // pemasukan
      expect(s.setCategoryBudget('tidak-ada', 1000), isFalse);
      expect(s.setCategoryBudget('food', 0), isTrue); // hapus
      expect(s.catBudgets, isEmpty);
      s.setCategoryBudget('food', 9999999999999999);
      expect(s.catBudgets['food'], AppStore.maxAmount); // dibatasi
    });

    test('terpakai dihitung dari periode ini saja', () async {
      final s = await newStore();
      s.setCategoryBudget('food', 100000);
      s.addTxn(name: 'a', cat: 'food', amount: -30000);
      s.addTxn(name: 'b', cat: 'food', amount: -20000);
      s.addTxn(name: 'c', cat: 'transport', amount: -99000);
      s.addTxn(name: 'lama', cat: 'food', amount: -77000, at: DateTime.now().subtract(const Duration(days: 90)));
      expect(s.categorySpent('food'), 50000);
    });

    test('bertahan setelah restart', () async {
      final s = await newStore();
      s.setCategoryBudget('food', 123000);
      await s.flush();
      final again = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      expect(again.catBudgets, {'food': 123000});
    });

    test('menghapus kategori buatan sendiri ikut menghapus batasnya', () async {
      final s = await newStore();
      final c = s.addCustomCategory('Hobi', income: false);
      expect(s.setCategoryBudget(c.id, 50000), isTrue);
      s.removeCustomCategory(c.id);
      expect(s.catBudgets.containsKey(c.id), isFalse);
    });

    test('ikut backup; entri tidak valid dibuang; hapus semua data mengosongkan', () async {
      final s = await newStore();
      final c = s.addCustomCategory('Hobi', income: false);
      s.setCategoryBudget('food', 400000);
      s.setCategoryBudget(c.id, 25000);
      final file = s.exportJson();
      final other = await newStore();
      expect(await other.importBackup(file), BackupResult.ok);
      expect(other.catBudgets, {'food': 400000, c.id: 25000});

      final m = jsonDecode(file) as Map<String, dynamic>;
      m['catBudgets'] = {'food': 1000, 'salary': 5, 'hantu': 7, 'transport': -5, 'bills': 'x', 'edu': 1e30};
      final third = await newStore();
      expect(await third.importBackup(jsonEncode(m)), BackupResult.ok);
      expect(third.catBudgets, {'food': 1000}); // pemasukan, tidak dikenal, negatif, salah tipe, kebesaran dibuang

      await third.clearAll();
      expect(third.catBudgets, isEmpty);
    });

    test('backup lama tanpa catBudgets tetap bisa dipulihkan', () async {
      final s = await newStore();
      s.setCategoryBudget('food', 5000);
      final m = jsonDecode(s.exportJson()) as Map<String, dynamic>..remove('catBudgets');
      final other = await newStore();
      expect(await other.importBackup(jsonEncode(m)), BackupResult.ok);
      expect(other.catBudgets, isEmpty);
    });

    test('data tersimpan yang rusak tidak membuat app gagal start', () async {
      final s = await newStore({'flutter.catBudgets': '{bukan json'});
      expect(s.catBudgets, isEmpty);
      final s2 = await newStore({'flutter.catBudgets': '[1,2]'});
      expect(s2.catBudgets, isEmpty);
    });
  });

  group('Peringatan per kategori', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final shown = <String?>[];

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'areNotificationsEnabled':
            return true;
          case 'show':
            shown.add((call.arguments as Map)['title'] as String?);
            return null;
          default:
            return null;
        }
      });
    });
    tearDownAll(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    setUp(shown.clear);

    test('mencapai 90% memberi tahu sekali per periode; saklar mati = tidak ada', () async {
      final s = await newStore();
      s.setBudget(0); // matikan anggaran total agar hanya kategori yang diuji
      s.setCategoryBudget('food', 100000);
      s.addTxn(name: 'a', cat: 'food', amount: -50000);
      s.setSwitch('budgetAlert', true);
      await Notif.checkBudget(s);
      expect(shown, isEmpty); // 50%

      s.addTxn(name: 'b', cat: 'food', amount: -45000); // 95%
      await Notif.checkBudget(s);
      expect(shown.length, 1);
      expect(shown.single, contains('Makan'));
      await Notif.checkBudget(s);
      expect(shown.length, 1); // tidak berulang

      s.setCategoryBudget('food', 100000); // batas dipasang ulang: boleh memberi tahu lagi
      await Notif.checkBudget(s);
      expect(shown.length, 2);

      shown.clear();
      s.setSwitch('budgetAlert', false);
      s.setCategoryBudget('food', 10000);
      await Notif.checkBudget(s);
      expect(shown, isEmpty);
    });

    test('nomor notifikasi kategori stabil, di luar rentang agenda/tagihan', () {
      for (final id in ['food', 'transport', 'c1700000000000001', 'x' * 40]) {
        final n = Notif.categoryNotifId(id);
        expect(n, inInclusiveRange(100, 899));
        expect(Notif.categoryNotifId(id), n);
      }
    });
  });

  group('Anggaran per kategori (layar)', () {
    testWidgets('memasang, melihat progres, dan menghapus batas', (t) async {
      final s = await newStore();
      s.addTxn(name: 'a', cat: 'food', amount: -50000);
      t.view.physicalSize = const Size(390 * 2, 844 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(StoreScope(store: s, child: MaterialApp(theme: buildTheme(Brightness.light), home: const CategoryBudgetsPage())));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Belum ada batas'), findsWidgets);

      await t.tap(find.text('Makan & Minum'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.enterText(find.byType(TextField), '100000');
      await t.tap(find.text('Simpan'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(s.catBudgets['food'], 100000);
      expect(find.byKey(const ValueKey('bar-food')), findsOneWidget);
      expect(find.textContaining('dari'), findsOneWidget);

      await t.tap(find.text('Makan & Minum'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Hapus batas'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(s.catBudgets, isEmpty);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  });
}
