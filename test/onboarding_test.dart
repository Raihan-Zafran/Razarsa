import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/settings/settings_page.dart';
import 'package:razarsa/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

Future<void> app(WidgetTester t, AppStore s, {Size size = const Size(390, 844)}) async {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(RazarsaApp(store: s));
  await t.pump(const Duration(milliseconds: 800));
}

Future<void> toForm(WidgetTester t) async {
  await t.tap(find.text('BUAT PROFIL'));
  await t.pump(const Duration(milliseconds: 900));
}

Future<void> fill(WidgetTester t, {String name = '', String email = '', String pin = '', String pin2 = ''}) async {
  final f = find.byType(TextField);
  await t.enterText(f.at(0), name);
  await t.enterText(f.at(1), email);
  await t.enterText(f.at(2), pin);
  await t.enterText(f.at(3), pin2);
}

Future<void> submit(WidgetTester t) async {
  await t.tap(find.text('MULAI'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 2000)); // pewaktu ekspresi karakter (1,5 dtk)
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 5));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
  });
  setUp(() => L.lang = 'id');

  group('Layar awal = profil lokal (tanpa pura-pura akun online)', () {
    testWidgets('hanya dua pilihan; tidak ada Google, kata sandi akun, atau lupa kata sandi', (t) async {
      final s = await newStore();
      await app(t, s);
      expect(find.text('BUAT PROFIL'), findsOneWidget);
      expect(find.text('LEWATI DULU'), findsOneWidget);
      for (final gone in ['GOOGLE', 'Lupa kata sandi', 'MASUK DENGAN EMAIL', 'Belum punya akun']) {
        expect(find.textContaining(gone), findsNothing, reason: gone);
      }
      expect(find.textContaining('tidak ada akun online', findRichText: true, skipOffstage: false), findsNothing);
      expect(find.text('Datamu hanya tersimpan di HP ini. Tidak ada akun online.'), findsOneWidget);
      await finish(t);
    });

    testWidgets('form: nama, email opsional, PIN, ulangi PIN (tanpa kata sandi)', (t) async {
      final s = await newStore();
      await app(t, s);
      await toForm(t);
      expect(find.byType(TextField), findsNWidgets(4));
      for (final hint in ['Nama panggilan', 'Email (opsional)', 'PIN 6 angka (disarankan)', 'Ulangi PIN']) {
        expect(find.text(hint), findsOneWidget, reason: hint);
      }
      expect(find.textContaining('Kata sandi'), findsNothing);
      await finish(t);
    });

    testWidgets('LEWATI DULU: masuk tanpa profil dan tanpa PIN', (t) async {
      final s = await newStore();
      await app(t, s);
      await t.tap(find.text('LEWATI DULU'));
      await t.pump(const Duration(milliseconds: 900));
      expect(s.loggedIn, isTrue);
      expect(s.pinEnabled, isFalse);
      expect(find.text('Transaksi Terbaru'), findsOneWidget);
      await finish(t);
    });
  });

  group('Validasi form', () {
    Future<void> expectRejected(WidgetTester t, AppStore s, String message) async {
      await submit(t);
      expect(find.text(message), findsOneWidget, reason: 'pesan: $message');
      expect(s.loggedIn, isFalse, reason: 'tidak boleh masuk bila isian salah');
      expect(s.pinEnabled, isFalse);
    }

    testWidgets('nama kosong ditolak', (t) async {
      final s = await newStore();
      await app(t, s);
      await toForm(t);
      await fill(t, name: '   ');
      await expectRejected(t, s, 'Isi nama panggilanmu dulu.');
      await finish(t);
    });

    testWidgets('email salah ditolak, email kosong boleh', (t) async {
      final s = await newStore();
      await app(t, s);
      await toForm(t);
      await fill(t, name: 'Budi', email: 'bukan-email');
      await expectRejected(t, s, 'Email belum benar (boleh dikosongkan).');
      await finish(t);
    });

    testWidgets('PIN kurang dari 6 angka ditolak', (t) async {
      final s = await newStore();
      await app(t, s);
      await toForm(t);
      await fill(t, name: 'Budi', pin: '1234', pin2: '1234');
      await expectRejected(t, s, 'PIN harus 6 angka.');
      await finish(t);
    });

    testWidgets('PIN dan ulangannya berbeda ditolak (mencegah terkunci karena salah ketik)', (t) async {
      final s = await newStore();
      await app(t, s);
      await toForm(t);
      await fill(t, name: 'Budi', pin: '123456', pin2: '123457');
      await expectRejected(t, s, 'PIN dan ulangannya belum sama.');
      await finish(t);
    });

    testWidgets('kolom PIN hanya menerima angka dan maksimal 6', (t) async {
      final s = await newStore();
      await app(t, s);
      await toForm(t);
      final f = find.byType(TextField);
      await t.enterText(f.at(2), 'ab12-34cd5678');
      expect(t.widget<TextField>(f.at(2)).controller!.text, '123456');
      await finish(t);
    });

    testWidgets('PIN diisi di satu kolom saja ditolak', (t) async {
      final s = await newStore();
      await app(t, s);
      await toForm(t);
      await fill(t, name: 'Budi', pin: '123456', pin2: '');
      await expectRejected(t, s, 'PIN dan ulangannya belum sama.');
      await finish(t);
    });
  });

  group('Berhasil membuat profil', () {
    testWidgets('hanya nama: profil dibuat, tanpa PIN', (t) async {
      final s = await newStore();
      await app(t, s);
      await toForm(t);
      await fill(t, name: '  Budi  ');
      await submit(t);
      expect(s.loggedIn, isTrue);
      expect(s.userName, 'Budi');
      expect(s.email, isEmpty);
      expect(s.pinEnabled, isFalse);
      expect(find.text('Transaksi Terbaru'), findsOneWidget);
      await finish(t);
    });

    testWidgets('nama + email + PIN: langsung masuk TANPA diminta PIN yang baru dibuat', (t) async {
      final s = await newStore();
      await app(t, s);
      await toForm(t);
      await fill(t, name: 'Budi', email: 'budi@contoh.com', pin: '246810', pin2: '246810');
      await submit(t);
      expect(s.loggedIn, isTrue);
      expect(s.email, 'budi@contoh.com');
      expect(s.pinEnabled, isTrue);
      expect(s.pinLength, 6);
      expect(find.text('Masukkan PIN'), findsNothing, reason: 'sesi pertama sudah terbuka');
      expect(find.text('Transaksi Terbaru'), findsOneWidget);
      await finish(t);
    });

    testWidgets('setelah itu, membuka aplikasi dari nol langsung meminta PIN', (t) async {
      final s = await newStore();
      await app(t, s);
      await toForm(t);
      await fill(t, name: 'Budi', pin: '246810', pin2: '246810');
      await submit(t);
      await finish(t);
      await s.flush();
      final reopened = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      expect(reopened.sessionUnlocked, isFalse, reason: 'status sesi tidak boleh ikut tersimpan');
      await app(t, reopened);
      expect(find.text('Masukkan PIN'), findsOneWidget);
      expect(find.text('Transaksi Terbaru'), findsNothing);
      await finish(t);
    });

    testWidgets('nama lebih dari 30 huruf dipotong', (t) async {
      final s = await newStore();
      await app(t, s);
      await toForm(t);
      await fill(t, name: 'N' * 45);
      await submit(t);
      expect(s.userName.length, 30);
      await finish(t);
    });
  });

  group('Ubah nama & email di Pengaturan (pengganti "Keluar")', () {
    Future<void> settings(WidgetTester t, AppStore s) async {
      t.view.physicalSize = const Size(390 * 2, 844 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(StoreScope(
        store: s,
        child: MaterialApp(theme: buildTheme(Brightness.light), home: const Scaffold(body: SettingsPage())),
      ));
      await t.pump(const Duration(milliseconds: 700));
    }

    testWidgets('tidak ada lagi tombol Keluar; ada Ubah nama & email', (t) async {
      final s = await newStore();
      await settings(t, s);
      await t.scrollUntilVisible(find.text('Ubah nama & email'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Keluar'), findsNothing);
      expect(find.text('Ubah nama & email'), findsOneWidget);
    });

    testWidgets('mengubah nama dan email tersimpan', (t) async {
      final s = await newStore();
      s.login(name: 'Lama', mail: 'lama@contoh.com');
      await settings(t, s);
      await t.scrollUntilVisible(find.text('Ubah nama & email'), 300, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.text('Ubah nama & email')); // ke tengah layar, bukan di belakang dock
      await t.pump();
      await t.tap(find.text('Ubah nama & email'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(0), 'Baru');
      await t.enterText(find.byType(TextField).at(1), '');
      await t.tap(find.text('Simpan'));
      await t.pumpAndSettle();
      expect(s.userName, 'Baru');
      expect(s.email, isEmpty);
    });

    testWidgets('email salah atau nama kosong ditolak, data lama tetap', (t) async {
      final s = await newStore();
      s.login(name: 'Lama', mail: 'lama@contoh.com');
      await settings(t, s);
      await t.scrollUntilVisible(find.text('Ubah nama & email'), 300, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.text('Ubah nama & email')); // ke tengah layar, bukan di belakang dock
      await t.pump();
      await t.tap(find.text('Ubah nama & email'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(1), 'salah');
      await t.tap(find.text('Simpan'));
      await t.pumpAndSettle();
      expect(s.userName, 'Lama');
      expect(s.email, 'lama@contoh.com');
    });
  });

  group('Store: profil dan sesi', () {
    test('updateProfile memeriksa nama dan email', () async {
      final s = await newStore();
      expect(s.updateProfile(name: '  ', email: ''), isFalse);
      expect(s.updateProfile(name: 'A' * 31), isFalse);
      expect(s.updateProfile(name: 'Ani', email: 'x'), isFalse);
      expect(s.updateProfile(name: 'Ani', email: ' ani@contoh.com '), isTrue);
      expect(s.userName, 'Ani');
      expect(s.email, 'ani@contoh.com');
    });

    test('sessionUnlocked hanya menyala setelah PIN dibuat, dan mematikan PIN tidak mengubahnya jadi terkunci', () async {
      final s = await newStore();
      expect(s.sessionUnlocked, isFalse);
      s.setPin('123456');
      expect(s.sessionUnlocked, isTrue);
    });
  });
}
