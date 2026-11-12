import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/models.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/finance/goals_page.dart';
import 'package:razarsa/shell/app_shell.dart';
import 'package:razarsa/shell/sky_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> newStore([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

Future<void> show(WidgetTester t, AppStore s, Widget home, {bool disableAnimations = false}) async {
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(StoreScope(
    store: s,
    child: MaterialApp(
      theme: buildTheme(Brightness.light),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations), child: child!),
      home: home,
    ),
  ));
  await t.pump(const Duration(milliseconds: 900));
}

Txn txn(String id, int amount, DateTime at) => Txn(id: id, name: id, cat: amount < 0 ? 'food' : 'salary', amount: amount, at: at);

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
  });
  setUp(() => L.lang = 'id');

  group('Data untuk desain baru', () {
    test('balanceSeries: saldo akhir tiap hari, termasuk transaksi sebelum jendela', () async {
      final s = await newStore();
      s.txns
        ..add(txn('a', 500, DateTime(2026, 10, 20, 9)))
        ..add(txn('b', 1000, DateTime(2026, 11, 5, 9)))
        ..add(txn('c', -300, DateTime(2026, 11, 12, 8)));
      final v = s.balanceSeries(12, DateTime(2026, 11, 12, 15));
      expect(v.length, 12);
      expect(v.first, 500); // 1 Nov
      expect(v[3], 500); // 4 Nov
      expect(v[4], 1500); // 5 Nov
      expect(v[10], 1500); // 11 Nov
      expect(v.last, 1200); // 12 Nov
    });

    test('balanceSeries kosong: semua nol', () async {
      final s = await newStore();
      expect(s.balanceSeries(12), List.filled(12, 0));
    });

    test('dailyExpense: hanya pengeluaran dalam 14 hari, hari ini paling akhir', () async {
      final s = await newStore();
      s.txns
        ..add(txn('old', -999, DateTime(2026, 10, 29, 9))) // di luar jendela
        ..add(txn('first', -100, DateTime(2026, 10, 30, 9)))
        ..add(txn('in', 777, DateTime(2026, 11, 3, 9))) // pemasukan diabaikan
        ..add(txn('today1', -200, DateTime(2026, 11, 12, 8)))
        ..add(txn('today2', -100, DateTime(2026, 11, 12, 20)));
      final v = s.dailyExpense(14, DateTime(2026, 11, 12, 15));
      expect(v.length, 14);
      expect(v.first, 100);
      expect(v[4], 0);
      expect(v.last, 300);
    });

    test('perkiraan target: dari tabungan 90 hari terakhir', () {
      final now = DateTime(2026, 11, 12);
      final g = Goal(id: 'g', name: 'Laptop', target: 1500000, saved: 600000);
      expect(g.monthlyRate(now), isNull, reason: 'belum ada riwayat menabung');
      expect(g.eta(now), isNull);
      g.addLog(now.subtract(const Duration(days: 60)), 300000);
      g.addLog(now.subtract(const Duration(days: 30)), 300000);
      // 600 rb dalam 60 hari = 300 rb per bulan; kurang 900 rb = 3 bulan lagi.
      expect(g.monthlyRate(now), 300000);
      expect(g.eta(now), DateTime(2027, 2));
    });

    test('perkiraan target: tidak ada kalau ditarik, sudah tercapai, atau riwayat terlalu lama', () {
      final now = DateTime(2026, 11, 12);
      final withdrawn = Goal(id: 'g', name: 'A', target: 1000, saved: 100)
        ..addLog(now.subtract(const Duration(days: 10)), 500)
        ..addLog(now.subtract(const Duration(days: 5)), -500);
      expect(withdrawn.eta(now), isNull);
      final done = Goal(id: 'g', name: 'B', target: 1000, saved: 1000)..addLog(now, 1000);
      expect(done.eta(now), isNull);
      final stale = Goal(id: 'g', name: 'C', target: 1000, saved: 100)..addLog(now.subtract(const Duration(days: 200)), 100);
      expect(stale.monthlyRate(now), isNull);
    });

    test('menabung dan menarik tercatat; riwayat ikut tersimpan dan terbaca lagi', () async {
      final s = await newStore();
      s.addGoal('Dana darurat', 10000000);
      final id = s.goals.single.id;
      s.addToGoal(id, 400000);
      expect(s.withdrawFromGoal(id, 100000), isTrue);
      expect(s.goals.single.log.map((e) => e.delta), [400000, -100000]);
      final back = Goal.fromJson(s.goals.single.toJson());
      expect(back.log.map((e) => e.delta), [400000, -100000]);
      expect(back.saved, 300000);
    });

    test('data target lama tanpa riwayat tetap terbaca; riwayat rusak dilewati', () {
      final old = Goal.fromJson({'id': '1', 'name': 'Lama', 'target': 1000, 'saved': 10, 'tone': 'green'});
      expect(old.log, isEmpty);
      final bad = Goal.fromJson({
        'id': '2',
        'name': 'Rusak',
        'target': 1000,
        'saved': 10,
        'log': [
          [1700000000000, 500],
          'bukan daftar',
          [1, 2, 3],
          ['x', 5],
          [-5, 5],
          [1700000000000, 99999999999999],
        ],
      });
      expect(bad.log.length, 1);
      expect(bad.log.single.delta, 500);
    });

    test('riwayat tabungan dibatasi jumlahnya', () {
      final g = Goal(id: 'g', name: 'A', target: 1000);
      for (var i = 0; i < Goal.maxLog + 30; i++) {
        g.addLog(DateTime(2026, 1, 1).add(Duration(days: i)), 1);
      }
      expect(g.log.length, Goal.maxLog);
    });
  });

  group('Tampilan desain baru', () {
    testWidgets('toggle mode: dua ikon, satu ketukan langsung ganti mode', (t) async {
      final s = await newStore({'loggedIn': true});
      await show(t, s, const ModeShell(mode: 'finance'));
      expect(find.byTooltip('Keuangan'), findsOneWidget);
      expect(find.byTooltip('Produktif'), findsOneWidget);
      expect(find.text('Keuangan'), findsNothing, reason: 'toggle tanpa teks');
      expect(s.mode, 'finance');
      await t.tap(find.byTooltip('Keuangan')); // sudah aktif: tidak terjadi apa-apa
      await t.pump(const Duration(milliseconds: 300));
      expect(s.mode, 'finance');
      await t.tap(find.byTooltip('Produktif'));
      await t.pump(const Duration(milliseconds: 300));
      expect(s.mode, 'productive');
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('grafik saldo: sentuh menampilkan saldo harian', (t) async {
      final s = await newStore({'loggedIn': true});
      s.txns.add(txn('gaji', 5000000, DateTime.now()));
      final handle = t.ensureSemantics();
      await show(t, s, const ModeShell(mode: 'finance'));
      final spark = find.bySemanticsLabel('Saldo 12 hari terakhir');
      expect(spark, findsOneWidget);
      expect(find.textContaining(' · Rp'), findsNothing);
      final g = await t.startGesture(t.getTopLeft(spark) + const Offset(82, 24)); // ujung kanan = hari ini
      await t.pump(const Duration(milliseconds: 150)); // jeda tekan standar sebelum "tap down"
      expect(find.textContaining(' · Rp 5.000.000'), findsOneWidget);
      await g.up();
      await t.pump();
      expect(find.textContaining(' · Rp'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
      handle.dispose();
    });

    testWidgets('kartu target: perkiraan selesai dari kebiasaan menabung', (t) async {
      final s = await newStore();
      s.addGoal('Laptop baru', 10000000);
      s.addToGoal(s.goals.single.id, 3000000);
      await show(t, s, const Scaffold(body: GoalsPage()));
      expect(find.textContaining('jika menabung Rp 3 jt/bulan'), findsOneWidget);
      expect(find.textContaining('Rp 3.000.000 dari Rp 10.000.000'), findsOneWidget);
    });

    testWidgets('kartu target: tanpa riwayat menabung tampil sisa yang kurang; tercapai tampil "Target tercapai"', (t) async {
      final s = await newStore();
      s.goals
        ..add(Goal(id: 'a', name: 'Belum menabung', target: 1000000))
        ..add(Goal(id: 'b', name: 'Selesai', target: 500000, saved: 500000));
      await show(t, s, const Scaffold(body: GoalsPage()));
      expect(find.text('Kurang Rp 1.000.000'), findsOneWidget);
      expect(find.text('Target tercapai'), findsOneWidget);
      expect(find.textContaining('jika menabung'), findsNothing);
    });

    testWidgets('kartu Fokus: daftar sisa tugas hari ini, ketuk lingkaran untuk menyelesaikan', (t) async {
      final s = await newStore({'loggedIn': true, 'mode': 'productive'});
      s.addTodo('Belajar', cat: 'Kuliah', tone: 'purple', due: DateTime.now());
      final handle = t.ensureSemantics();
      await show(t, s, const ModeShell(mode: 'productive'));
      expect(find.text('tugas tersisa hari ini'), findsOneWidget);
      expect(find.text('Belajar'), findsWidgets);
      await t.tap(find.bySemanticsLabel('Tandai selesai: Belajar').first);
      await t.pump(const Duration(milliseconds: 300));
      expect(s.todos.single.done, isTrue);
      expect(find.text('tugas hari ini selesai'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
      handle.dispose();
    });

    testWidgets('Pengaturan dengan ikon polos tampil tanpa galat', (t) async {
      final s = await newStore({'loggedIn': true});
      await show(t, s, const ModeShell(mode: 'finance'));
      final state = t.state(find.byType(ModeShell)) as dynamic;
      state.goTo(4);
      await t.pump(const Duration(milliseconds: 900));
      expect(find.text('Tampilan'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
  });

  group('Transisi stagger', () {
    testWidgets('elemen muncul bertahap: opacity naik, lalu penuh', (t) async {
      await t.pumpWidget(const MaterialApp(
        home: PageStagger(child: StaggerItem(index: 3, child: Text('x'))),
      ));
      double opacity() => t.widget<Opacity>(find.byType(Opacity)).opacity;
      expect(opacity(), 0);
      await t.pump(const Duration(milliseconds: 100));
      expect(opacity(), lessThan(0.2), reason: 'elemen ke-4 menunggu 180 ms');
      await t.pump(const Duration(milliseconds: 800));
      expect(opacity(), 1);
    });

    testWidgets('"kurangi animasi": langsung tampil tanpa animasi', (t) async {
      await t.pumpWidget(const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: PageStagger(child: StaggerItem(index: 3, child: Text('x'))),
        ),
      ));
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('x'), findsOneWidget);
    });

    testWidgets('hanya 7 elemen pertama yang dianimasikan', (t) async {
      late BuildContext ctx;
      await t.pumpWidget(MaterialApp(
        home: PageStagger(child: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })),
      ));
      final items = staggered(ctx, [for (var i = 0; i < 10; i++) Text('t$i')]);
      expect(items.whereType<StaggerItem>().length, StaggerItem.maxItems);
      expect(items.length, 10);
    });
  });

  group('Latar Langit', () {
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
                child: Scaffold(body: SkyBackground(dark: dark, tab: tab)),
              ),
            ));
            await t.pump(const Duration(milliseconds: 500));
            await t.pump(const Duration(seconds: 2));
            expect(tester(t), isNull);
          }
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        });
      }
    }
  });
}

/// Mengambil galat yang tertangkap selama tes (null kalau tidak ada).
Object? tester(WidgetTester t) => t.takeException();
