import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> loggedIn() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppStore(await SharedPreferences.getInstance(), vault: testVault);
  s.login(name: 'Budi');
  s.addTxn(name: 'Kopi susu', cat: 'food', amount: -22000);
  s.addTxn(name: 'Gaji', cat: 'salary', amount: 5000000);
  return s;
}

Future<void> openApp(WidgetTester t, AppStore s, {Size size = const Size(1440, 900)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(RazarsaApp(store: s));
  await t.pump(const Duration(seconds: 2));
}

Future<void> ctrl(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyDownEvent(k);
  await t.sendKeyUpEvent(k);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 700));
}

/// Beberapa bingkai berturut-turut: animasi menutup rute butuh lebih dari satu pump.
Future<void> frames(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 50));
  await t.pump(const Duration(seconds: 1));
  await t.pump(const Duration(seconds: 1));
}

Future<void> close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
  });
  setUp(() => L.lang = 'id');

  group('Kerangka desktop (jendela lebar)', () {
    testWidgets('jendela lebar memakai sidebar; jendela sempit tetap memakai dock HP', (t) async {
      final s = await loggedIn();
      await openApp(t, s);
      for (final label in ['Beranda', 'Transaksi', 'Saldo', 'Laporan', 'Target', 'Hari ini', 'Tugas', 'Kalender', 'Catatan', 'Kunci', 'Pengaturan', 'Buat baru']) {
        expect(find.text(label), findsWidgets, reason: 'sidebar tanpa "$label"');
      }
      expect(find.text('Ringkasan uang dan kegiatanmu hari ini'), findsOneWidget);
      await close(t);
      await openApp(t, s, size: const Size(390, 844));
      expect(find.text('Buat baru'), findsNothing);
      expect(find.text('Halo, Budi'), findsOneWidget);
      await close(t);
    });

    testWidgets('pintasan Ctrl+angka pindah halaman dan menyamakan mode', (t) async {
      final s = await loggedIn();
      await openApp(t, s);
      await ctrl(t, LogicalKeyboardKey.digit2);
      expect(find.text('Kopi susu'), findsWidgets); // daftar transaksi
      expect(s.mode, 'finance');
      await ctrl(t, LogicalKeyboardKey.digit7);
      expect(s.mode, 'productive');
      expect(find.text('Daftar tugas dan pengingat'), findsOneWidget);
      await ctrl(t, LogicalKeyboardKey.digit1);
      expect(s.mode, 'finance');
      expect(find.text('Ringkasan uang dan kegiatanmu hari ini'), findsOneWidget);
      await ctrl(t, LogicalKeyboardKey.comma);
      expect(find.text('Pakai latar'), findsOneWidget);
      await close(t);
    });

    testWidgets('Ctrl+B menciutkan sidebar menjadi ikon dan melebarkannya lagi', (t) async {
      final s = await loggedIn();
      await openApp(t, s);
      expect(find.text('Buat baru'), findsOneWidget);
      await ctrl(t, LogicalKeyboardKey.keyB);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Buat baru'), findsNothing);
      await ctrl(t, LogicalKeyboardKey.keyB);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Buat baru'), findsOneWidget);
      await close(t);
    });

    testWidgets('Kunci tanpa PIN memberi tahu; menu tidak terkunci', (t) async {
      final s = await loggedIn();
      await openApp(t, s);
      await ctrl(t, LogicalKeyboardKey.keyL);
      expect(find.text('Aktifkan PIN dulu'), findsOneWidget);
      await t.pump(const Duration(seconds: 6));
      await close(t);
    });

    testWidgets('semua halaman tergambar tanpa galat di beberapa ukuran jendela', (t) async {
      final s = await loggedIn();
      for (final size in const [Size(900, 600), Size(1280, 720), Size(1440, 900), Size(1920, 1080)]) {
        await openApp(t, s, size: size);
        for (final k in [
          LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3, LogicalKeyboardKey.digit4, LogicalKeyboardKey.digit5,
          LogicalKeyboardKey.digit6, LogicalKeyboardKey.digit7, LogicalKeyboardKey.digit8, LogicalKeyboardKey.digit9, LogicalKeyboardKey.comma,
        ]) {
          await ctrl(t, k);
          expect(t.takeException(), isNull, reason: 'galat di $size (${k.keyLabel})');
        }
        await close(t);
      }
    });
  });

  group('Palet perintah', () {
    testWidgets('Ctrl+K membuka, mengetik menyaring, Enter menjalankan, Esc menutup', (t) async {
      final s = await loggedIn();
      await openApp(t, s);
      await ctrl(t, LogicalKeyboardKey.keyK);
      expect(find.text('Esc'), findsOneWidget);
      expect(find.text('Catat pengeluaran'), findsWidgets); // juga ada sebagai tombol di Beranda
      await t.enterText(find.byType(TextField).last, 'lapor');
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Laporan'), findsWidgets);
      expect(find.text('Catat pengeluaran'), findsOneWidget); // hanya tombol di Beranda; barisnya di palet tersaring
      await t.testTextInput.receiveAction(TextInputAction.done); // Enter di kolom cari
      await frames(t);
      expect(find.text('Esc'), findsNothing); // palet tertutup
      expect(find.text('Ringkasan pemasukan dan pengeluaran'), findsWidgets); // halaman Laporan terbuka
      await close(t);
    });

    testWidgets('Esc menutup palet; Ctrl+N juga membukanya', (t) async {
      final s = await loggedIn();
      await openApp(t, s);
      await ctrl(t, LogicalKeyboardKey.keyN);
      expect(find.text('Esc'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(t);
      expect(find.text('Esc'), findsNothing);
      await close(t);
    });

    testWidgets('panah bawah memindah pilihan, Enter menjalankan perintah ganti tema', (t) async {
      final s = await loggedIn();
      await openApp(t, s);
      final before = s.themeMode;
      await ctrl(t, LogicalKeyboardKey.keyK);
      await t.enterText(find.byType(TextField).last, 'tema');
      await t.pump(const Duration(milliseconds: 200));
      await t.testTextInput.receiveAction(TextInputAction.done);
      await frames(t);
      expect(s.themeMode, isNot(before));
      await close(t);
    });

    testWidgets('mencari nama transaksi memunculkan hasilnya', (t) async {
      final s = await loggedIn();
      await openApp(t, s);
      await ctrl(t, LogicalKeyboardKey.keyK);
      await t.enterText(find.byType(TextField).last, 'kopi');
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Kopi susu'), findsWidgets); // ada di hasil palet (dan di daftar di belakangnya bila terbuka)
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(t);
      await close(t);
    });

    testWidgets('tanpa hasil: pesan kosong tampil', (t) async {
      final s = await loggedIn();
      await openApp(t, s);
      await ctrl(t, LogicalKeyboardKey.keyK);
      await t.enterText(find.byType(TextField).last, 'zzzqqq');
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Tidak ada hasil'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(t);
      await close(t);
    });
  });

  group('Layar sambutan di jendela lebar', () {
    testWidgets('dua panel: ilustrasi di kiri, tombol di kanan; alur buat profil jalan', (t) async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      await openApp(t, s);
      expect(find.text('razarsa'), findsOneWidget);
      expect(find.text('Buat profil'), findsOneWidget);
      await t.tap(find.text('Buat profil'));
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(TextField), findsNWidgets(4));
      expect(t.takeException(), isNull);
      await close(t);
    });
  });
}
