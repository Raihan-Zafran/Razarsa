import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> store({bool lockedNote = false}) async {
  SharedPreferences.setMockInitialValues({});
  final s = AppStore(await SharedPreferences.getInstance(), vault: testVault)..setPin('123456');
  if (lockedNote) {
    final n = s.addNote(title: 'Rahasia', body: 'isi');
    s.updateNote(n, locked: true);
  }
  return s;
}

Future<void> openSettings(WidgetTester t, AppStore s) async {
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(StoreScope(
    store: s,
    child: MaterialApp(theme: buildTheme(Brightness.light), home: const Scaffold(body: SettingsPage())),
  ));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> digits(WidgetTester t, String d) async {
  for (final c in d.split('')) {
    await t.tap(find.text(c));
    await t.pump(const Duration(milliseconds: 60));
  }
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> scrollTo(WidgetTester t, String text) async {
  await t.scrollUntilVisible(find.text(text), 300, scrollable: find.byType(Scrollable).first);
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
  });
  setUp(() => L.lang = 'id');

  group('Ganti PIN', () {
    testWidgets('PIN lama benar lalu PIN baru dua kali: berganti, catatan tetap terkunci', (t) async {
      final s = await store(lockedNote: true);
      await openSettings(t, s);
      await scrollTo(t, 'Ganti PIN');
      await t.tap(find.text('Ganti PIN'));
      await t.pumpAndSettle();
      expect(find.text('Masukkan PIN'), findsOneWidget);
      await digits(t, '123456');
      await t.pumpAndSettle();
      expect(find.text('Buat PIN'), findsOneWidget);
      await digits(t, '654321');
      await t.pumpAndSettle();
      expect(find.text('Ulangi PIN'), findsOneWidget);
      await digits(t, '654321');
      await t.pumpAndSettle();
      expect(s.checkPin('654321'), isTrue);
      expect(s.checkPin('123456'), isFalse);
      expect(s.notes.single.locked, isTrue);
      expect(s.notes.single.body, 'isi');
    });

    testWidgets('PIN lama salah: tidak bisa lanjut dan PIN tidak berubah', (t) async {
      final s = await store();
      await openSettings(t, s);
      await scrollTo(t, 'Ganti PIN');
      await t.tap(find.text('Ganti PIN'));
      await t.pumpAndSettle();
      await digits(t, '000000');
      expect(find.text('PIN salah'), findsOneWidget);
      expect(find.text('Buat PIN'), findsNothing);
      expect(s.pinFails, 1);
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('PIN baru yang tidak cocok diulang dan PIN lama tetap berlaku', (t) async {
      final s = await store();
      await openSettings(t, s);
      await scrollTo(t, 'Ganti PIN');
      await t.tap(find.text('Ganti PIN'));
      await t.pumpAndSettle();
      await digits(t, '123456');
      await t.pumpAndSettle();
      await digits(t, '111111');
      await t.pumpAndSettle();
      await digits(t, '222222'); // tidak sama
      await t.pumpAndSettle();
      expect(find.text('PIN tidak cocok, coba lagi'), findsOneWidget);
      expect(s.checkPin('123456'), isTrue);
    });
  });

  group('Dialog backup', () {
    Future<void> openBackupDialog(WidgetTester t) async {
      await scrollTo(t, 'Backup & Pulihkan');
      await t.tap(find.text('Backup & Pulihkan'));
      await t.pumpAndSettle();
      await t.tap(find.text('Buat backup'));
      await t.pumpAndSettle();
      expect(find.text('Lindungi backup dengan kata sandi'), findsOneWidget);
    }

    testWidgets('ada catatan terkunci: kata sandi wajib, tidak ada pilihan tanpa kata sandi', (t) async {
      final s = await store(lockedNote: true);
      await openSettings(t, s);
      await openBackupDialog(t);
      expect(find.text('Tanpa kata sandi'), findsNothing);
      expect(find.textContaining('wajib diberi kata sandi'), findsOneWidget);
    });

    testWidgets('tanpa catatan terkunci: boleh tanpa kata sandi', (t) async {
      final s = await store();
      await openSettings(t, s);
      await openBackupDialog(t);
      expect(find.text('Tanpa kata sandi'), findsOneWidget);
    });

    testWidgets('kata sandi terlalu pendek dan tidak cocok ditolak dengan pesan', (t) async {
      final s = await store(lockedNote: true);
      await openSettings(t, s);
      await openBackupDialog(t);
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'abc');
      await t.enterText(fields.at(1), 'abc');
      await t.tap(find.text('Lanjut'));
      await t.pump();
      expect(find.text('Kata sandi terlalu pendek'), findsOneWidget);
      await t.enterText(fields.at(0), 'kata-sandi-123');
      await t.enterText(fields.at(1), 'kata-sandi-999');
      await t.tap(find.text('Lanjut'));
      await t.pump();
      expect(find.text('Kata sandi tidak cocok'), findsOneWidget);
      expect(find.text('Lindungi backup dengan kata sandi'), findsOneWidget); // dialog tetap terbuka
    });

    testWidgets('Batal menutup dialog tanpa membuat file', (t) async {
      final s = await store();
      await openSettings(t, s);
      await openBackupDialog(t);
      await t.tap(find.text('Batal'));
      await t.pumpAndSettle();
      expect(find.text('Lindungi backup dengan kata sandi'), findsNothing);
      expect(s.lastBackup, isEmpty);
    });
  });
}
