import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

Future<void> pumpLogin(WidgetTester t, AppStore s, {required Size size, required double keyboard}) async {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  t.view.viewInsets = FakeViewPadding.zero;
  addTearDown(t.view.reset);
  await t.pumpWidget(StoreScope(
    store: s,
    child: MaterialApp(theme: buildTheme(Brightness.light), home: const LoginScreen()),
  ));
  await t.pump(const Duration(milliseconds: 800));
  await t.tap(find.text('Buat profil'));
  await t.pump(const Duration(milliseconds: 900));
  t.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => L.lang = 'id');

  for (final (name, size, kb) in const [
    ('360x640 + keyboard 280', Size(360, 640), 280.0),
    ('360x800 + keyboard 300', Size(360, 800), 300.0),
    ('411x891 + keyboard 320', Size(411, 891), 320.0),
    ('320x568 + keyboard 250', Size(320, 568), 250.0),
  ]) {
    testWidgets('keyboard terbuka ($name): tiap isian yang diketuk dan tombol Ayo mulai! bisa dijangkau di atas keyboard', (t) async {
      final s = await newStore();
      await pumpLogin(t, s, size: size, keyboard: kb);
      final top = size.height - kb;
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(4)); // nama, email, PIN, ulangi PIN
      for (var i = 0; i < 4; i++) {
        await t.ensureVisible(fields.at(i)); // pengguna menggulir isian ke layar
        await t.pump(const Duration(milliseconds: 400));
        await t.tap(fields.at(i));
        await t.pump(const Duration(milliseconds: 500));
        final r = t.getRect(fields.at(i));
        expect(r.bottom, lessThanOrEqualTo(top + 0.5), reason: 'isian ${i + 1} tertutup keyboard (bawah=${r.bottom}, keyboard mulai di $top)');
        expect(r.top, greaterThanOrEqualTo(-0.5), reason: 'isian ${i + 1} keluar layar atas');
        expect(r.height, closeTo(23, 3), reason: 'ukuran isian tidak boleh mengecil');
      }
      await t.ensureVisible(find.text('Ayo mulai!'));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.getRect(find.text('Ayo mulai!')).bottom, lessThanOrEqualTo(top + 0.5), reason: 'tombol tertutup keyboard');
      await t.pumpWidget(const SizedBox()); // lepas layar supaya pewaktu animasi berhenti
      await t.pump(const Duration(seconds: 5));
    });
  }

  testWidgets('inisial di lambang mengikuti huruf pertama nama', (t) async {
    final s = await newStore();
    await pumpLogin(t, s, size: const Size(390, 844), keyboard: 0);
    expect(find.text('?'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'rina');
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('R'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
