import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/shell/dock.dart';

void main() {
  group('Bentuk dock', () {
    const size = Size(358, 52);

    test('lekukan melingkar: kosong di dalam lingkaran, bar penuh di luarnya', () {
      for (final cx in [54.0, 116.5, 179.0, 241.5, 304.0]) {
        final p = dockPath(size, cx);
        // Pusat lingkaran lekukan (cx, 6) dan titik tepat di dalamnya berada di luar bar.
        expect(p.contains(Offset(cx, 6)), isFalse, reason: 'pusat lekukan cx=$cx');
        expect(p.contains(Offset(cx, 28)), isFalse, reason: 'dasar lekukan cx=$cx');
        // Di bawah lekukan dan di samping lekukan, bar tetap ada.
        expect(p.contains(Offset(cx, 40)), isTrue, reason: 'bawah lekukan cx=$cx');
        expect(p.contains(Offset(cx - 40, 10)), isTrue, reason: 'kiri lekukan cx=$cx');
        expect(p.contains(Offset(cx + 40, 10)), isTrue, reason: 'kanan lekukan cx=$cx');
        // Seluruh bar tetap di dalam kotaknya.
        final b = p.getBounds();
        expect(b.left, 0);
        expect(b.right, 358);
        expect(b.top, 0);
        expect(b.bottom, 52);
      }
    });

    test('simetris terhadap pusat lekukan', () {
      const cx = 179.0;
      final p = dockPath(size, cx);
      for (final dx in [5.0, 12.0, 20.0, 24.0]) {
        for (final y in [4.0, 14.0, 24.0]) {
          expect(p.contains(Offset(cx - dx, y)), p.contains(Offset(cx + dx, y)), reason: 'dx=$dx y=$y');
        }
      }
    });

    test('pusat menu berjarak sama dan simetris', () {
      final xs = [for (var i = 0; i < 5; i++) dockCenterOf(i, 5, 358)];
      expect(xs.first, 54);
      expect(xs.last, 358 - 54);
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i] - xs[i - 1], closeTo(62.5, 1e-9));
      }
    });
  });

  testWidgets('dock tergambar di tiap tab, terang dan gelap, tanpa galat', (t) async {
    for (final b in [Brightness.light, Brightness.dark]) {
      for (var i = 0; i < 5; i++) {
        await t.pumpWidget(MaterialApp(
          theme: buildTheme(b),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ZDock(
                  items: const [
                    DockItem(Icons.home_rounded, 'A'),
                    DockItem(Icons.receipt_long_rounded, 'B'),
                    DockItem(Icons.bar_chart_rounded, 'C'),
                    DockItem(Icons.flag_rounded, 'D'),
                    DockItem(Icons.settings_rounded, 'E'),
                  ],
                  index: i,
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        ));
        await t.pump(const Duration(milliseconds: 600));
        expect(t.takeException(), isNull);
      }
    }
  });

  testWidgets('mengetuk menu memanggil onTap dengan indeks yang benar', (t) async {
    var got = -1;
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 358,
            child: ZDock(
              items: const [
                DockItem(Icons.home_rounded, 'A'),
                DockItem(Icons.receipt_long_rounded, 'B'),
                DockItem(Icons.bar_chart_rounded, 'C'),
                DockItem(Icons.flag_rounded, 'D'),
                DockItem(Icons.settings_rounded, 'E'),
              ],
              index: 0,
              onTap: (i) => got = i,
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.bySemanticsLabel('D'));
    expect(got, 3);
  });
}
