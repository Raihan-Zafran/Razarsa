import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/core/palettes.dart';
import 'package:razarsa/data/models.dart';
import 'package:razarsa/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> newStore([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

void main() {
  group('Sumber saldo', () {
    test('pengguna baru punya satu sumber bawaan "Tunai"', () async {
      final s = await newStore();
      expect(s.wallets.length, 1);
      expect(s.wallets.first.id, kDefaultWalletId);
      expect(s.wallets.first.type, 'cash');
      expect(s.balance, 0);
    });

    test('data lama (tanpa sumber) pindah ke Tunai dan total tidak berubah', () async {
      final old = jsonEncode([
        {'id': 'a', 'name': 'Gaji', 'cat': 'salary', 'amount': 5000000, 'at': '2026-01-05T08:00:00.000'},
        {'id': 'b', 'name': 'Kopi', 'cat': 'food', 'amount': -25000, 'at': '2026-01-06T08:00:00.000'},
      ]);
      final s = await newStore({'dataVersion': 2, 'txns': old});
      expect(s.balance, 4975000);
      expect(s.wallets.single.id, kDefaultWalletId);
      expect(s.txns.every((t) => t.wallet == kDefaultWalletId), isTrue);
      expect(s.walletBalance(kDefaultWalletId), 4975000);
    });

    test('tambah sumber: nama ganda (beda huruf besar/spasi) ditolak, nama kosong ditolak', () async {
      final s = await newStore();
      expect(s.addWallet(name: 'BRI', type: 'bank'), WalletResult.ok);
      expect(s.addWallet(name: ' bri ', type: 'bank'), WalletResult.duplicate);
      expect(s.addWallet(name: 'B  R  I', type: 'bank'), WalletResult.ok); // spasi dirapikan, beda nama
      expect(s.addWallet(name: '   ', type: 'bank'), WalletResult.invalid);
      expect(s.addWallet(name: 'X', type: 'aneh'), WalletResult.invalid);
      expect(s.addWallet(name: 'tunai', type: 'cash'), WalletResult.duplicate); // bawaan
    });

    test('nama dipotong 24 huruf', () async {
      final s = await newStore();
      s.addWallet(name: 'A' * 60, type: 'bank');
      expect(s.wallets.last.name.length, 24);
    });

    test('maksimal 10 sumber', () async {
      final s = await newStore();
      for (var i = 1; i < 10; i++) {
        expect(s.addWallet(name: 'Bank $i', type: 'bank'), WalletResult.ok);
      }
      expect(s.wallets.length, 10);
      expect(s.addWallet(name: 'Kesebelas', type: 'bank'), WalletResult.full);
      expect(s.wallets.length, 10);
    });

    test('ubah nama: ganda ditolak, nama sendiri boleh, kosong ditolak', () async {
      final s = await newStore();
      s.addWallet(name: 'BCA', type: 'bank');
      final id = s.wallets.last.id;
      expect(s.renameWallet(id, 'tunai'), WalletResult.duplicate);
      expect(s.renameWallet(id, 'BCA'), WalletResult.ok);
      expect(s.renameWallet(id, ' '), WalletResult.invalid);
      expect(s.renameWallet('tidak-ada', 'Z'), WalletResult.invalid);
      expect(s.renameWallet(id, 'Mandiri'), WalletResult.ok);
      expect(s.walletName(id), 'Mandiri');
    });

    test('atur saldo: boleh minus dan nol; angka raksasa ditolak', () async {
      final s = await newStore();
      expect(s.setWalletBalance('cash', -250000), isTrue);
      expect(s.balance, -250000);
      expect(s.setWalletBalance('cash', 0), isTrue);
      expect(s.balance, 0);
      expect(s.setWalletBalance('cash', AppStore.maxAmount), isTrue);
      expect(s.setWalletBalance('cash', AppStore.maxAmount + 1), isFalse);
      expect(s.balance, AppStore.maxAmount);
      expect(s.setWalletBalance('nope', 1), isFalse);
    });

    test('atur saldo memperhitungkan transaksi yang sudah ada', () async {
      final s = await newStore();
      s.addTxn(name: 'Makan', cat: 'food', amount: -30000);
      expect(s.setWalletBalance('cash', 100000), isTrue);
      expect(s.walletBalance('cash'), 100000);
      expect(s.wallets.first.opening, 130000);
    });

    test('catat transaksi ke sumber tertentu; sumber terakhir diingat', () async {
      final s = await newStore();
      s.addWallet(name: 'DANA', type: 'ewallet');
      final dana = s.wallets.last.id;
      s.addTxn(name: 'Bakso', cat: 'food', amount: -20000, wallet: dana);
      expect(s.lastWallet, dana);
      expect(s.defaultWallet.id, dana);
      s.addTxn(name: 'Kopi', cat: 'food', amount: -10000); // tanpa pilihan: pakai yang terakhir
      expect(s.txns.last.wallet, dana);
      expect(s.walletBalance(dana), -30000);
      expect(s.walletBalance('cash'), 0);
      expect(s.balance, -30000);
      s.addTxn(name: 'Lama', cat: 'food', amount: -1, wallet: 'tidak-ada'); // sumber hilang: jatuh ke bawaan
      expect(s.walletById(s.txns.last.wallet), isNotNull);
    });

    test('hapus sumber memindahkan transaksi dan saldo awal; total tetap', () async {
      final s = await newStore();
      s.addWallet(name: 'BNI', type: 'bank', opening: 1000000);
      final bni = s.wallets.last.id;
      s.addTxn(name: 'Belanja', cat: 'shopping', amount: -250000, wallet: bni);
      final before = s.balance;
      expect(s.deleteWallet(bni), isTrue);
      expect(s.balance, before);
      expect(s.wallets.length, 1);
      expect(s.txns.single.wallet, 'cash');
      expect(s.lastWallet, '');
    });

    test('sumber terakhir tidak bisa dihapus', () async {
      final s = await newStore();
      expect(s.deleteWallet('cash'), isFalse);
      expect(s.wallets.length, 1);
    });

    test('total saldo = jumlah saldo semua sumber, termasuk minus', () async {
      final s = await newStore();
      s.addWallet(name: 'Kartu', type: 'bank');
      s.setWalletBalance(s.wallets.last.id, -500000);
      s.setWalletBalance('cash', 200000);
      expect(s.balance, -300000);
    });

    test('simpan lalu muat ulang membawa sumber, transaksi, sumber terakhir, palet', () async {
      final s = await newStore();
      s.addWallet(name: 'OVO', type: 'ewallet', opening: 5000);
      final ovo = s.wallets.last.id;
      s.addTxn(name: 'Es', cat: 'food', amount: -7000, wallet: ovo);
      s.setPalette(2);
      await s.flush();
      final back = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      expect(back.wallets.map((w) => w.name), ['Tunai', 'OVO']);
      expect(back.txns.single.wallet, ovo);
      expect(back.lastWallet, ovo);
      expect(back.palette, 2);
      expect(back.balance, -2000);
    });

    test('backup: sumber ikut, impor memulihkan, file dengan sumber ganda/terlalu banyak ditolak', () async {
      final s = await newStore();
      s.addWallet(name: 'GoPay', type: 'ewallet', opening: 100);
      s.addTxn(name: 'Ojek', cat: 'transport', amount: -9000, wallet: s.wallets.last.id);
      final file = s.exportJson();
      final other = await newStore();
      expect(await other.importBackup(file), BackupResult.ok);
      expect(other.wallets.map((w) => w.name), ['Tunai', 'GoPay']);
      expect(other.balance, s.balance);

      Future<BackupResult> tamper(void Function(Map<String, dynamic>) f) async {
        final m = jsonDecode(file) as Map<String, dynamic>;
        f(m);
        return (await newStore()).importBackup(jsonEncode(m));
      }

      // Sumber ganda (id sama) disatukan, bukan membuat dua.
      final dup = await newStore();
      final m2 = jsonDecode(file) as Map<String, dynamic>;
      (m2['wallets'] as List).add((m2['wallets'] as List).first);
      expect(await dup.importBackup(jsonEncode(m2)), BackupResult.ok);
      expect(dup.wallets.length, 2);
      // Dua sumber dengan nama sama ditolak.
      expect(
        await tamper((m) => (m['wallets'] as List).add({'id': 'zz', 'name': 'gopay', 'type': 'bank', 'opening': 0})),
        isNot(BackupResult.ok),
      );
      expect(
        await tamper((m) {
          final l = m['wallets'] as List;
          for (var i = 0; i < 12; i++) {
            l.add({'id': 'x$i', 'name': 'N$i', 'type': 'bank', 'opening': 0});
          }
        }),
        isNot(BackupResult.ok),
      );
    });

    test('backup lama (tanpa sumber) tetap bisa dipulihkan ke sumber bawaan', () async {
      final s = await newStore();
      s.addTxn(name: 'A', cat: 'food', amount: -100);
      final m = jsonDecode(s.exportJson()) as Map<String, dynamic>..remove('wallets');
      for (final t in m['txns'] as List) {
        (t as Map).remove('w');
      }
      final other = await newStore();
      expect(await other.importBackup(jsonEncode(m)), BackupResult.ok);
      expect(other.balance, -100);
      expect(other.wallets.single.id, 'cash');
    });

    test('sumber di backup yang rusak: transaksi menunjuk sumber hilang dipindah ke sumber pertama', () async {
      final s = await newStore();
      s.addTxn(name: 'A', cat: 'food', amount: -100);
      final m = jsonDecode(s.exportJson()) as Map<String, dynamic>;
      (m['txns'] as List).first['w'] = 'hantu';
      final other = await newStore();
      expect(await other.importBackup(jsonEncode(m)), BackupResult.ok);
      expect(other.walletById(other.txns.single.wallet), isNotNull);
      expect(other.balance, -100);
    });

    test('hapus semua data mengembalikan satu sumber bawaan', () async {
      final s = await newStore();
      s.addWallet(name: 'BCA', type: 'bank');
      await s.clearAll();
      expect(s.wallets.single.id, 'cash');
      expect(s.lastWallet, '');
    });

    test('hapus kategori: transaksi tetap di sumbernya', () async {
      final s = await newStore();
      s.addWallet(name: 'BCA', type: 'bank');
      final bca = s.wallets.last.id;
      s.addCustomCategory('Hobi', income: false);
      final cat = s.customCats.last.id;
      s.addTxn(name: 'Cat', cat: cat, amount: -5000, wallet: bca);
      s.removeCustomCategory(cat);
      expect(s.txns.single.wallet, bca);
    });

    test('CSV memuat kolom sumber sebelum jumlah', () async {
      final s = await newStore();
      s.addWallet(name: 'DANA', type: 'ewallet');
      s.addTxn(name: 'Bakso', cat: 'food', amount: -1000, wallet: s.wallets.last.id);
      final csv = s.exportCsv();
      expect(csv.split('\n').first, 'tanggal,jenis,kategori,catatan,sumber,jumlah');
      expect(csv, contains(',"DANA",-1000'));
    });

    test('Wallet.fromJson menolak id/nama kosong dan merapikan nilai aneh', () {
      expect(() => Wallet.fromJson({'id': '', 'name': 'x'}), throwsFormatException);
      expect(() => Wallet.fromJson({'id': 'a', 'name': '  '}), throwsFormatException);
      final w = Wallet.fromJson({'id': 'a', 'name': 'x' * 40, 'type': 'zzz', 'opening': 1e30});
      expect(w.name.length, 24);
      expect(w.type, 'bank');
      expect(w.opening, 1000000000000);
    });
  });

  group('Palet', () {
    test('bawaan Zamrud; indeks rusak kembali ke bawaan; pilihan tersimpan', () async {
      expect((await newStore()).palette, kDefaultPalette);
      expect((await newStore({'palette': 99})).palette, kDefaultPalette);
      expect((await newStore({'palette': 'x'})).palette, kDefaultPalette);
      final s = await newStore();
      s.setPalette(3);
      expect(s.palette, 3);
      s.setPalette(-5);
      expect(s.palette, kDefaultPalette);
    });

    test('backup membawa palet', () async {
      final s = await newStore();
      s.setPalette(2);
      final other = await newStore();
      expect(await other.importBackup(s.exportJson()), BackupResult.ok);
      expect(other.palette, 2);
    });
  });
}
