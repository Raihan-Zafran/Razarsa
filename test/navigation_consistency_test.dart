import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/models.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/settings/manage_pages.dart';
import 'package:razarsa/shell/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

Future<void> view(WidgetTester t, AppStore s, Widget home) async {
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(StoreScope(
    store: s,
    child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
  ));
  await t.pump(const Duration(milliseconds: 800));
}

/// Memajukan animasi bertahap (latar punya animasi tanpa akhir, jadi pumpAndSettle tidak dipakai).
Future<void> step(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
  });
  setUp(() => L.lang = 'id');

  group('Tombol Kembali sistem', () {
    for (final mode in ['finance', 'productive']) {
      testWidgets('mode $mode: dari tab lain kembali ke Beranda dulu, bukan keluar aplikasi', (t) async {
        final s = await newStore();
        await view(t, s, ModeShell(mode: mode));
        final state = t.state(find.byType(ModeShell)) as dynamic;
        final home = find.text(mode == 'finance' ? 'Total Saldo' : 'Fokus Hari Ini');
        expect(home, findsOneWidget);
        state.goTo(2);
        await step(t);
        expect(home, findsNothing, reason: 'sudah pindah dari Beranda');
        final handled = await t.binding.handlePopRoute();
        await step(t);
        expect(handled, isTrue, reason: 'Kembali harus ditangani aplikasi');
        expect(home, findsOneWidget, reason: 'kembali ke Beranda, bukan keluar aplikasi');
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      });
    }

    testWidgets('dari tab terjauh (Pengaturan) juga kembali ke Beranda', (t) async {
      final s = await newStore();
      await view(t, s, const ModeShell(mode: 'finance'));
      final state = t.state(find.byType(ModeShell)) as dynamic;
      state.goTo(4);
      await step(t);
      expect(find.text('Total Saldo'), findsNothing);
      await t.binding.handlePopRoute();
      await step(t);
      expect(find.text('Total Saldo'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
  });

  group('Hapus selalu meminta konfirmasi', () {
    testWidgets('transaksi berulang: tombol sampah membuka konfirmasi; Batal menyimpan, Hapus menghapus', (t) async {
      final s = await newStore();
      s.recurring.add(Recurring(id: 'r1', name: 'Kos', cat: 'housing', amount: -800000, day: 5, lastPosted: '2026-11'));
      await view(t, s, const RecurringPage());
      await t.tap(find.byIcon(Icons.delete_outline_rounded));
      await t.pumpAndSettle();
      expect(find.text('Hapus transaksi berulang?'), findsOneWidget);
      expect(s.recurring, hasLength(1), reason: 'belum dihapus sebelum dikonfirmasi');
      await t.tap(find.text('Batal'));
      await t.pumpAndSettle();
      expect(s.recurring, hasLength(1));
      await t.tap(find.byIcon(Icons.delete_outline_rounded));
      await t.pumpAndSettle();
      await t.tap(find.text('Hapus'));
      await t.pumpAndSettle();
      expect(s.recurring, isEmpty);
    });

    testWidgets('tombol Catat Cepat: Hapus di lembar ubah meminta konfirmasi', (t) async {
      final s = await newStore();
      final before = s.quickItems.length;
      await view(t, s, const QuickItemsPage());
      await t.tap(find.text('Kopi').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Hapus'));
      await t.pumpAndSettle();
      expect(find.text('Hapus tombol?'), findsOneWidget);
      expect(s.quickItems, hasLength(before));
      await t.tap(find.text('Batal'));
      await t.pumpAndSettle();
      expect(s.quickItems, hasLength(before), reason: 'Batal tidak menghapus');
      await t.tap(find.text('Hapus'));
      await t.pumpAndSettle();
      await t.tap(find.text('Hapus').last);
      await t.pumpAndSettle();
      expect(s.quickItems, hasLength(before - 1));
    });
  });

  test('istilah seragam: "Tugas" (bukan campuran "To-do") di Indonesia dan "Tasks" di Inggris', () {
    expect(tr('Tugas'), 'Tugas');
    L.lang = 'en';
    expect(tr('Tugas'), 'Tasks');
    expect(tr('Tugas, kalender, pengingat, catatan'), 'Tasks, calendar, reminders, notes');
    L.lang = 'id';
  });
}
