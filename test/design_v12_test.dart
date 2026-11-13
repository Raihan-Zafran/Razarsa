import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/models.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/finance/goals_page.dart';
import 'package:razarsa/features/security/lock.dart';
import 'package:razarsa/shell/dusk_background.dart';
import 'package:razarsa/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> newStore([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

Future<void> show(WidgetTester t, AppStore s, Widget home) async {
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(StoreScope(store: s, child: MaterialApp(theme: buildTheme(Brightness.light), home: home)));
  await t.pump(const Duration(milliseconds: 900));
}

Future<void> digits(WidgetTester t, String d) async {
  for (final c in d.split('')) {
    await t.tap(find.text(c));
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
  });
  setUp(() => L.lang = 'id');

  group('Latar dan efek kaca (data)', () {
    test('bawaan: Langit dan kaca halus', () async {
      final s = await newStore();
      expect(s.financeBg, 'sky');
      expect(s.glassLevel, 1);
    });

    test('latar Gurun lama otomatis menjadi Langit; Gurun Senja dipertahankan', () async {
      expect((await newStore({'financeBg': 'desert'})).financeBg, 'sky');
      expect((await newStore({'financeBg': 'dusk'})).financeBg, 'dusk');
      expect(AppStore.normalizeFinanceBg('desert'), 'sky');
      expect(AppStore.normalizeFinanceBg(null), 'sky');
      expect(AppStore.normalizeFinanceBg(5), 'sky');
      final s = await newStore();
      s.setFinanceBg('desert'); // tidak bisa dipilih lagi
      expect(s.financeBg, 'sky');
      s.setFinanceBg('dusk');
      expect(s.financeBg, 'dusk');
    });

    test('tingkat kaca dibatasi 0..2 dan ikut tersimpan', () async {
      final s = await newStore();
      s.setGlassLevel(9);
      expect(s.glassLevel, 2);
      s.setGlassLevel(-3);
      expect(s.glassLevel, 0);
      s.setGlassLevel(2);
      await s.flush();
      final prefs = await SharedPreferences.getInstance();
      final back = AppStore(prefs, vault: testVault);
      expect(back.glassLevel, 2);
    });

    test('backup membawa latar dan efek kaca; nilai rusak diabaikan', () async {
      final s = await newStore();
      s.setFinanceBg('dusk');
      s.setGlassLevel(2);
      final file = s.exportJson();
      final other = await newStore();
      expect(await other.importBackup(file), BackupResult.ok);
      expect(other.financeBg, 'dusk');
      expect(other.glassLevel, 2);
      // File lama berisi Gurun: dipindah ke Langit.
      final m = jsonDecode(file) as Map<String, dynamic>;
      (m['settings'] as Map<String, dynamic>)
        ..['financeBg'] = 'desert'
        ..['glassLevel'] = 'x';
      final old = jsonEncode(m);
      final third = await newStore();
      third.setGlassLevel(0);
      expect(await third.importBackup(old), BackupResult.ok);
      expect(third.financeBg, 'sky');
      expect(third.glassLevel, 0);
    });
  });

  group('Efek kaca (tampilan)', () {
    Future<void> pumpCard(WidgetTester t, int level) async {
      final s = await newStore();
      s.setGlassLevel(level);
      await show(t, s, const Scaffold(body: Center(child: ZCard(child: Text('isi')))));
    }

    testWidgets('mati: kartu biasa tanpa blur', (t) async {
      await pumpCard(t, 0);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('isi'), findsOneWidget);
    });

    testWidgets('halus dan kuat: kartu memakai blur', (t) async {
      await pumpCard(t, 1);
      expect(find.byType(BackdropFilter), findsOneWidget);
      await pumpCard(t, 2);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('tanpa store (misalnya di tes lain): kartu tetap tampil', (t) async {
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const Scaffold(body: ZCard(child: Text('x')))));
      expect(find.text('x'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('Latar Gurun Senja', () {
    for (final dark in [false, true]) {
      for (final reduce in [false, true]) {
        testWidgets('semua halaman tergambar tanpa galat (gelap=$dark, kurangi animasi=$reduce)', (t) async {
          t.view.physicalSize = const Size(390 * 2, 844 * 2);
          t.view.devicePixelRatio = 2;
          addTearDown(t.view.reset);
          for (var tab = 0; tab < 5; tab++) {
            await t.pumpWidget(MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: reduce),
                child: Scaffold(body: DuskBackground(dark: dark, tab: tab)),
              ),
            ));
            await t.pump(const Duration(milliseconds: 500));
            await t.pump(const Duration(seconds: 2));
            expect(t.takeException(), isNull);
          }
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        });
      }
    }
  });

  group('Ringkasan target', () {
    testWidgets('menjumlah semua target: total, persen, tercapai, dan sisa', (t) async {
      final s = await newStore();
      s.goals
        ..add(Goal(id: 'a', name: 'Dana darurat', target: 10000000, saved: 6000000))
        ..add(Goal(id: 'b', name: 'Laptop baru', target: 12000000, saved: 2400000))
        ..add(Goal(id: 'c', name: 'Liburan', target: 5000000, saved: 5000000));
      await show(t, s, const Scaffold(body: GoalsPage()));
      expect(find.text('Total tabungan'), findsOneWidget);
      expect(find.text('Rp 13.400.000'), findsOneWidget);
      expect(find.text('dari Rp 27.000.000'), findsOneWidget);
      expect(find.text('50%'), findsWidgets);
      expect(find.text('1 dari 3 tercapai'), findsOneWidget);
      expect(find.text('Kurang Rp 13,6 jt'), findsOneWidget);
      expect(find.text('Bangun Masa Depanmu'), findsNothing); // teks dan gambar lama sudah dihapus
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('tabungan melebihi target tidak membuat persen lebih dari 100', (t) async {
      final s = await newStore();
      s.goals.add(Goal(id: 'a', name: 'Kecil', target: 1000000, saved: 1500000));
      await show(t, s, const Scaffold(body: GoalsPage()));
      expect(find.text('Rp 1.500.000'), findsOneWidget);
      expect(find.text('100%'), findsWidgets);
      expect(find.text('Semua tercapai'), findsOneWidget);
    });

    testWidgets('tanpa target: nol dan petunjuk membuat target', (t) async {
      final s = await newStore();
      await show(t, s, const Scaffold(body: GoalsPage()));
      expect(find.text('Rp 0'), findsOneWidget);
      expect(find.text('0%'), findsWidgets);
      expect(find.text('Belum ada target'), findsWidgets);
    });
  });

  group('Layar PIN', () {
    testWidgets('layar kunci: sapaan, nama, dan titik hijau "Terbuka" sebelum masuk', (t) async {
      SharedPreferences.setMockInitialValues({});
      final seed = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      seed.updateProfile(name: 'Budi');
      seed.setPin('123456');
      await seed.flush();
      final store = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      await show(t, store, const LockGate(child: Text('ISI-APLIKASI')));
      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('Masukkan PIN'), findsOneWidget);
      expect(find.text('Lupa PIN?'), findsOneWidget);
      await digits(t, '123456');
      expect(find.text('Terbuka'), findsOneWidget);
      expect(find.text('ISI-APLIKASI'), findsNothing); // belum: menunggu animasi sukses
      await t.pump(const Duration(milliseconds: 700));
      await t.pumpAndSettle();
      expect(find.text('ISI-APLIKASI'), findsOneWidget);
    });

    testWidgets('salah: titik merah dulu, baru kosong; ketukan saat itu diabaikan', (t) async {
      final got = <String>[];
      await show(
        t,
        await newStore(),
        PinPad(title: 'PIN', length: 4, onPin: (p) {
          got.add(p);
          return false;
        }),
      );
      await digits(t, '1111');
      expect(find.text('PIN salah'), findsOneWidget);
      await t.tap(find.text('2'));
      await t.pump();
      expect(got, ['1111']); // ketukan di tengah animasi salah tidak masuk
      await t.pump(const Duration(milliseconds: 600));
      await digits(t, '2222');
      expect(got, ['1111', '2222']);
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('sisa percobaan tampil di layar kunci saat tinggal sedikit', (t) async {
      await show(
        t,
        await newStore(),
        PinPad(
          title: 'Masukkan PIN',
          length: 4,
          triesLeft: () => 2,
          profile: const SizedBox(width: 76, height: 76),
          greetingText: 'Selamat pagi',
          nameText: 'Budi',
          onPin: (_) => false,
        ),
      );
      expect(find.text('Sisa 2 percobaan'), findsOneWidget);
    });

    testWidgets('layar buat PIN: langkah 1 lalu 2 dengan petunjuk', (t) async {
      await show(t, await newStore(), const PinSetupPage());
      expect(find.text('Buat PIN'), findsOneWidget);
      expect(find.textContaining('Hindari tanggal lahir'), findsOneWidget);
      await digits(t, '123456');
      expect(find.text('Ulangi PIN'), findsOneWidget);
      expect(find.textContaining('sekali lagi'), findsOneWidget);
    });

    testWidgets('Kunci sekarang: mengunci lagi sesi yang sudah terbuka, hanya kalau PIN aktif', (t) async {
      final s = await newStore();
      s.requestLock(); // tanpa PIN: tidak berbuat apa-apa
      expect(s.lockTick, 0);
      s.setPin('123456');
      await show(t, s, const LockGate(child: Text('ISI-APLIKASI')));
      expect(find.text('ISI-APLIKASI'), findsOneWidget);
      s.requestLock();
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('ISI-APLIKASI'), findsNothing);
      expect(find.text('Masukkan PIN'), findsOneWidget);
      await digits(t, '123456');
      await t.pump(const Duration(milliseconds: 700));
      await t.pumpAndSettle();
      expect(find.text('ISI-APLIKASI'), findsOneWidget);
    });
  });
}
