import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/settings/manage_pages.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
  });
  setUp(() => L.lang = 'id');

  group('Kelola kategori (data)', () {
    test('ganti nama: terikat id, transaksi lama ikut nama baru; nama kembar/kosong ditolak', () async {
      final s = await newStore();
      final a = s.addCustomCategory('Hobi', income: false);
      s.addCustomCategory('Game', income: false);
      s.addTxn(name: 'x', cat: a.id, amount: -1000);
      expect(s.renameCustomCategory(a.id, '  Koleksi  '), isTrue);
      expect(s.category(a.id).label, 'Koleksi');
      expect(s.txns.first.cat, a.id);
      expect(s.renameCustomCategory(a.id, 'game'), isFalse); // kembar dengan buatan lain
      expect(s.renameCustomCategory(a.id, 'makan & minum'), isFalse); // kembar dengan bawaan
      expect(s.renameCustomCategory(a.id, '   '), isFalse);
      expect(s.renameCustomCategory('tidak-ada', 'Baru'), isFalse);
      expect(s.category(a.id).label, 'Koleksi');
    });

    test('hapus: data yang memakainya pindah ke Lainnya, tidak ada transaksi hilang', () async {
      final s = await newStore();
      final e = s.addCustomCategory('Hobi', income: false);
      final i = s.addCustomCategory('Side job', income: true);
      s.addTxn(name: 'a', cat: e.id, amount: -1000);
      s.addTxn(name: 'b', cat: i.id, amount: 5000);
      s.addRecurring(name: 'r', cat: e.id, amount: -2000, day: 5);
      expect(s.categoryUsage(e.id), 2);
      expect(s.removeCustomCategory(e.id), 2);
      expect(s.removeCustomCategory(i.id), 1);
      expect(s.customCats, isEmpty);
      expect(s.txns.length, 2);
      expect(s.txns.firstWhere((t) => t.name == 'a').cat, 'other');
      expect(s.txns.firstWhere((t) => t.name == 'b').cat, 'otherIn');
      expect(s.recurring.single.cat, 'other');
      expect(s.removeCustomCategory(e.id), -1); // sudah hilang: aman
    });

    test('hasil ganti nama dan hapus bertahan setelah restart', () async {
      final s = await newStore();
      final a = s.addCustomCategory('Hobi', income: false);
      final b = s.addCustomCategory('Game', income: false);
      s.renameCustomCategory(a.id, 'Koleksi');
      s.removeCustomCategory(b.id);
      await s.flush();
      final again = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      expect(again.customCats.map((c) => c.label), ['Koleksi']);
    });
  });

  group('Kelola kategori (layar)', () {
    testWidgets('tambah, ganti nama, dan hapus lewat layar', (t) async {
      final s = await newStore();
      t.view.physicalSize = const Size(390 * 2, 844 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(StoreScope(store: s, child: MaterialApp(theme: buildTheme(Brightness.light), home: const CategoriesPage())));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Makan & Minum'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);

      await t.tap(find.byTooltip('Tambah'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.enterText(find.byType(TextField), 'Hobi');
      await t.tap(find.text('Simpan'));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 600));
      expect(s.customCats.single.label, 'Hobi');
      expect(find.text('Hobi'), findsOneWidget);

      await t.tap(find.byTooltip('Ubah nama'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.enterText(find.byType(TextField), 'Makan & Minum');
      await t.tap(find.text('Simpan'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Nama itu sudah dipakai kategori lain.'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Koleksi');
      await t.tap(find.text('Simpan'));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 600));
      expect(s.customCats.single.label, 'Koleksi');

      await t.tap(find.byTooltip('Hapus'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.text('Hapus').last);
      await t.pump(const Duration(milliseconds: 500));
      expect(s.customCats, isEmpty);
      await t.pumpWidget(const SizedBox());
    });
  });
}
