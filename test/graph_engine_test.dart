import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/data/models.dart';
import 'package:razarsa/features/saldo/graph_engine.dart';

final now = DateTime(2026, 11, 13, 12);

List<Wallet> wallets(int n) => [
      for (var i = 0; i < n; i++) Wallet(id: 'w$i', name: 'Sumber $i', type: kWalletTypes[i % 3]),
    ];

Txn tx(int i, {String wallet = 'w0', String cat = 'food', DateTime? at, int amount = -10000}) =>
    Txn(id: 't$i', name: 'n$i', cat: cat, amount: amount, at: at ?? now.subtract(Duration(minutes: i)), wallet: wallet);

String label(String id) => id;

GraphData data(List<Txn> t, List<Wallet> w, {int q = 0, DateTime? at}) =>
    buildGraphData(txns: t, wallets: w, catLabel: label, now: at ?? now, quarterOffset: q);

void main() {
  group('Data graph', () {
    test('kosong: tanpa transaksi, hanya sumber', () {
      final d = data([], wallets(2));
      expect(d.wallets.length, 2);
      expect(d.cats, isEmpty);
      expect(d.txns, isEmpty);
      expect(d.count, 0);
      final g = GraphSim.build(d);
      expect(g.empty, isTrue);
    });

    test('transaksi, kategori, sumber terhubung; sumber hanya ke kategori yang dipakainya', () {
      final w = wallets(3);
      final d = data([tx(1, wallet: 'w0', cat: 'food'), tx(2, wallet: 'w1', cat: 'food'), tx(3, wallet: 'w1', cat: 'bills')], w);
      expect(d.cats.map((c) => c.cat).toSet(), {'food', 'bills'});
      expect(d.links.where((l) => l.walletToCat).length, 3); // w0-food, w1-food, w1-bills
      expect(d.cats.length, 2); // kategori dipakai bersama
      expect(d.wallets.firstWhere((n) => n.walletId == 'w2').cnt, 0);
    });

    test('maksimal 200 transaksi: yang terbaru dipertahankan, sisanya jadi riwayat', () {
      final list = [for (var i = 0; i < 260; i++) tx(i)];
      final d = data(list, wallets(1));
      expect(d.txns.length, 200);
      expect(d.count, 200);
      expect(d.txns.any((n) => n.txn!.id == 't0'), isTrue); // terbaru
      expect(d.txns.any((n) => n.txn!.id == 't259'), isFalse); // terlama tertimpa
      expect(d.history.length, 60);
    });

    test('riwayat dibatasi 90 titik', () {
      final list = [for (var i = 0; i < 400; i++) tx(i)];
      final d = data(list, wallets(1));
      expect(d.history.length, kGraphMaxHistory);
    });

    test('maksimal 50 kategori; selebihnya (paling jarang) digabung ke "Lainnya"', () {
      final list = <Txn>[];
      for (var c = 0; c < 70; c++) {
        // kategori kecil punya 1 transaksi; k0..k9 punya 3
        for (var j = 0; j < (c < 10 ? 3 : 1); j++) {
          list.add(tx(c * 10 + j, cat: 'k$c'));
        }
      }
      final d = data(list, wallets(1));
      expect(d.cats.length, 50);
      expect(d.cats.where((c) => c.cat == '_more').length, 1);
      expect(d.cats.firstWhere((c) => c.cat == '_more').label, 'Lainnya');
      expect(d.txns.length, list.length); // tidak ada transaksi hilang
      expect(d.cats.where((c) => c.cat == 'k0').length, 1); // yang ramai tetap berdiri sendiri
    });

    test('tepat 50 kategori: tidak ada yang digabung', () {
      final list = [for (var c = 0; c < 50; c++) tx(c, cat: 'k$c')];
      final d = data(list, wallets(1));
      expect(d.cats.length, 50);
      expect(d.cats.any((c) => c.cat == '_more'), isFalse);
    });

    test('maksimal 10 sumber', () {
      final d = data([], wallets(14));
      expect(d.wallets.length, 10);
    });

    test('hanya kuartal kalender berjalan; kuartal lain jadi arsip', () {
      final list = [
        tx(1, at: DateTime(2026, 11, 1)), // Q4 2026
        tx(2, at: DateTime(2026, 10, 1)), // Q4 2026
        tx(3, at: DateTime(2026, 9, 30)), // Q3
        tx(4, at: DateTime(2026, 7, 1)), // Q3
        tx(5, at: DateTime(2025, 12, 31)), // Q4 2025
      ];
      final w = wallets(1);
      final q0 = data(list, w);
      expect((q0.year, q0.quarter), (2026, 3));
      expect(q0.txns.length, 2);
      expect(q0.canPrev, isTrue);
      expect(q0.canNext, isFalse);
      expect(q0.history.length, 3); // tetap tersimpan, tampil sebagai riwayat
      final q1 = data(list, w, q: -1);
      expect((q1.year, q1.quarter), (2026, 2));
      expect(q1.txns.map((n) => n.txn!.id).toSet(), {'t3', 't4'});
      expect(q1.canNext, isTrue);
      final q3 = data(list, w, q: -4);
      expect((q3.year, q3.quarter), (2025, 3));
      expect(q3.txns.map((n) => n.txn!.id), ['t5']);
      expect(q3.canPrev, isFalse); // tidak ada yang lebih lama
      expect(data(list, w, q: 5).canNext, isFalse); // offset positif dianggap 0
    });

    test('pergantian kuartal: tanggal 1 Januari/April mulai rasi baru', () {
      final list = [tx(1, at: DateTime(2026, 12, 31, 23, 59)), tx(2, at: DateTime(2027, 1, 1))];
      final w = wallets(1);
      final dec = data(list, w, at: DateTime(2026, 12, 31, 23, 59));
      expect(dec.txns.map((n) => n.txn!.id), ['t1']);
      final jan = data(list, w, at: DateTime(2027, 1, 1));
      expect(jan.txns.map((n) => n.txn!.id), ['t2']);
      expect((jan.year, jan.quarter), (2027, 0));
      expect(jan.canPrev, isTrue);
    });

    test('transaksi ke sumber yang sudah tidak ada diabaikan, tidak membuat galat', () {
      final d = data([tx(1, wallet: 'hantu'), tx(2)], wallets(1));
      expect(d.txns.length, 1);
    });

    test('jumlah nol, minus, dan 13 digit tidak merusak', () {
      final d = data([tx(1, amount: 0), tx(2, amount: -9999999999999), tx(3, amount: 1000000000000)], wallets(1));
      final g = GraphSim.build(d);
      expect(g.nodes.length, 1 + 1 + 3);
      for (final n in g.nodes) {
        expect(n.x.isFinite && n.y.isFinite, isTrue);
      }
    });

    test('urutan deterministik: dua kali bangun hasilnya sama', () {
      final list = [for (var i = 0; i < 80; i++) tx(i, cat: 'k${i % 7}', wallet: 'w${i % 3}')];
      final a = GraphSim.build(data(list, wallets(3)));
      final b = GraphSim.build(data(list, wallets(3)));
      for (var i = 0; i < a.nodes.length; i++) {
        expect(a.nodes[i].id, b.nodes[i].id);
        expect(a.nodes[i].x, closeTo(b.nodes[i].x, 1e-9));
        expect(a.nodes[i].y, closeTo(b.nodes[i].y, 1e-9));
      }
    });

    test('catatan yang sama jam: urutan tetap deterministik', () {
      final at = DateTime(2026, 11, 2, 8);
      final list = [for (var i = 0; i < 260; i++) tx(i, at: at)];
      final a = data(list, wallets(1)).txns.map((n) => n.txn!.id).toList();
      final b = data(list, wallets(1)).txns.map((n) => n.txn!.id).toList();
      expect(a, b);
      expect(a.length, 200);
    });
  });

  group('Simulasi', () {
    GraphSim full() {
      final list = <Txn>[];
      for (var i = 0; i < 200; i++) {
        list.add(tx(i, wallet: 'w${i % 10}', cat: 'k${i % 50}'));
      }
      return GraphSim.build(data(list, wallets(10)));
    }

    test('beban maksimum (10 sumber, 50 kategori, 200 transaksi): semua titik dalam batas, tanpa NaN', () {
      final g = full();
      expect(g.data.wallets.length, 10);
      expect(g.data.cats.length, 50);
      expect(g.data.txns.length, 200);
      for (final n in g.nodes) {
        expect(n.x.isFinite && n.y.isFinite, isTrue, reason: n.id);
        expect(n.x, inInclusiveRange(58, kGraphW - 58));
        expect(n.y, inInclusiveRange(52, kGraphH - 72));
      }
      // makin banyak titik, makin kecil
      expect(g.scale, lessThan(0.55));
    });

    test('beban maksimum: satu langkah cukup ringan', () {
      final g = full();
      final sw = Stopwatch()..start();
      for (var i = 0; i < 60; i++) {
        g.step();
      }
      sw.stop();
      // 60 langkah (~1 detik animasi) harus jauh di bawah 1 detik di mesin tes.
      expect(sw.elapsedMilliseconds, lessThan(1500));
    });

    test('mereda: alpha turun dan akhirnya diam', () {
      final g = full();
      var n = 0;
      while (!g.settled && n < 3000) {
        g.step();
        n++;
      }
      expect(g.settled, isTrue);
      expect(n, lessThan(1500));
    });

    test('sumber dikelompokkan per jenis: bank di kiri, e-wallet di kanan, tunai di bawah', () {
      final w = [
        Wallet(id: 'b', name: 'BRI', type: 'bank'),
        Wallet(id: 'e', name: 'DANA', type: 'ewallet'),
        Wallet(id: 'c', name: 'Tunai', type: 'cash'),
      ];
      final g = GraphSim.build(data([tx(1, wallet: 'b'), tx(2, wallet: 'e'), tx(3, wallet: 'c')], w));
      for (var i = 0; i < 300; i++) {
        g.step();
      }
      final bank = g.byId['w:b']!, ew = g.byId['w:e']!, cash = g.byId['w:c']!;
      expect(bank.x, lessThan(ew.x));
      expect(cash.y, greaterThan(bank.y));
    });

    test('titik lama mempertahankan posisi saat data bertambah', () {
      final list = [for (var i = 0; i < 20; i++) tx(i, cat: 'k${i % 3}')];
      final a = GraphSim.build(data(list, wallets(1)));
      final x0 = a.byId['t:t5']!.x;
      final more = [...list, tx(99)];
      final b = GraphSim.build(data(more, wallets(1)), previous: a, t: 5);
      expect((b.byId['t:t5']!.x - x0).abs(), lessThan(40));
      expect(b.byId['t:t99']!.born, 5);
      expect(b.byId['t:t5']!.born, a.byId['t:t5']!.born);
    });

    test('pilih titik: sumber menyalakan transaksi dan kategorinya, tidak sumber lain', () {
      final g = GraphSim.build(data([tx(1, wallet: 'w0', cat: 'food'), tx(2, wallet: 'w1', cat: 'food'), tx(3, wallet: 'w1', cat: 'bills')], wallets(2)));
      final s = g.neighbors('w:w0')!;
      expect(s, containsAll(['w:w0', 'c:food', 't:t1']));
      expect(s.contains('w:w1'), isFalse);
      expect(s.contains('t:t2'), isFalse);
      final c = g.neighbors('c:food')!;
      expect(c, containsAll(['c:food', 't:t1', 't:t2', 'w:w0', 'w:w1']));
      expect(c.contains('t:t3'), isFalse);
      final t = g.neighbors('t:t3')!;
      expect(t, {'t:t3', 'c:bills', 'w:w1'});
      expect(g.neighbors('tidak-ada'), isNull);
    });

    test('sentuhan: kena titik sumber, meleset di ruang kosong', () {
      final g = GraphSim.build(data([tx(1)], wallets(1)));
      final w = g.byId['w:w0']!;
      expect(g.hit(w.x, w.y), same(w));
      expect(g.hit(w.x + 3, w.y - 2), same(w));
      expect(g.hit(5, 5), isNull);
    });

    test('titik terkunci (sedang digeser) tidak ikut bergerak', () {
      final g = GraphSim.build(data([tx(1), tx(2)], wallets(1)));
      final w = g.byId['w:w0']!;
      w.pin = true;
      w.x = 100;
      w.y = 100;
      g.alpha = 1;
      for (var i = 0; i < 20; i++) {
        g.step();
      }
      expect(w.x, 100);
      expect(w.y, 100);
    });

    test('riwayat: titik redup berada di tepi luar', () {
      final g = GraphSim.build(data([for (var i = 0; i < 230; i++) tx(i)], wallets(1)));
      expect(g.history.length, 30);
      for (final h in g.history) {
        final r = math.sqrt(math.pow(h.x - kGraphW / 2, 2) + math.pow(h.y - kGraphH / 2, 2));
        expect(r, inInclusiveRange(133, 161));
      }
    });
  });
}
