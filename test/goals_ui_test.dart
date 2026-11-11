import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/finance/goals_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> seeded({int saved = 3000000}) async {
  SharedPreferences.setMockInitialValues({});
  final s = AppStore(await SharedPreferences.getInstance(), vault: testVault);
  s.addGoal('Laptop baru', 10000000);
  if (saved > 0) s.addToGoal(s.goals.single.id, saved);
  return s;
}

Future<void> show(WidgetTester t, AppStore s) async {
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(StoreScope(
    store: s,
    child: MaterialApp(theme: buildTheme(Brightness.light), home: const Scaffold(body: GoalsPage())),
  ));
  await t.pump(const Duration(milliseconds: 700));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
  });
  setUp(() => L.lang = 'id');

  testWidgets('ketuk target: tambah tabungan tetap bisa, dan ada tombol Kurangi', (t) async {
    final s = await seeded();
    await show(t, s);
    await t.tap(find.text('Laptop baru'));
    await t.pumpAndSettle();
    expect(find.text('Kurangi'), findsOneWidget);
    expect(find.textContaining('Tabungan saat ini'), findsOneWidget);
    await t.enterText(find.byType(TextField), '500000');
    await t.tap(find.text('Tambah'));
    await t.pumpAndSettle();
    expect(s.goals.single.saved, 3500000);
  });

  testWidgets('Kurangi mengurangi tabungan', (t) async {
    final s = await seeded();
    await show(t, s);
    await t.tap(find.text('Laptop baru'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '1000000');
    await t.tap(find.text('Kurangi'));
    await t.pumpAndSettle();
    expect(s.goals.single.saved, 2000000);
  });

  testWidgets('Kurangi lebih dari tabungan ditolak dengan pesan, tabungan tidak berubah', (t) async {
    final s = await seeded();
    await show(t, s);
    await t.tap(find.text('Laptop baru'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '9000000');
    await t.tap(find.text('Kurangi'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Tidak bisa mengurangi'), findsOneWidget);
    expect(s.goals.single.saved, 3000000);
  });

  testWidgets('target belum punya tabungan: tidak ada tombol Kurangi', (t) async {
    final s = await seeded(saved: 0);
    await show(t, s);
    await t.tap(find.text('Laptop baru'));
    await t.pumpAndSettle();
    expect(find.text('Kurangi'), findsNothing);
  });

  testWidgets('tekan lama: menu Ubah target / Hapus; ubah nama dan target', (t) async {
    final s = await seeded();
    await show(t, s);
    await t.longPress(find.text('Laptop baru'));
    await t.pumpAndSettle();
    expect(find.text('Ubah target'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
    await t.tap(find.text('Ubah target'));
    await t.pumpAndSettle();
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), 'Laptop kerja');
    await t.enterText(fields.at(1), '12000000');
    await t.tap(find.text('Simpan'));
    await t.pumpAndSettle();
    expect(s.goals.single.name, 'Laptop kerja');
    expect(s.goals.single.target, 12000000);
    expect(s.goals.single.saved, 3000000);
  });

  testWidgets('ubah target dengan isian kosong ditolak dan data tetap', (t) async {
    final s = await seeded();
    await show(t, s);
    await t.longPress(find.text('Laptop baru'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ubah target'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).at(1), '');
    await t.tap(find.text('Simpan'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Nama dan jumlah target harus diisi'), findsOneWidget);
    expect(s.goals.single.target, 10000000);
  });

  testWidgets('tekan lama lalu Hapus masih meminta konfirmasi dan menghapus', (t) async {
    final s = await seeded();
    await show(t, s);
    await t.longPress(find.text('Laptop baru'));
    await t.pumpAndSettle();
    await t.tap(find.text('Hapus'));
    await t.pumpAndSettle();
    expect(find.text('Hapus target?'), findsOneWidget);
    await t.tap(find.text('Hapus').last);
    await t.pumpAndSettle();
    expect(s.goals, isEmpty);
  });
}
