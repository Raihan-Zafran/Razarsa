import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/widgets/common.dart';

Widget host({String? action}) => MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () => showZToast(c, 'Parkir Rp 5 rb dicatat', actionLabel: action, onAction: () {}),
            child: const Text('CATAT'),
          ),
        ),
      ),
    );

/// Memajukan waktu bertahap (frame demi frame) seperti di perangkat nyata: 6 detik,
/// jauh lebih lama dari durasi pop up (2 dtk) + animasinya.
Future<void> waitOut(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  testWidgets('pop up tanpa tombol hilang sendiri', (t) async {
    await t.pumpWidget(host());
    await t.tap(find.text('CATAT'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Parkir Rp 5 rb dicatat'), findsOneWidget);
    await waitOut(t);
    expect(find.text('Parkir Rp 5 rb dicatat'), findsNothing);
  });

  testWidgets('pop up dengan tombol "Batalkan" (Catat Cepat) juga hilang sendiri', (t) async {
    await t.pumpWidget(host(action: 'Batalkan'));
    await t.tap(find.text('CATAT'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Batalkan'), findsOneWidget);
    await waitOut(t);
    expect(find.text('Parkir Rp 5 rb dicatat'), findsNothing);
    expect(find.text('Batalkan'), findsNothing);
  });

  testWidgets('pop up baru menggantikan yang lama, bukan menumpuk', (t) async {
    await t.pumpWidget(host(action: 'Batalkan'));
    await t.tap(find.text('CATAT'));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('CATAT'));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Parkir Rp 5 rb dicatat'), findsOneWidget);
    await waitOut(t);
    expect(find.text('Parkir Rp 5 rb dicatat'), findsNothing);
  });
}
