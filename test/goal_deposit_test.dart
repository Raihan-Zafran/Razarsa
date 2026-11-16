import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/models.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/finance/goals_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppStore(await SharedPreferences.getInstance(), vault: testVault);
  s.goals.add(Goal(id: 'a', name: 'Dana darurat', target: 10000000, saved: 6000000));
  return s;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
  });
  setUp(() => L.lang = 'id');

  for (final (w, h, label) in const [(390.0, 844.0, 'HP'), (1440.0, 900.0, 'Windows')]) {
    testWidgets('$label: setor dengan titik ribuan + Enter menambah tabungan; kosong diberi pesan', (t) async {
      t.view.physicalSize = Size(w, h);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final s = await newStore();
      await t.pumpWidget(StoreScope(store: s, child: MaterialApp(theme: buildTheme(Brightness.light), home: const Scaffold(body: GoalsPage()))));
      await t.pump(const Duration(seconds: 3));
      // HP: ketuk kartu target; Windows: tombol "Setor".
      await t.tap(w > 900 ? find.text('Setor').first : find.text('Dana darurat').last);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Setor ke Dana darurat'), findsOneWidget);
      // Kosong: tidak tertutup diam-diam, ada pesannya.
      await t.tap(find.text('Tambah'));
      await t.pump();
      expect(find.text('Isi nominal dulu'), findsOneWidget);
      await t.enterText(find.byType(TextField), '150000');
      await t.pump();
      expect(find.text('150.000'), findsOneWidget, reason: 'titik ribuan saat mengetik');
      await t.tap(find.text('+Rp 50 rb'));
      await t.pump();
      expect(find.text('200.000'), findsOneWidget);
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump(const Duration(milliseconds: 400));
      expect(s.goals.single.saved, 6200000);
      await t.pump(const Duration(seconds: 3));
    });
  }
}
