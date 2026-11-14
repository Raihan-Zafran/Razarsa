import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

/// Mengubah satu bagian acak dari struktur JSON: hapus, ganti tipe, atau isi nilai ekstrem.
void mutate(Object? node, Random r, {int depth = 0}) {
  final weird = <Object?>[null, 'x', -1, 1e30, 9223372036854775807, [], {}, true, '', 'a' * 500, 0.5];
  if (node is Map) {
    if (node.isEmpty) return;
    final k = node.keys.elementAt(r.nextInt(node.length));
    switch (r.nextInt(4)) {
      case 0:
        node.remove(k);
      case 1:
        node[k] = weird[r.nextInt(weird.length)];
      case 2:
        mutate(node[k], r, depth: depth + 1);
      default:
        node['tambahan'] = weird[r.nextInt(weird.length)];
    }
  } else if (node is List) {
    if (node.isEmpty) return;
    final i = r.nextInt(node.length);
    switch (r.nextInt(3)) {
      case 0:
        node.removeAt(i);
      case 1:
        node[i] = weird[r.nextInt(weird.length)];
      default:
        mutate(node[i], r, depth: depth + 1);
    }
  }
}

void main() {
  test('impor backup rusak tidak pernah melempar galat dan tidak merusak data yang ada', () async {
    final src = await newStore();
    src.addWallet(name: 'BRI', type: 'bank', opening: 1000);
    src.addWallet(name: 'DANA', type: 'ewallet');
    for (var i = 0; i < 12; i++) {
      src.addTxn(name: 'T$i', cat: i.isEven ? 'food' : 'salary', amount: i.isEven ? -1000 * (i + 1) : 5000, wallet: src.wallets[i % 3].id);
    }
    src.addGoal('Laptop', 5000000);
    src.setPalette(2);
    final good = src.exportJson();
    final r = Random(7);
    for (var n = 0; n < 400; n++) {
      final m = jsonDecode(good);
      for (var k = 0; k < 1 + r.nextInt(3); k++) {
        mutate(m, r);
      }
      final target = await newStore();
      target.addTxn(name: 'Asli', cat: 'food', amount: -777);
      final before = target.balance;
      final res = await target.importBackup(jsonEncode(m));
      // Kalau ditolak, data lama utuh; kalau diterima, data konsisten (sumber ada, transaksi menunjuk sumber yang ada).
      if (res != BackupResult.ok) {
        expect(target.balance, before, reason: 'iterasi $n: data lama berubah padahal ditolak ($res)');
      } else {
        expect(target.wallets, isNotEmpty);
        expect(target.wallets.length, lessThanOrEqualTo(AppStore.maxWallets));
        final ids = {for (final w in target.wallets) w.id};
        expect(target.txns.every((t) => ids.contains(t.wallet)), isTrue, reason: 'iterasi $n');
        expect(target.palette, inInclusiveRange(0, 3));
        expect(target.balance, isA<int>());
      }
    }
  });

  test('data tersimpan yang rusak (sumber, transaksi, palet) tidak menjatuhkan aplikasi saat dibuka', () async {
    final r = Random(3);
    final bad = <Object>[
      'bukan json',
      '{}',
      '[1,2,3]',
      '[{"id":"a"}]',
      '[{"id":"","name":"x","type":"bank"}]',
      '[{"id":"a","name":"  ","type":"bank"}]',
      '[{"id":"a","name":"ok","type":9,"opening":"x"}]',
      '[{"id":"a","name":"ok"},{"id":"a","name":"dobel"}]',
      '[null]',
      '',
    ];
    for (var n = 0; n < 150; n++) {
      final prefs = <String, Object>{'dataVersion': 3};
      for (final k in ['wallets', 'txns', 'goals']) {
        if (r.nextBool()) prefs[k] = bad[r.nextInt(bad.length)];
      }
      if (r.nextBool()) prefs['palette'] = r.nextBool() ? 'x' : 999;
      if (r.nextBool()) prefs['lastWallet'] = 'hantu';
      SharedPreferences.setMockInitialValues(prefs);
      final s = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      expect(s.wallets, isNotEmpty, reason: '$prefs');
      expect(s.palette, inInclusiveRange(0, 3));
      final ids = {for (final w in s.wallets) w.id};
      expect(s.txns.every((t) => ids.contains(t.wallet)), isTrue, reason: '$prefs');
      expect(ids.contains(s.defaultWallet.id), isTrue);
    }
  });
}
