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
  await t.tap(find.text('BUAT PROFIL'));
  await t.pump(const Duration(milliseconds: 900));
  t.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
  await t.pump(); // frame pertama memulai animasi
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
    testWidgets('keyboard terbuka ($name): 4 isian dan tombol MULAI terlihat di atas keyboard dan tetap berukuran nyaman', (t) async {
      final s = await newStore();
      await pumpLogin(t, s, size: size, keyboard: kb);
      final top = size.height - kb;
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(4)); // nama, email, PIN, ulangi PIN
      for (var i = 0; i < 4; i++) {
        final r = t.getRect(fields.at(i));
        expect(r.bottom, lessThanOrEqualTo(top), reason: 'isian ${i + 1} tertutup keyboard (bawah=${r.bottom}, keyboard mulai di $top)');
        expect(r.top, greaterThanOrEqualTo(0), reason: 'isian ${i + 1} keluar layar atas');
        expect(r.height, greaterThanOrEqualTo(17), reason: 'isian ${i + 1} terlalu kecil: ${r.height} (normal 23, layar 320 px maksimal 0,82x)');
      }
      // Karakter (kanvas y=135..320) harus tetap terlihat bila layarnya cukup tinggi; tidak boleh terpotong atas layar.
      final canvas = t.getRect(find.byKey(const ValueKey('login-canvas')));
      final sc = canvas.height / 844;
      if (size.height - kb >= 480) {
        expect(canvas.top + 135 * sc, greaterThanOrEqualTo(-0.01), reason: 'karakter terpotong di atas layar saat keyboard terbuka');
        expect(canvas.top + 320 * sc, lessThan(t.getRect(fields.at(0)).top), reason: 'karakter menimpa isian');
      }
      final btn = t.getRect(find.text('MULAI'));
      expect(btn.bottom, lessThanOrEqualTo(top), reason: 'tombol MULAI tertutup keyboard');
      await t.pumpWidget(const SizedBox()); // lepas layar supaya pewaktu animasi berhenti
      await t.pump(const Duration(seconds: 5));
    });
  }

  testWidgets('tanpa keyboard: tampilan penuh tetap seperti semula (muat seluruh kanvas)', (t) async {
    final s = await newStore();
    await pumpLogin(t, s, size: const Size(390, 844), keyboard: 0);
    final r = t.getRect(find.byType(TextField).first);
    expect(r.top, inInclusiveRange(360, 420));
    expect(r.height, closeTo(23, 1.5)); // ukuran normal tanpa keyboard tidak berubah
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
