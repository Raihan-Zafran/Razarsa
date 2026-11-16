import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/core/format.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/widgets/count_up.dart';

Widget host(Widget child, {bool still = false}) => MaterialApp(
      home: MediaQuery(data: MediaQueryData(disableAnimations: still), child: Scaffold(body: Center(child: child))),
    );

void main() {
  setUp(() => L.lang = 'id');

  testWidgets('CountUp: mulai dari 0, naik, berhenti tepat di nilai akhir', (t) async {
    String shown() => t.state<CountUpState>(find.byType(CountUp)).shown;
    await t.pumpWidget(host(CountUp(value: 1500000, format: rp)));
    expect(shown(), 'Rp 0');
    await t.pump(const Duration(milliseconds: 300));
    final mid = shown();
    expect(mid, isNot('Rp 0'));
    expect(mid, isNot('Rp 1.500.000'));
    await t.pump(const Duration(seconds: 1));
    expect(shown(), 'Rp 1.500.000');
    // Ukuran selalu dari nilai akhir (tidak menata ulang halaman tiap bingkai).
    expect(find.text('Rp 1.500.000'), findsOneWidget);
  });

  testWidgets('CountUp: nilai berubah -> bergeser dari nilai lama, bukan dari 0', (t) async {
    await t.pumpWidget(host(CountUp(value: 1000, format: rp)));
    await t.pump(const Duration(seconds: 2));
    await t.pumpWidget(host(CountUp(value: 2000, format: rp)));
    await t.pump(const Duration(milliseconds: 50));
    final v = int.parse(t.state<CountUpState>(find.byType(CountUp)).shown.replaceAll(RegExp(r'[^0-9]'), ''));
    expect(v, inInclusiveRange(1000, 2000));
    await t.pump(const Duration(seconds: 2));
    expect(t.state<CountUpState>(find.byType(CountUp)).shown, 'Rp 2.000');
  });

  testWidgets('CountUp: animasi dimatikan -> langsung nilai akhir', (t) async {
    await t.pumpWidget(host(CountUp(value: 750000, format: rp), still: true));
    expect(find.text('Rp 750.000'), findsOneWidget);
  });

  testWidgets('CountUp: pembaca layar mendengar nilai akhir, bukan angka berjalan', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(host(CountUp(value: 300000, format: rp)));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.bySemanticsLabel('Rp 300.000'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    h.dispose();
  });

  testWidgets('FillIn: mulai kosong lalu penuh; mati kalau animasi dimatikan', (t) async {
    double? last;
    Widget w(bool still) => host(FillIn(value: 0.6, builder: (_, v) {
          last = v;
          return const SizedBox();
        }), still: still);
    await t.pumpWidget(w(false));
    expect(last, 0);
    // Tertunda 0,3 s seperti prototipe, lalu tumbuh.
    await t.pump(const Duration(milliseconds: 200));
    expect(last, 0);
    await t.pump(const Duration(milliseconds: 300));
    expect(last, greaterThan(0));
    expect(last, lessThan(0.6));
    await t.pump(const Duration(seconds: 2));
    expect(last, closeTo(0.6, 1e-9));
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(w(true));
    expect(last, 0.6);
  });
}
