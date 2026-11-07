import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/data/models.dart';
import 'package:razarsa/data/productive_models.dart';
import 'package:razarsa/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> newStore([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  return AppStore(await SharedPreferences.getInstance());
}

String txnsJson(List<Txn> list) => jsonEncode(list.map((e) => e.toJson()).toList());

void main() {
  group('Saldo & transaksi', () {
    test('saldo = jumlah semua transaksi (pemasukan positif, pengeluaran negatif)', () async {
      final s = await newStore();
      s.addTxn(name: 'Gaji', cat: 'salary', amount: 5000000);
      s.addTxn(name: 'Kopi', cat: 'food', amount: -25000);
      s.addTxn(name: 'Makan', cat: 'food', amount: -50000);
      expect(s.balance, 4925000);
    });

    test('hapus transaksi mengubah saldo', () async {
      final s = await newStore();
      final t = s.addTxn(name: 'Kopi', cat: 'food', amount: -25000);
      s.removeTxn(t.id);
      expect(s.balance, 0);
      expect(s.txns, isEmpty);
    });
  });

  group('Transaksi berulang', () {
    test('tercatat sekali per bulan, bukan berulang tiap dibuka', () async {
      final s = await newStore();
      // Tanggal 1 selalu sudah lewat bulan ini.
      s.recurring.add(Recurring(id: 'r1', name: 'Kos', cat: 'bills', amount: -800000, day: 1));
      expect(s.postRecurring(notify: false), 1);
      expect(s.postRecurring(notify: false), 0);
      expect(s.txns.where((t) => t.name == 'Kos').length, 1);
      expect(s.balance, -800000);
    });
  });

  group('Backup', () {
    test('ekspor lalu impor mengembalikan data yang sama', () async {
      final a = await newStore();
      a.addTxn(name: 'Gaji', cat: 'salary', amount: 3000000);
      a.addGoal('Laptop', 10000000);
      a.setBudget(4000000);
      final json = a.exportJson();

      final b = await newStore();
      expect(b.importJson(json), isTrue);
      expect(b.balance, 3000000);
      expect(b.goals.length, 1);
      expect(b.monthlyBudget, 4000000);
    });

    test('file backup rusak ditolak dan data lama tidak berubah', () async {
      final s = await newStore();
      s.addTxn(name: 'Kopi', cat: 'food', amount: -25000);
      // txns valid, tapi goals tidak ada -> seluruh impor harus dibatalkan.
      final bad = jsonEncode({
        'app': 'razarsa',
        'txns': [Txn(id: 'x', name: 'Palsu', cat: 'food', amount: -1, at: DateTime(2026, 1, 1)).toJson()],
      });
      expect(s.importJson(bad), isFalse);
      expect(s.txns.length, 1);
      expect(s.txns.first.name, 'Kopi');
      expect(s.importJson('bukan json'), isFalse);
      expect(s.importJson(jsonEncode({'app': 'lain', 'txns': [], 'goals': [], 'customCats': []})), isFalse);
    });

    test('impor menyimpan salinan data lama untuk dibatalkan', () async {
      final s = await newStore();
      s.addTxn(name: 'Kopi', cat: 'food', amount: -25000);
      final empty = jsonEncode({'app': 'razarsa', 'txns': [], 'goals': [], 'customCats': []});
      expect(s.importJson(empty), isTrue);
      expect(s.txns, isEmpty);
      expect(s.hasAutoBackup, isTrue);
      expect(s.restoreAutoBackup(), isTrue);
      expect(s.txns.length, 1);
    });

    test('hapus semua data masih bisa dibatalkan lewat cadangan otomatis', () async {
      final s = await newStore();
      s.addTxn(name: 'Kopi', cat: 'food', amount: -25000);
      await s.clearAll();
      expect(s.txns, isEmpty);
      expect(s.restoreAutoBackup(), isTrue);
      expect(s.balance, -25000);
    });
  });

  group('Data rusak & cadangan otomatis', () {
    test('data rusak tidak dibuang: salinannya diselamatkan', () async {
      final s = await newStore({'txns': 'ini bukan json'});
      expect(s.txns, isEmpty);
      expect(s.loadProblems, contains('txns'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('rusak_txns'), 'ini bukan json');
    });

    test('salinan data rusak pertama tidak ditimpa', () async {
      final s = await newStore({'txns': 'rusak asli', 'rusak_txns': 'salinan lama'});
      expect(s.loadProblems, contains('txns'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('rusak_txns'), 'salinan lama');
    });

    test('cadangan otomatis dibuat saat aplikasi dibuka dan data ada', () async {
      final t = Txn(id: '1', name: 'Kopi', cat: 'food', amount: -25000, at: DateTime(2026, 1, 1));
      final s = await newStore({'txns': txnsJson([t])});
      expect(s.hasAutoBackup, isTrue);
      expect(s.autoBackupAt, isNotEmpty);
    });

    test('data yang gagal dibaca tidak menimpa cadangan otomatis', () async {
      final s = await newStore({'txns': 'rusak', 'autoBackup': 'cadangan bagus', 'autoBackupAt': '2020-01-01T00:00:00'});
      expect(s.loadProblems, isNotEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('autoBackup'), 'cadangan bagus');
    });

    test('versi data ditandai', () async {
      await newStore();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('dataVersion'), AppStore.dataVersion);
    });
  });

  group('Catatan: folder dan kunci', () {
    test('folder: tambah, tolak kosong atau ganda, hapus memindahkan catatan', () async {
      final s = await newStore();
      expect(s.addNoteFolder('Kuliah'), isTrue);
      expect(s.addNoteFolder(' Kuliah '), isFalse);
      expect(s.addNoteFolder('   '), isFalse);
      expect(s.addNoteFolder('x' * 21), isFalse);
      final n = s.addNote(title: 'A', folder: 'Kuliah');
      expect(n.folder, 'Kuliah');
      s.removeNoteFolder('Kuliah');
      expect(s.noteFolders, isEmpty);
      expect(s.notes.single.folder, '');
    });

    test('memindah folder atau mengunci tidak mengubah waktu terakhir diubah', () async {
      final s = await newStore();
      final n = s.addNote(title: 'A');
      final t = n.updatedAt;
      s.updateNote(n, folder: 'Ide', locked: true);
      expect(n.updatedAt, t);
      expect(n.locked, isTrue);
    });

    test('folder dan kunci ikut backup', () async {
      final a = await newStore();
      a.addNoteFolder('Ide');
      final n = a.addNote(title: 'Rahasia', body: 'x', folder: 'Ide');
      a.updateNote(n, locked: true);
      final b = await newStore();
      expect(b.importJson(a.exportJson()), isTrue);
      expect(b.noteFolders, ['Ide']);
      expect(b.notes.single.folder, 'Ide');
      expect(b.notes.single.locked, isTrue);
    });

    test('catatan versi lama tanpa folder tetap terbaca', () {
      final n = Note.fromJson({'id': '1', 'title': 't', 'body': 'b', 'tone': 'amber', 'pinned': false, 'updatedAt': '2026-01-01T00:00:00'});
      expect(n.folder, '');
      expect(n.locked, isFalse);
    });
  });

  group('Terjemahan', () {
    test('semua teks tr() di kode punya terjemahan Inggris', () {
      final re = RegExp(r'''\btrf?\(\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")''');
      final missing = <String>{};
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') || f.path.endsWith('i18n.dart')) continue;
        for (final m in re.allMatches(f.readAsStringSync())) {
          final text = (m.group(1) ?? m.group(2))!.replaceAll(r"\'", "'").replaceAll(r'\n', '\n');
          if (!hasEnglish(text)) missing.add(text);
        }
      }
      expect(missing, isEmpty, reason: 'Tambahkan terjemahan di lib/core/i18n.dart untuk:\n${missing.join('\n')}');
    });
  });
}
