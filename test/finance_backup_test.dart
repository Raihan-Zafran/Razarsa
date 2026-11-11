import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/data/backup.dart';
import 'package:razarsa/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> open([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

/// Membuka ulang aplikasi dengan penyimpanan yang sama (tanpa direset).
Future<AppStore> reopen() async => AppStore(await SharedPreferences.getInstance(), vault: testVault);

/// Baris data CSV (tanpa header), dipecah per kolom bertanda kutip.
List<String> csvRows(AppStore s) => s.exportCsv().trim().split('\n').skip(1).toList();

void main() {
  group('Target tabungan: bisa dikurangi dan diubah', () {
    test('tarik sebagian tabungan', () async {
      final s = await open();
      s.addGoal('Laptop', 10000000);
      final g = s.goals.single;
      s.addToGoal(g.id, 3000000);
      expect(s.withdrawFromGoal(g.id, 1000000), isTrue);
      expect(s.goals.single.saved, 2000000);
    });

    test('tidak bisa menarik lebih dari yang ditabung, dan nilai tidak valid ditolak', () async {
      final s = await open();
      s.addGoal('Laptop', 10000000);
      final g = s.goals.single;
      s.addToGoal(g.id, 500000);
      expect(s.withdrawFromGoal(g.id, 500001), isFalse);
      expect(s.withdrawFromGoal(g.id, 0), isFalse);
      expect(s.withdrawFromGoal(g.id, -5), isFalse);
      expect(s.withdrawFromGoal('tidak-ada', 10), isFalse);
      expect(s.goals.single.saved, 500000);
    });

    test('tarik semua: tabungan kembali 0 (tidak negatif)', () async {
      final s = await open();
      s.addGoal('Laptop', 10000000);
      final g = s.goals.single;
      s.addToGoal(g.id, 750000);
      expect(s.withdrawFromGoal(g.id, 750000), isTrue);
      expect(s.goals.single.saved, 0);
      expect(s.goals.single.progress, 0);
    });

    test('ubah nama dan target; tabungan tetap', () async {
      final s = await open();
      s.addGoal('Laptop', 10000000);
      final g = s.goals.single;
      s.addToGoal(g.id, 2000000);
      expect(s.editGoal(g.id, name: '  Laptop kerja  ', target: 12000000), isTrue);
      expect(s.goals.single.name, 'Laptop kerja');
      expect(s.goals.single.target, 12000000);
      expect(s.goals.single.saved, 2000000);
    });

    test('ubah target di bawah tabungan: tetap boleh (target tercapai), tapi tidak nol/negatif/kosong', () async {
      final s = await open();
      s.addGoal('Laptop', 10000000);
      final g = s.goals.single;
      s.addToGoal(g.id, 6000000);
      expect(s.editGoal(g.id, target: 5000000), isTrue);
      expect(s.goals.single.progress, 1.0);
      expect(s.editGoal(g.id, target: 0), isFalse);
      expect(s.editGoal(g.id, target: -1), isFalse);
      expect(s.editGoal(g.id, name: '   '), isFalse);
      expect(s.editGoal(g.id, target: AppStore.maxAmount + 1), isFalse);
      expect(s.editGoal('tidak-ada', name: 'x'), isFalse);
      expect(s.goals.single.target, 5000000);
    });

    test('perubahan tersimpan permanen', () async {
      final s = await open();
      s.addGoal('Laptop', 10000000);
      final g = s.goals.single;
      s.addToGoal(g.id, 2000000);
      s.withdrawFromGoal(g.id, 500000);
      s.editGoal(g.id, name: 'Baru');
      await s.flush();
      final b = await reopen();
      expect(b.goals.single.name, 'Baru');
      expect(b.goals.single.saved, 1500000);
    });
  });

  group('CSV: tahan formula injection', () {
    Future<AppStore> withNames(List<String> names, {String? customCat}) async {
      final s = await open();
      String cat = 'food';
      if (customCat != null) cat = s.addCustomCategory(customCat, income: false).id;
      for (final n in names) {
        s.addTxn(name: n, cat: cat, amount: -1000);
      }
      return s;
    }

    test('semua awalan berbahaya diberi tanda petik: = + - @ tab, CR, LF', () async {
      final bad = ['=1+1', '+1+1', '-1+1', '@SUM(A1)', '\t=1+1', '\r=1+1', '\n=1+1'];
      final s = await withNames(bad);
      final csv = s.exportCsv();
      for (final b in bad) {
        expect(csv, isNot(contains(',"${b.replaceAll('"', '""')}",')), reason: 'tanpa petik: ${jsonEncode(b)}');
      }
      expect(csv.split("\"'").length - 1, bad.length);
    });

    test('spasi di depan tidak melewati penyaringan (sebagian aplikasi memangkas spasi)', () async {
      final s = await withNames([' =HYPERLINK("http://x","y")', '   +cmd|calc!A0']);
      final csv = s.exportCsv();
      expect(csv, isNot(contains(',"  ')));
      expect(csv.split("\"'").length - 1, 2);
    });

    test('nama kategori buatan sendiri juga disaring', () async {
      final s = await withNames(['biasa'], customCat: '=cmd|\' /C calc\'!A0');
      expect(s.exportCsv(), contains("\"'=cmd"));
    });

    test('teks aman tidak diubah; kutip ganda di dalam teks di-escape', () async {
      final s = await withNames(['Makan "enak" siang', 'Kopi, susu']);
      final csv = s.exportCsv();
      expect(csv, contains('"Makan ""enak"" siang"'));
      expect(csv, contains('"Kopi, susu"'));
      expect(csv, isNot(contains("\"'Makan")));
    });

    test('kolom jumlah tetap angka murni (bukan teks)', () async {
      final s = await withNames(['x']);
      expect(csvRows(s).single.endsWith(',-1000'), isTrue);
    });

    test('baris tidak pecah oleh baris baru di dalam nama (tetap satu record bertanda kutip)', () async {
      final s = await withNames(['baris1\nbaris2']);
      expect(s.exportCsv(), contains('"baris1\nbaris2"'));
    });
  });

  group('Pratinjau sebelum memulihkan backup', () {
    Future<String> sampleBackup({int txns = 3}) async {
      final s = await open();
      for (var i = 0; i < txns; i++) {
        s.addTxn(name: 'T$i', cat: 'food', amount: -(i + 1) * 1000);
      }
      s.addGoal('G', 1000);
      s.addNote(title: 'N', body: 'B');
      return s.exportJson();
    }

    test('mengintip isi backup polos tanpa mengubah data di HP', () async {
      final file = await sampleBackup(txns: 3);
      final s = await open();
      s.addTxn(name: 'Milik HP ini', cat: 'food', amount: -1);
      final i = await s.inspectBackup(file);
      expect(i.result, BackupResult.ok);
      expect(i.encrypted, isFalse);
      expect(i.count('txns'), 3);
      expect(i.count('goals'), 1);
      expect(i.count('notes'), 1);
      expect(i.exportedAt, isNotNull);
      expect(s.txns.single.name, 'Milik HP ini'); // belum diganti
    });

    test('backup terenkripsi: perlu kata sandi, sandi salah ditolak, sandi benar bisa diintip', () async {
      final s0 = await open();
      s0.addTxn(name: 'x', cat: 'food', amount: -5);
      final file = await s0.exportEncrypted('kata-sandi-kuat-1');
      final s = await open();
      expect((await s.inspectBackup(file)).result, BackupResult.needPassword);
      expect((await s.inspectBackup(file, password: 'salah-salah-1')).result, BackupResult.wrongPassword);
      final i = await s.inspectBackup(file, password: 'kata-sandi-kuat-1');
      expect(i.result, BackupResult.ok);
      expect(i.encrypted, isTrue);
      expect(i.count('txns'), 1);
      expect(s.txns, isEmpty);
    });

    test('memulihkan dari hasil pratinjau tidak mendekripsi dua kali dan hasilnya sama', () async {
      final s0 = await open();
      s0.addTxn(name: 'x', cat: 'food', amount: -5);
      final file = await s0.exportEncrypted('kata-sandi-kuat-1');
      final s = await open();
      final i = await s.inspectBackup(file, password: 'kata-sandi-kuat-1');
      expect(await s.restoreFrom(i), BackupResult.ok);
      expect(s.txns.single.name, 'x');
    });

    test('file jelek / versi baru / bukan backup: ditolak saat pratinjau', () async {
      final s = await open();
      expect((await s.inspectBackup('bukan json')).result, BackupResult.invalid);
      expect((await s.inspectBackup(jsonEncode({'app': 'lain'}))).result, BackupResult.invalid);
      expect((await s.inspectBackup(jsonEncode({'app': 'razarsa', 'version': 99, 'txns': [], 'goals': [], 'customCats': []}))).result, BackupResult.tooNew);
    });

    test('restoreFrom hasil pratinjau yang gagal tidak mengubah apa pun', () async {
      final s = await open();
      s.addTxn(name: 'Aman', cat: 'food', amount: -1);
      final i = await s.inspectBackup('sampah');
      expect(await s.restoreFrom(i), BackupResult.invalid);
      expect(s.txns.single.name, 'Aman');
    });
  });

  group('Kata sandi backup', () {
    test('terlalu pendek, terlalu mudah ditebak, dan sandi yang layak', () {
      expect(BackupEnvelope.passwordProblem('abc'), BackupPasswordProblem.tooShort);
      expect(BackupEnvelope.passwordProblem('12345678'), BackupPasswordProblem.weak);
      expect(BackupEnvelope.passwordProblem('aaaaaaaaaa'), BackupPasswordProblem.weak);
      expect(BackupEnvelope.passwordProblem('Password'), BackupPasswordProblem.weak);
      expect(BackupEnvelope.passwordProblem('qwertyuiop'), BackupPasswordProblem.weak);
      expect(BackupEnvelope.passwordProblem('kata-sandi-123'), isNull);
      expect(BackupEnvelope.passwordProblem('kopi manis tanpa gula'), isNull);
    });
  });
}
