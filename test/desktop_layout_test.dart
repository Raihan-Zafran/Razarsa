import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Semua halaman desktop pada berbagai lebar/tinggi jendela: tidak boleh ada overflow atau galat tata letak.
Future<AppStore> seeded() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppStore(await SharedPreferences.getInstance(), vault: testVault);
  s.login(name: 'Budi');
  final now = DateTime.now();
  for (var i = 0; i < 14; i++) {
    s.addTxn(name: 'Makan $i', cat: 'food', amount: -20000 - i * 1500, at: now.subtract(Duration(days: i)));
  }
  s.addTxn(name: 'Gaji', cat: 'salary', amount: 5000000, at: now.subtract(const Duration(days: 3)));
  s.addWallet(name: 'BRI', type: 'bank', opening: 1000000);
  s.addWallet(name: 'DANA', type: 'ewallet', opening: 200000);
  s.addGoal('Dana darurat', 10000000);
  s.addToGoal(s.goals.first.id, 4000000);
  s.setBudget(3000000);
  s.addTodo('Tugas terlambat', cat: 'Kerja', tone: 'blue', due: now.subtract(const Duration(days: 2)));
  s.addTodo('Tugas hari ini', cat: 'Pribadi', tone: 'green', due: now);
  s.addAgenda('Rapat panjang sekali nama acaranya untuk menguji pemotongan teks', DateTime(now.year, now.month, now.day, 10));
  s.addNote(title: 'Catatan satu', body: 'Isi catatan', tone: 'amber');
  return s;
}

Future<void> ctrl(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyDownEvent(k);
  await t.sendKeyUpEvent(k);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 700));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
  });
  setUp(() => L.lang = 'id');

  final keys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
    LogicalKeyboardKey.comma,
  ];

  for (final size in const [Size(900, 600), Size(1000, 700), Size(1100, 800), Size(1280, 720), Size(1440, 900), Size(1920, 1080)]) {
    testWidgets('semua halaman desktop tanpa overflow: ${size.width.toInt()}x${size.height.toInt()}', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final s = await seeded();
      await t.pumpWidget(RazarsaApp(store: s));
      await t.pump(const Duration(seconds: 2));
      for (final k in keys) {
        await ctrl(t, k);
        await t.pump(const Duration(seconds: 2));
        expect(t.takeException(), isNull, reason: 'galat di halaman ${keys.indexOf(k) + 1} pada $size');
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    });
  }
}
