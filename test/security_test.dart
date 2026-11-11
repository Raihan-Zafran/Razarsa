import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/core/crypto.dart';
import 'package:razarsa/data/backup.dart';
import 'package:razarsa/data/models.dart';
import 'package:razarsa/data/productive_models.dart';
import 'package:razarsa/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

const secret = 'RAHASIA-JANGAN-BOCOR-12345';

Future<AppStore> open({Map<String, Object>? seed, KeyVault? vault}) async {
  if (seed != null) SharedPreferences.setMockInitialValues(seed);
  return AppStore(await SharedPreferences.getInstance(), vault: vault ?? testVault);
}

/// Semua nilai teks di penyimpanan, digabung, untuk memastikan tidak ada rahasia yang polos.
Future<String> dump() async {
  final p = await SharedPreferences.getInstance();
  return p.getKeys().map((k) => '$k=${p.get(k)}').join('\n');
}

Future<AppStore> withLockedNote([KeyVault? vault]) async {
  final s = await open(seed: {}, vault: vault);
  s.setPin('123456');
  final n = s.addNote(title: 'Rahasia', body: secret);
  expect(s.updateNote(n, locked: true), isTrue);
  await s.flush();
  return s;
}

void main() {
  group('PIN: batas percobaan', () {
    test('5 kali salah mengunci sementara, PIN benar pun ditolak selama dikunci', () async {
      final s = await open(seed: {});
      s.setPin('123456');
      for (var i = 0; i < 4; i++) {
        expect(s.tryPin('000000'), PinResult.wrong);
      }
      expect(s.pinLockRemaining, Duration.zero);
      expect(s.tryPin('000000'), PinResult.wrong); // ke-5
      expect(s.pinLockRemaining.inSeconds, greaterThan(20));
      expect(s.tryPin('123456'), PinResult.locked);
      expect(s.checkPin('123456'), isFalse);
    });

    test('jeda makin lama di percobaan berikutnya', () async {
      final s = await open(seed: {});
      s.setPin('123456');
      for (var i = 0; i < 5; i++) {
        s.tryPin('000000');
      }
      final first = s.pinLockRemaining;
      s.pinLockUntilMs = 0; // anggap jeda pertama sudah lewat
      s.tryPin('000000'); // ke-6
      expect(s.pinLockRemaining, greaterThan(first));
    });

    test('setelah jeda lewat, PIN benar diterima dan hitungan salah direset', () async {
      final s = await open(seed: {});
      s.setPin('123456');
      for (var i = 0; i < 5; i++) {
        s.tryPin('000000');
      }
      s.pinLockUntilMs = DateTime.now().millisecondsSinceEpoch - 1;
      expect(s.tryPin('123456'), PinResult.ok);
      expect(s.pinFails, 0);
      expect(s.pinLockUntilMs, 0);
    });

    test('hitungan salah dan jeda bertahan walau aplikasi ditutup lalu dibuka', () async {
      final s = await open(seed: {});
      s.setPin('123456');
      for (var i = 0; i < 5; i++) {
        s.tryPin('000000');
      }
      await s.flush();
      final b = await open();
      expect(b.pinFails, 5);
      expect(b.pinLockRemaining.inSeconds, greaterThan(20));
      expect(b.tryPin('123456'), PinResult.locked);
    });

    test('jam HP dimundurkan tidak membuat jeda lebih lama dari 1 jam', () async {
      final s = await open(seed: {});
      s.setPin('123456');
      s.pinLockUntilMs = DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
      expect(s.pinLockRemaining, lessThanOrEqualTo(const Duration(hours: 1)));
    });
  });

  group('PIN: format & kompatibilitas', () {
    test('PIN baru 4-6 digit angka saja', () async {
      final s = await open(seed: {});
      for (final bad in ['123', '1234567', 'abcd', '12 34', '', '12.45']) {
        expect(() => s.setPin(bad), throwsArgumentError, reason: bad);
      }
      s.setPin('1234');
      expect(s.pinLength, 4);
      s.setPin('654321');
      expect(s.pinLength, 6);
      expect(s.checkPin('654321'), isTrue);
    });

    test('PIN lama 4 digit (SHA-256 polos) tetap bisa dipakai dan di-upgrade', () async {
      final s = await open(seed: {
        'pinHash': '2fc87f8286ffc6bc8a3696adbf13c104b100a04af525a96d93d665e99ecadf58',
        'switches': jsonEncode({'pin': true}),
      });
      expect(s.pinEnabled, isTrue);
      expect(s.pinLength, 4);
      expect(s.checkPin('0000'), isFalse);
      expect(s.checkPin('1234'), isTrue);
      expect(s.pinHash.startsWith(r'v2$'), isTrue);
      expect(s.checkPin('1234'), isTrue);
    });

    test('hash PBKDF2 buatan versi sebelumnya (30.000 iterasi) tetap cocok, lalu naik iterasi', () async {
      // Vektor dihitung terpisah dengan hashlib.pbkdf2_hmac('sha256', b'1234', salt, 30000, 32).
      const old = r'v2$30000$00112233445566778899aabbccddeeff$3366e22a2a6be6e276c83820f018a7eed8dea53823667453002b766617c2745a';
      final s = await open(seed: {'pinHash': old});
      expect(s.checkPin('1234'), isTrue);
      expect(s.pinHash.split(r'$')[1], isNot('30000'));
      expect(s.checkPin('1234'), isTrue);
      expect(s.checkPin('4321'), isFalse);
    });

    test('hash PIN rusak atau tidak masuk akal ditolak tanpa crash', () async {
      for (final bad in [r'v2$abc$00$00', r'v2$999999999$00$00', r'v2$1', 'zzz']) {
        final s = await open(seed: {'pinHash': bad});
        expect(s.checkPin('1234'), isFalse, reason: bad);
      }
    });

    test('saklar PIN selalu sejalan dengan hash PIN', () async {
      final s = await open(seed: {
        'switches': jsonEncode({'pin': true, 'bio': true}),
      });
      expect(s.pinEnabled, isFalse);
      expect(s.switches['pin'], isFalse);
      expect(s.switches['bio'], isFalse);
    });
  });

  group('Catatan terkunci: enkripsi', () {
    test('isi catatan terkunci tidak pernah tersimpan polos (termasuk cadangan otomatis)', () async {
      final s = await withLockedNote();
      s.updateNote(s.notes.first, body: '$secret lagi');
      await s.flush();
      await s.restoreAutoBackup();
      await s.flush();
      expect(await dump(), isNot(contains('RAHASIA')));
      expect(s.notes.first.body, contains(secret));
    });

    test('dibuka ulang dengan kunci yang sama: isi terbaca kembali', () async {
      await withLockedNote();
      final b = await open();
      expect(b.notes.single.locked, isTrue);
      expect(b.notes.single.body, secret);
      expect(b.notes.single.unreadable, isFalse);
    });

    test('kunci perangkat hilang: catatan tidak terbaca tapi ciphertext TIDAK hilang', () async {
      await withLockedNote();
      final other = MemoryKeyVault();
      final b = await open(vault: other);
      final n = b.notes.single;
      expect(n.unreadable, isTrue);
      expect(n.body, '');
      // Tidak boleh diubah atau dibuka kuncinya, dan menyimpan data lain tidak merusaknya.
      expect(b.updateNote(n, body: 'timpa'), isFalse);
      expect(b.updateNote(n, locked: false), isFalse);
      b.addTxn(name: 'x', cat: 'food', amount: -1000);
      await b.flush();
      final back = await open(); // kunci asli kembali
      expect(back.notes.single.body, secret);
    });

    test('ciphertext yang diubah ditolak (autentikasi GCM)', () async {
      await withLockedNote();
      final p = await SharedPreferences.getInstance();
      final list = jsonDecode(p.getString('notes')!) as List;
      final enc = (list.first as Map)['enc'] as String;
      final raw = base64.decode(enc);
      raw[raw.length - 1] ^= 1;
      (list.first as Map)['enc'] = base64.encode(raw);
      await p.setString('notes', jsonEncode(list));
      final b = await open();
      expect(b.notes.single.unreadable, isTrue);
      expect(b.notes.single.body, '');
    });

    test('ciphertext terikat ke id catatan: ditukar ke catatan lain tidak terbuka', () async {
      final s = await open(seed: {});
      s.setPin('123456');
      final a = s.addNote(title: 'A', body: 'isi A');
      final b = s.addNote(title: 'B', body: 'isi B');
      s.updateNote(a, locked: true);
      s.updateNote(b, locked: true);
      await s.flush();
      final p = await SharedPreferences.getInstance();
      final list = (jsonDecode(p.getString('notes')!) as List).cast<Map<String, dynamic>>();
      final tmp = list[0]['enc'];
      list[0]['enc'] = list[1]['enc'];
      list[1]['enc'] = tmp;
      await p.setString('notes', jsonEncode(list));
      final r = await open();
      expect(r.notes.every((n) => n.unreadable), isTrue);
    });

    test('data lama (catatan terkunci polos + cadangan polos) dimigrasi tanpa kehilangan isi', () async {
      final note = {
        'id': 'n1', 'title': 'Lama', 'body': secret, 'tone': 'amber', 'pinned': false,
        'folder': '', 'locked': true, 'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      };
      final s = await open(seed: {
        'dataVersion': 1,
        'notes': jsonEncode([note]),
        'autoBackup': jsonEncode({'app': 'razarsa', 'version': 1, 'txns': [], 'goals': [], 'customCats': [], 'notes': [note]}),
        'autoBackupAt': '2020-01-01T00:00:00',
      });
      await s.flush();
      expect(s.notes.single.body, secret);
      expect(await dump(), isNot(contains('RAHASIA')));
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('dataVersion'), AppStore.dataVersion);
      // Cadangan lama tidak dibuang dan masih bisa dipulihkan.
      expect(s.hasAutoBackup, isTrue);
      final again = await open();
      expect(again.notes.single.body, secret);
      expect(await again.restoreAutoBackup(), isTrue);
      expect(again.notes.single.body, secret);
    });

    test('tanpa kunci enkripsi: catatan tidak bisa dikunci dan data tidak hilang', () async {
      final s = await open(seed: {}, vault: MemoryKeyVault.unavailable());
      expect(s.canLockNotes, isFalse);
      s.setPin('123456');
      final n = s.addNote(title: 'A', body: 'isi');
      expect(s.updateNote(n, locked: true), isFalse);
      expect(n.locked, isFalse);
      expect(n.body, 'isi');
    });

    test('buka kunci mengembalikan catatan biasa; mematikan PIN membuka semua kunci', () async {
      final s = await withLockedNote();
      s.setPin('654321'); // ganti PIN: kunci tetap
      expect(s.notes.single.locked, isTrue);
      s.setPin(null);
      expect(s.notes.single.locked, isFalse);
      expect(s.notes.single.body, secret);
      await s.flush();
      final b = await open();
      expect(b.notes.single.body, secret);
      expect(b.notes.single.locked, isFalse);
    });
  });

  group('Backup', () {
    test('backup polos tidak memuat isi catatan terkunci', () async {
      final s = await withLockedNote();
      expect(s.exportJson(), isNot(contains('RAHASIA')));
      expect(s.hasLockedNotes, isTrue);
    });

    test('backup terenkripsi: bolak-balik utuh, tanpa teks polos, termasuk catatan terkunci', () async {
      final s = await withLockedNote();
      s.addTxn(name: 'Kopi Rahasia', cat: 'food', amount: -25000);
      final file = await s.exportEncrypted('kata-sandi-kuat');
      expect(file, isNot(contains('RAHASIA')));
      expect(file, isNot(contains('Kopi')));

      // Dipulihkan di HP lain (kunci perangkat berbeda).
      final other = await open(seed: {}, vault: MemoryKeyVault());
      expect(await other.importBackup(file), BackupResult.needPassword);
      expect(await other.importBackup(file, password: 'salah-salah'), BackupResult.wrongPassword);
      expect(other.txns, isEmpty);
      expect(await other.importBackup(file, password: 'kata-sandi-kuat'), BackupResult.ok);
      expect(other.txns.single.name, 'Kopi Rahasia');
      expect(other.notes.single.locked, isTrue);
      expect(other.notes.single.body, secret);
      await other.flush();
      expect(await dump(), isNot(contains('RAHASIA')));
    });

    test('file terenkripsi yang diubah atau kdf berlebihan ditolak', () async {
      final s = await withLockedNote();
      final m = jsonDecode(await s.exportEncrypted('kata-sandi-kuat')) as Map<String, dynamic>;
      final data = base64.decode(m['data'] as String);
      data[20] ^= 0xff;
      final tampered = {...m, 'data': base64.encode(data)};
      final t = await open(seed: {});
      expect(await t.importBackup(jsonEncode(tampered), password: 'kata-sandi-kuat'), BackupResult.wrongPassword);
      final bomb = {...m, 'iter': 900000000};
      expect(await t.importBackup(jsonEncode(bomb), password: 'kata-sandi-kuat'), BackupResult.wrongPassword);
    });

    test('backup versi lebih baru dan file sampah ditolak, data lama utuh', () async {
      final s = await open(seed: {});
      s.addTxn(name: 'Ada', cat: 'food', amount: -1000);
      expect(await s.importBackup(jsonEncode({'app': 'razarsa', 'version': 99, 'txns': [], 'goals': [], 'customCats': []})), BackupResult.tooNew);
      expect(await s.importBackup('bukan json'), BackupResult.invalid);
      expect(await s.importBackup(jsonEncode({'app': 'lain'})), BackupResult.invalid);
      expect(await s.importBackup('x' * (AppStore.maxBackupChars + 1)), BackupResult.invalid);
      expect(s.txns.length, 1);
    });

    test('nominal tidak masuk akal ditolak seluruhnya (atomik)', () async {
      final s = await open(seed: {});
      s.addTxn(name: 'Ada', cat: 'food', amount: -1000);
      final bad = {
        'app': 'razarsa', 'version': 2, 'goals': [], 'customCats': [],
        'txns': [
          {'id': '1', 'name': 'a', 'cat': 'food', 'amount': -5, 'at': '2026-01-01T00:00:00'},
          {'id': '2', 'name': 'b', 'cat': 'food', 'amount': 9000000000000000, 'at': '2026-01-01T00:00:00'},
        ],
      };
      expect(s.importJson(jsonEncode(bad)), isFalse);
      expect(s.txns.single.name, 'Ada');
    });

    test('id kembar di file dibuang supaya hapus satu tidak menghapus dua', () async {
      final s = await open(seed: {});
      final dup = {
        'app': 'razarsa', 'version': 2, 'goals': [], 'customCats': [],
        'txns': [
          {'id': '1', 'name': 'a', 'cat': 'food', 'amount': -5, 'at': '2026-01-01T00:00:00'},
          {'id': '1', 'name': 'b', 'cat': 'food', 'amount': -7, 'at': '2026-01-02T00:00:00'},
        ],
      };
      expect(s.importJson(jsonEncode(dup)), isTrue);
      expect(s.txns.length, 1);
    });

    test('backup versi lama (tanpa version, nama zevra) tetap bisa dipulihkan', () async {
      final s = await open(seed: {});
      final legacy = {
        'app': 'zevra', 'exportedAt': '2026-01-01T00:00:00', 'monthlyBudget': 3000000,
        'txns': [
          {'id': '1', 'name': 'Kopi', 'cat': 'food', 'amount': -25000, 'at': '2026-01-01T08:00:00'}
        ],
        'goals': [
          {'id': 'g', 'name': 'Laptop', 'target': 10000000, 'saved': 500000, 'tone': 'blue'}
        ],
        'customCats': [],
      };
      expect(await s.importBackup(jsonEncode(legacy)), BackupResult.ok);
      expect(s.txns.single.amount, -25000);
      expect(s.goals.single.saved, 500000);
      expect(s.monthlyBudget, 3000000);
    });

    test('backup polos dari versi 1.2.x dengan catatan terkunci tetap terbaca dan jadi terenkripsi', () async {
      final s = await open(seed: {});
      final old = {
        'app': 'razarsa', 'version': 1, 'txns': [], 'goals': [], 'customCats': [],
        'notes': [
          {'id': 'n', 'title': 'T', 'body': secret, 'tone': 'amber', 'locked': true, 'updatedAt': '2026-01-01T00:00:00'}
        ],
      };
      expect(s.importJson(jsonEncode(old)), isTrue);
      await s.flush();
      expect(s.notes.single.body, secret);
      expect(await dump(), isNot(contains('RAHASIA')));
    });

    test('CSV: teks berawalan = + - @ tidak jadi rumus Excel', () async {
      final s = await open(seed: {});
      s.addTxn(name: '=HYPERLINK("http://evil","klik")', cat: 'food', amount: -1000);
      s.addTxn(name: '@SUM(A1)', cat: 'food', amount: -1000);
      s.addTxn(name: '-2+3', cat: 'food', amount: -1000);
      s.addTxn(name: 'aman', cat: 'food', amount: -1000);
      final csv = s.exportCsv();
      expect(csv, contains('"\'=HYPERLINK'));
      expect(csv, contains('"\'@SUM(A1)"'));
      expect(csv, contains('"\'-2+3"'));
      expect(csv, contains('"aman"'));
    });

    test('pbkdf2 sama dengan vektor RFC 7914 (PBKDF2-HMAC-SHA256)', () {
      // RFC 7914 §11: P="passwd", S="salt", c=1, dkLen=64 -> awalan 55ac046e56e3089f...
      final k = pbkdf2('passwd', utf8.encode('salt'), 1, length: 64);
      expect(k.sublist(0, 8).map((e) => e.toRadixString(16).padLeft(2, '0')).join(), '55ac046e56e3089f');
      expect(BackupEnvelope.minPasswordLength, 8);
    });
  });

  group('Notifikasi tidak menggantung', () {
    Recurring bill(String id) => Recurring(id: id, name: 'Kos', cat: 'bills', amount: -500000, day: 5);

    test('hapus transaksi berulang membatalkan notifikasinya', () async {
      final s = await open(seed: {});
      final cancelled = <int>[];
      s.onRecurringChanged = ({List<int> cancelIds = const []}) => cancelled.addAll(cancelIds);
      final r = bill('123456789');
      s.recurring.add(r);
      s.removeRecurring(r.id);
      expect(cancelled, [r.notifId]);
    });

    test('hapus semua data membatalkan tagihan dan pengingat', () async {
      final s = await open(seed: {});
      final r = bill('222222222');
      s.recurring.add(r);
      final a = s.addAgenda('Rapat', DateTime.now().add(const Duration(days: 1)), reminder: true);
      final cancelledBills = <int>[];
      final removedAgenda = <String>[];
      s.onRecurringChanged = ({List<int> cancelIds = const []}) => cancelledBills.addAll(cancelIds);
      s.onAgendaChanged = (x, {bool removed = false}) {
        if (removed) removedAgenda.add(x.id);
      };
      await s.clearAll();
      expect(cancelledBills, [r.notifId]);
      expect(removedAgenda, [a.id]);
    });

    test('impor backup membatalkan pengingat dan tagihan lama yang tidak ada di backup', () async {
      final s = await open(seed: {});
      final r = bill('333333333');
      s.recurring.add(r);
      final a = s.addAgenda('Lama', DateTime.now().add(const Duration(days: 1)), reminder: true);
      final cancelledBills = <int>[];
      final removedAgenda = <String>[];
      s.onRecurringChanged = ({List<int> cancelIds = const []}) => cancelledBills.addAll(cancelIds);
      s.onAgendaChanged = (x, {bool removed = false}) {
        if (removed) removedAgenda.add(x.id);
      };
      expect(s.importJson(jsonEncode({'app': 'razarsa', 'version': 2, 'txns': [], 'goals': [], 'customCats': []})), isTrue);
      expect(cancelledBills, contains(r.notifId));
      expect(removedAgenda, contains(a.id));
    });

    test('peringatan anggaran yang sudah terkirim tersimpan permanen', () async {
      final s = await open(seed: {});
      s.markBudgetAlert('2026-11-01');
      await s.flush();
      final b = await open();
      expect(b.budgetAlertSent, '2026-11-01');
    });
  });

  group('Storage & keuangan', () {
    test('nilai tersimpan yang rusak atau salah tipe tidak membuat aplikasi crash', () async {
      final s = await open(seed: {
        'themeMode': 99,
        'lang': 5,
        'monthStartDay': 400,
        'monthlyBudget': 'banyak',
        'mode': 'gym',
        'financeBg': 7,
        'activeDays': 'bukan list',
        'switches': '[]',
      });
      expect(s.themeMode, isNotNull);
      expect(s.lang, 'id');
      expect(s.monthStartDay, 28);
      expect(s.monthlyBudget, 5000000);
      expect(s.mode, 'finance');
    });

    test('data dari aplikasi yang lebih baru tidak ditimpa', () async {
      final s = await open(seed: {'dataVersion': 99, 'txns': 'data-masa-depan'});
      s.addTxn(name: 'x', cat: 'food', amount: -1);
      await s.flush();
      final p = await SharedPreferences.getInstance();
      expect(p.getString('txns'), 'data-masa-depan');
      expect(p.getInt('dataVersion'), 99);
    });

    test('id selalu unik walau dibuat beruntun', () async {
      final s = await open(seed: {});
      final ids = {for (var i = 0; i < 5000; i++) s.newId()};
      expect(ids.length, 5000);
    });

    test('nominal dibatasi supaya hitungan tidak meluap', () async {
      final s = await open(seed: {});
      final t = s.addTxn(name: 'x', cat: 'food', amount: 1 << 60);
      expect(t.amount, AppStore.maxAmount);
      s.setBudget(-5);
      expect(s.monthlyBudget, 0);
      s.addGoal('G', 1000);
      s.addToGoal(s.goals.single.id, 1 << 60);
      expect(s.goals.single.saved, AppStore.maxAmount);
    });

    test('aksi pada id yang sudah tidak ada tidak crash (tekan ganda)', () async {
      final s = await open(seed: {});
      expect(() => s.toggleTodo('x'), returnsNormally);
      expect(() => s.toggleAgenda('x'), returnsNormally);
      expect(() => s.removeAgenda('x'), returnsNormally);
      expect(() => s.addToGoal('x', 5), returnsNormally);
    });

    test('transaksi berulang yang terlewat saat aplikasi tidak dibuka ikut tercatat', () async {
      final s = await open(seed: {});
      final now = DateTime.now();
      final threeAgo = DateTime(now.year, now.month - 3);
      final key = '${threeAgo.year}-${threeAgo.month.toString().padLeft(2, '0')}';
      s.recurring.add(Recurring(id: 'r', name: 'Kos', cat: 'housing', amount: -800000, day: 1, lastPosted: key));
      expect(s.postRecurring(notify: false), 3);
      final months = s.txns.map((t) => t.at.month).toSet();
      expect(months.length, 3);
      expect(s.postRecurring(notify: false), 0);
    });

    test('catch-up transaksi berulang dibatasi 12 bulan', () async {
      final s = await open(seed: {});
      s.recurring.add(Recurring(id: 'r', name: 'Kos', cat: 'housing', amount: -1, day: 1, lastPosted: '2000-01'));
      expect(s.postRecurring(notify: false), 12);
    });

    test('transaksi berulang baru dibuat tidak mencatat bulan-bulan sebelum dibuat', () async {
      final s = await open(seed: {});
      final now = DateTime.now();
      s.recurring.add(Recurring(id: 'r', name: 'Gaji', cat: 'salary', amount: 1, day: 1));
      expect(s.postRecurring(notify: false), 1);
      expect(s.txns.single.at.month, now.month);
    });

    test('hapus semua data juga membuang salinan data rusak', () async {
      final s = await open(seed: {'txns': 'rusak'});
      expect((await SharedPreferences.getInstance()).containsKey('rusak_txns'), isTrue);
      await s.clearAll();
      expect((await SharedPreferences.getInstance()).containsKey('rusak_txns'), isFalse);
    });

    test('hanya data yang berubah yang ditulis ulang', () async {
      final s = await open(seed: {});
      s.addTxn(name: 'a', cat: 'food', amount: -1);
      await s.flush();
      final p = await SharedPreferences.getInstance();
      await p.setString('goals', 'ditandai-dari-luar');
      s.addTxn(name: 'b', cat: 'food', amount: -1);
      await s.flush();
      // goals tidak berubah di memori, jadi tidak ditulis ulang.
      expect(p.getString('goals'), 'ditandai-dari-luar');
      expect(Txn.fromJson((jsonDecode(p.getString('txns')!) as List).first as Map<String, dynamic>).name, isNotEmpty);
    });

    test('catatan versi 1.2.1 tanpa kolom baru tetap terbaca', () async {
      final s = await open(seed: {
        'dataVersion': 1,
        'notes': jsonEncode([
          {'id': 'a', 'title': 'T', 'body': 'B', 'tone': 'amber', 'updatedAt': '2026-01-01T00:00:00'}
        ]),
      });
      expect(s.notes.single.body, 'B');
      expect(s.notes.single.locked, isFalse);
      expect(s.notes.single, isA<Note>());
    });
  });
}
