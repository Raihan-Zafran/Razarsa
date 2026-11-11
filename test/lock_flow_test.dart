import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/productive_models.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/productive/notes_page.dart';
import 'package:razarsa/features/security/lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

Future<void> digits(WidgetTester t, String d) async {
  for (final c in d.split('')) {
    await t.tap(find.text(c));
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() => L.lang = 'id');

  testWidgets('PIN yang baru dibuat tidak langsung meminta PIN lagi', (t) async {
    final store = await newStore();
    await t.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const LockGate(child: Text('ISI-APLIKASI'))),
    ));
    expect(find.text('ISI-APLIKASI'), findsOneWidget);
    store.setPin('123456'); // dibuat dari Pengaturan
    await t.pump();
    expect(find.text('ISI-APLIKASI'), findsOneWidget);
    expect(find.text('Masukkan PIN'), findsNothing);
  });

  testWidgets('aplikasi dibuka dengan PIN aktif: terkunci sampai PIN benar', (t) async {
    SharedPreferences.setMockInitialValues({});
    final seed = AppStore(await SharedPreferences.getInstance(), vault: testVault)..setPin('123456');
    await seed.flush();
    final store = AppStore(await SharedPreferences.getInstance(), vault: testVault); // buka ulang
    await t.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const LockGate(child: Text('ISI-APLIKASI'))),
    ));
    expect(find.text('ISI-APLIKASI'), findsNothing);
    await digits(t, '000000');
    expect(find.text('ISI-APLIKASI'), findsNothing);
    await digits(t, '123456');
    expect(find.text('ISI-APLIKASI'), findsOneWidget);
  });

  testWidgets('catatan terkunci tanpa PIN (hasil restore di HP baru): minta buat PIN lalu terbuka', (t) async {
    final store = await newStore();
    final note = Note(id: 'n', title: 'T', body: 'isi', tone: 'amber', locked: true, updatedAt: DateTime(2026));
    store.notes.add(note);
    expect(store.pinEnabled, isFalse);
    bool? opened;
    await t.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Builder(
          builder: (c) => TextButton(onPressed: () async => opened = await NoteLock.ensure(c, note), child: const Text('BUKA')),
        ),
      ),
    ));
    await t.tap(find.text('BUKA'));
    await t.pumpAndSettle();
    expect(find.text('Buat PIN'), findsOneWidget); // bukan "Masukkan PIN" yang tak mungkin benar
    await digits(t, '654321');
    await t.pumpAndSettle();
    await digits(t, '654321');
    await t.pumpAndSettle();
    expect(opened, isTrue);
    expect(store.pinEnabled, isTrue);
    expect(store.pinLength, 6);
    expect(note.locked, isTrue); // tetap terkunci
    expect(NoteLock.isOpen(note), isTrue);
    NoteLock.closeAll();
  });

  testWidgets('membatalkan pembuatan PIN: catatan tetap terkunci', (t) async {
    final store = await newStore();
    final note = Note(id: 'n2', title: 'T', body: 'isi', tone: 'amber', locked: true, updatedAt: DateTime(2026));
    store.notes.add(note);
    bool? opened;
    await t.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Builder(
          builder: (c) => TextButton(onPressed: () async => opened = await NoteLock.ensure(c, note), child: const Text('BUKA')),
        ),
      ),
    ));
    await t.tap(find.text('BUKA'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.close_rounded));
    await t.pumpAndSettle();
    expect(opened, isFalse);
    expect(store.pinEnabled, isFalse);
    expect(NoteLock.isOpen(note), isFalse);
  });
}
