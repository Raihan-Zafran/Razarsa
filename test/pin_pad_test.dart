import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/features/security/lock.dart';

Widget host(Widget child) => MaterialApp(theme: buildTheme(Brightness.light), home: child);

Future<void> tapDigits(WidgetTester t, String digits) async {
  for (final d in digits.split('')) {
    await t.tap(find.text(d));
    await t.pump();
  }
}

void main() {
  setUp(() => L.lang = 'id');

  testWidgets('PIN 6 digit: diperiksa otomatis setelah digit ke-6, bukan ke-4', (t) async {
    final got = <String>[];
    await t.pumpWidget(host(PinPad(title: 'PIN', length: 6, onPin: (p) {
      got.add(p);
      return true;
    })));
    await tapDigits(t, '1234');
    expect(got, isEmpty);
    await tapDigits(t, '56');
    expect(got, ['123456']);
  });

  testWidgets('PIN lama 4 digit tetap diperiksa setelah digit ke-4', (t) async {
    final got = <String>[];
    await t.pumpWidget(host(PinPad(title: 'PIN', length: 4, onPin: (p) {
      got.add(p);
      return false;
    })));
    await tapDigits(t, '1234');
    expect(got, ['1234']);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('saat dikunci sementara: ketukan diabaikan dan sisa waktu ditampilkan', (t) async {
    final got = <String>[];
    await t.pumpWidget(host(PinPad(
      title: 'PIN',
      length: 4,
      lockRemaining: () => const Duration(seconds: 30),
      onPin: (p) {
        got.add(p);
        return true;
      },
    )));
    await tapDigits(t, '1234');
    expect(got, isEmpty);
    expect(find.textContaining('Terlalu banyak percobaan'), findsOneWidget);
    // Pewaktu hitung mundur dibersihkan saat widget dilepas.
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('setelah salah, papan menampilkan pesan PIN salah', (t) async {
    await t.pumpWidget(host(PinPad(title: 'PIN', length: 4, onPin: (_) => false)));
    await tapDigits(t, '9999');
    expect(find.text('PIN salah'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
  });
}
