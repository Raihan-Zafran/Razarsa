import 'dart:convert';
import 'package:flutter/material.dart' show ThemeMode;

import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/crypto.dart';
import 'package:razarsa/data/models.dart';
import 'package:razarsa/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> open({Map<String, Object>? seed, KeyVault? vault}) async {
  if (seed != null) SharedPreferences.setMockInitialValues(seed);
  return AppStore(await SharedPreferences.getInstance(), vault: vault ?? testVault);
}

Future<List<dynamic>> storedList(String key) async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString(key);
  return raw == null ? [] : jsonDecode(raw) as List;
}

Map<String, dynamic> backupWith(List<Map<String, dynamic>> txns, {Map<String, dynamic>? extra}) => {
      'app': 'razarsa',
      'version': 2,
      'txns': txns,
      'goals': [],
      'customCats': [],
      ...?extra,
    };

Map<String, dynamic> txn(String id, int amount) =>
    {'id': id, 'name': 'T$id', 'cat': 'food', 'amount': amount, 'at': '2026-01-01T08:00:00.000'};

void main() {
  group('Sukses = sudah tersimpan', () {
    test('importBackup: begitu hasilnya "ok", data baru sudah ada di penyimpanan', () async {
      final s = await open(seed: {});
      s.addTxn(name: 'Lama', cat: 'food', amount: -1000);
      await s.flush();
      final r = await s.importBackup(jsonEncode(backupWith([txn('9', -5)])));
      expect(r, BackupResult.ok);
      // Tanpa flush(): kalau aplikasi mati tepat sekarang, apa yang tersimpan?
      final stored = await storedList('txns');
      expect(stored.map((e) => (e as Map)['id']), ['9']);
    });

    test('clearAll: begitu selesai, penyimpanan sudah kosong', () async {
      final s = await open(seed: {});
      s.addTxn(name: 'Lama', cat: 'food', amount: -1000);
      await s.flush();
      await s.clearAll();
      expect(await storedList('txns'), isEmpty);
    });

    test('restoreAutoBackup: begitu selesai, data pulih sudah tersimpan', () async {
      final s = await open(seed: {});
      s.addTxn(name: 'Penting', cat: 'food', amount: -1000);
      await s.flush();
      await s.clearAll();
      final ok = await s.restoreAutoBackup();
      expect(ok, isTrue);
      expect((await storedList('txns')).length, 1);
    });

    test('gagal menulis ke penyimpanan: impor TIDAK dilaporkan berhasil', () async {
      SharedPreferences.setMockInitialValues({});
      final broken = _BrokenPrefs(await SharedPreferences.getInstance());
      final b = AppStore(broken, vault: testVault);
      broken.fail = true;
      final r = await b.importBackup(jsonEncode(backupWith([txn('1', -5)])));
      expect(r, BackupResult.saveFailed);
      expect(b.lastSaveError, isNotNull);
    });
  });

  group('Migrasi versi data', () {
    test('sebelum migrasi v1 -> v2 dibuat salinan cadangan terenkripsi dari kondisi lama', () async {
      final note = {
        'id': 'n1', 'title': 'Lama', 'body': 'ISI-RAHASIA-LAMA', 'tone': 'amber', 'pinned': false,
        'folder': '', 'locked': true, 'updatedAt': '2026-01-01T00:00:00.000',
      };
      final s = await open(seed: {
        'dataVersion': 1,
        'txns': jsonEncode([txn('1', -5000)]),
        'notes': jsonEncode([note]),
      });
      await s.flush();
      final p = await SharedPreferences.getInstance();
      final backup = p.getString('autoBackup') ?? '';
      expect(backup, contains('"id":"1"'), reason: 'transaksi lama ada di cadangan pra-migrasi');
      expect(backup, isNot(contains('ISI-RAHASIA-LAMA')), reason: 'isi catatan terkunci terenkripsi');
      expect(backup, contains('"enc"'));
    });

    test('cadangan hari ini sudah ada (snapshot biasa dilewati): kondisi pra-migrasi tetap diamankan', () async {
      final today = DateTime.now().toIso8601String();
      final s = await open(seed: {
        'dataVersion': 1,
        'txns': jsonEncode([txn('7', -7000)]),
        'autoBackup': jsonEncode({'app': 'razarsa', 'version': 1, 'txns': [], 'goals': [], 'customCats': []}),
        'autoBackupAt': today,
      });
      await s.flush();
      final p = await SharedPreferences.getInstance();
      expect(p.getString('autoBackup'), contains('"id":"7"'));
    });

    test('data rusak saat migrasi: cadangan lama yang bagus TIDAK ditimpa', () async {
      final good = jsonEncode({'app': 'razarsa', 'version': 1, 'txns': [txn('1', -1)], 'goals': [], 'customCats': []});
      await open(seed: {'dataVersion': 1, 'txns': 'rusak', 'autoBackup': good, 'autoBackupAt': '2020-01-01T00:00:00'});
      final p = await SharedPreferences.getInstance();
      expect(p.getString('autoBackup'), good);
    });

    test('migrasi diulang aman bila terputus sebelum dataVersion ditulis', () async {
      final note = {
        'id': 'n1', 'title': 'L', 'body': 'ISI-LAMA', 'tone': 'amber', 'pinned': false,
        'folder': '', 'locked': true, 'updatedAt': '2026-01-01T00:00:00.000',
      };
      final a = await open(seed: {'dataVersion': 1, 'notes': jsonEncode([note])});
      await a.flush();
      final p = await SharedPreferences.getInstance();
      await p.setInt('dataVersion', 1); // simulasi: penanda versi gagal tertulis
      final b = await open();
      await b.flush();
      expect(b.notes.single.body, 'ISI-LAMA');
      expect(p.getInt('dataVersion'), AppStore.dataVersion);
    });
  });

  group('Hapus semua data', () {
    Future<AppStore> richStore() async {
      final s = await open(seed: {});
      s.addTxn(name: 'T', cat: 'food', amount: -1000);
      s.addGoal('G', 1000);
      s.addTodo('Todo', cat: 'Pribadi', tone: 'teal');
      s.addNote(title: 'N', body: 'B');
      s.addNoteFolder('F');
      s.addRecurring(name: 'Kos', cat: 'housing', amount: -1, day: 5);
      s.addCustomCategory('Kopi kenangan', income: false);
      s.setBio('Halo saya Budi');
      s.saveQuickItem(QuickEntry(name: 'Es teh pribadi', cat: 'food', amount: 7000));
      s.setBudget(1234567);
      await s.flush();
      return s;
    }

    test('semua data pengguna kembali ke kondisi awal (termasuk Catat Cepat dan bio)', () async {
      final s = await richStore();
      await s.clearAll();
      expect(s.txns, isEmpty);
      expect(s.goals, isEmpty);
      expect(s.todos, isEmpty);
      expect(s.agenda, isEmpty);
      expect(s.notes, isEmpty);
      expect(s.noteFolders, isEmpty);
      expect(s.recurring, isEmpty);
      expect(s.customCats, isEmpty);
      expect(s.bio, isEmpty);
      expect(s.monthlyBudget, 5000000);
      expect(s.quickItems.map((q) => q.name), isNot(contains('Es teh pribadi')));
      expect(s.quickItems, isNotEmpty); // kembali ke bawaan, bukan kosong
    });

    test('profil dan kemajuan (hari aktif, XP) ikut direset', () async {
      final s = await richStore();
      await s.clearAll();
      expect(s.xp, lessThanOrEqualTo(20)); // hanya hari ini
      expect(s.activeDays.length, 1);
    });

    test('hapus permanen: penyimpanan fisik bersih total, bukan hanya memori', () async {
      final s = await richStore();
      await s.clearAll(keepSafetyCopy: false);
      final p = await SharedPreferences.getInstance();
      final all = p.getKeys().map((k) => '$k=${p.get(k)}').join('\n');
      for (final secret in ['Es teh pribadi', 'Budi', 'Kopi kenangan', '1234567']) {
        expect(all, isNot(contains(secret)), reason: secret);
      }
    });

    test('hapus biasa menyimpan satu salinan (sengaja, bisa dipulihkan) - bukan hapus total', () async {
      final s = await richStore();
      await s.clearAll();
      final p = await SharedPreferences.getInstance();
      expect(p.getString('autoBackup'), contains('Es teh pribadi'));
    });

    test('permanen: salinan cadangan otomatis juga dihapus', () async {
      final s = await richStore();
      await s.clearAll(keepSafetyCopy: false);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('autoBackup'), isNull);
      expect(p.getString('autoBackupAt'), isNull);
      expect(s.hasAutoBackup, isFalse);
    });

    test('biasa: salinan cadangan disimpan dan bisa memulihkan semuanya', () async {
      final s = await richStore();
      await s.clearAll();
      expect(s.hasAutoBackup, isTrue);
      expect(await s.restoreAutoBackup(), isTrue);
      expect(s.txns.single.name, 'T');
      expect(s.goals.single.name, 'G');
      expect(s.notes.single.body, 'B');
      expect(s.customCats.single.label, 'Kopi kenangan');
      expect(s.quickItems.map((q) => q.name), contains('Es teh pribadi'));
      expect(s.bio, 'Halo saya Budi');
      expect(s.monthlyBudget, 1234567);
    });
  });

  group('Cadangan tidak melewatkan data', () {
    test('pengaturan yang memengaruhi laporan ikut dicadangkan (awal bulan, awal minggu, bahasa)', () async {
      final s = await open(seed: {});
      s.addTxn(name: 'x', cat: 'food', amount: -1000);
      s.setMonthStart(25);
      s.setWeekStartMonday(false);
      s.setLang('en');
      s.setFinanceBg('sky');
      final file = s.exportJson();
      final other = await open(seed: {});
      expect(other.monthStartDay, 1);
      expect(await other.importBackup(file), BackupResult.ok);
      expect(other.monthStartDay, 25);
      expect(other.weekStartMonday, isFalse);
      expect(other.lang, 'en');
      expect(other.financeBg, 'sky');
      s.setLang('id');
    });

    test('mata uang selalu Rupiah: data lama/backup berisi USD dibaca sebagai Rupiah', () async {
      final s = await open(seed: {'currency': 'USD'});
      expect(s.currency, 'IDR');
      final file = (await open(seed: {})).exportJson().replaceFirst('"currency": "IDR"', '"currency": "USD"');
      expect(await s.importBackup(file), BackupResult.ok);
      expect(s.currency, 'IDR');
      expect(L.currency, 'IDR');
    });

    test('nama, email, tema, dan mode ikut backup berkata sandi; backup polos tidak membawa nama/email', () async {
      final s = await open(seed: {});
      s.updateProfile(name: 'Budi', email: 'r@contoh.com');
      s.setThemeMode(ThemeMode.dark);
      s.setMode('productive');
      final enc = await s.exportEncrypted('kata-sandi-kuat-1');
      final other = await open(seed: {});
      final insp = await other.inspectBackup(enc, password: 'kata-sandi-kuat-1');
      expect(await other.restoreFrom(insp), BackupResult.ok);
      expect(other.userName, 'Budi');
      expect(other.email, 'r@contoh.com');
      expect(other.themeMode, ThemeMode.dark);
      expect(other.mode, 'productive');

      final plain = s.exportJson();
      expect(plain.contains('Budi'), isFalse);
      expect(plain.contains('r@contoh.com'), isFalse);
      final third = await open(seed: {});
      third.updateProfile(name: 'Lain', email: '');
      expect(await third.importBackup(plain), BackupResult.ok);
      expect(third.userName, 'Lain'); // tidak tertimpa
      expect(third.themeMode, ThemeMode.dark);
    });

    test('backup dengan nama/email/tema/mode tidak valid diabaikan', () async {
      final s = await open(seed: {});
      s.updateProfile(name: 'Asli', email: 'a@b.co');
      final base = s.exportJson();
      final m = jsonDecode(base) as Map<String, dynamic>;
      (m['settings'] as Map)['themeMode'] = 99;
      (m['settings'] as Map)['mode'] = 'hack';
      (m['profile'] as Map)['name'] = 'x' * 500;
      (m['profile'] as Map)['email'] = 'bukan-email';
      expect(await s.importBackup(jsonEncode(m)), BackupResult.ok);
      expect(s.userName, 'Asli');
      expect(s.email, 'a@b.co');
      expect(s.mode, 'finance');
      expect(s.themeMode, ThemeMode.system);
    });

    test('profil (bio, hari bergabung, hari aktif) ikut dicadangkan', () async {
      final s = await open(seed: {});
      s.addTxn(name: 'x', cat: 'food', amount: -1000);
      s.setBio('Bio saya');
      final file = s.exportJson();
      final other = await open(seed: {});
      expect(await other.importBackup(file), BackupResult.ok);
      expect(other.bio, 'Bio saya');
      expect(other.joinedAt, s.joinedAt);
    });

    test('pengaturan keamanan TIDAK ikut (PIN, sidik jari, layar aman)', () async {
      final s = await open(seed: {});
      s.setPin('123456');
      s.addTxn(name: 'x', cat: 'food', amount: -1000);
      final file = s.exportJson();
      expect(file, isNot(contains('pinHash')));
      expect(file, isNot(contains('"pin"')));
      final other = await open(seed: {});
      await other.importBackup(file);
      expect(other.pinEnabled, isFalse);
    });

    test('nilai pengaturan di file diperiksa (tidak percaya begitu saja)', () async {
      final s = await open(seed: {});
      final bad = backupWith([], extra: {
        'settings': {'monthStartDay': 99, 'currency': 'EUR', 'lang': 'xx', 'financeBg': 5, 'weekStartMonday': 'ya'},
        'profile': {'bio': 12345, 'joinedAt': 'bukan-tanggal', 'activeDays': ['2026-01-01', 'sampah', 7]},
      });
      expect(await s.importBackup(jsonEncode(bad)), BackupResult.ok);
      expect(s.monthStartDay, inInclusiveRange(1, 28));
      expect(s.currency, 'IDR');
      expect(s.lang, 'id');
      expect(s.financeBg, 'desert');
      expect(s.activeDays.where((d) => d == 'sampah'), isEmpty);
    });

    test('cadangan otomatis juga dibuat bila hanya ada transaksi berulang atau kategori sendiri', () async {
      final s = await open(seed: {});
      s.addRecurring(name: 'Kos', cat: 'housing', amount: -1, day: 5);
      s.addCustomCategory('Kopi', income: false);
      await s.flush();
      final p = await SharedPreferences.getInstance();
      await p.remove('autoBackup');
      await p.remove('autoBackupAt');
      final b = await open();
      expect(b.hasAutoBackup, isTrue);
    });
  });

  group('Penulisan antre & konsisten', () {
    test('banyak perubahan cepat berurutan: hasil akhir di disk = keadaan terakhir di memori', () async {
      final s = await open(seed: {});
      for (var i = 0; i < 60; i++) {
        s.addTxn(name: 'T$i', cat: 'food', amount: -(i + 1));
        if (i % 7 == 0) s.addGoal('G$i', 1000);
        if (i % 11 == 0 && s.txns.isNotEmpty) s.removeTxn(s.txns.first.id);
      }
      await s.flush();
      final fresh = await open();
      expect(fresh.txns.map((t) => t.id).toSet(), s.txns.map((t) => t.id).toSet());
      expect(fresh.goals.length, s.goals.length);
    });

    test('dua instance bergantian (mis. restart cepat) tidak saling merusak data yang sudah tersimpan', () async {
      final a = await open(seed: {});
      a.addTxn(name: 'A', cat: 'food', amount: -1);
      await a.flush();
      final b = await open();
      b.addTxn(name: 'B', cat: 'food', amount: -2);
      await b.flush();
      final c = await open();
      expect(c.txns.map((t) => t.name).toSet(), {'A', 'B'});
    });
  });
}

/// SharedPreferences yang bisa dipaksa gagal menulis.
class _BrokenPrefs implements SharedPreferences {
  _BrokenPrefs(this.inner);
  final SharedPreferences inner;
  bool fail = false;

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError(i.memberName.toString());

  @override
  Object? get(String key) => inner.get(key);
  @override
  bool containsKey(String key) => inner.containsKey(key);
  @override
  Set<String> getKeys() => inner.getKeys();
  @override
  String? getString(String key) => inner.getString(key);
  @override
  int? getInt(String key) => inner.getInt(key);
  @override
  bool? getBool(String key) => inner.getBool(key);
  @override
  List<String>? getStringList(String key) => inner.getStringList(key);
  @override
  Future<bool> setString(String key, String value) async => fail ? false : inner.setString(key, value);
  @override
  Future<bool> setInt(String key, int value) async => fail ? false : inner.setInt(key, value);
  @override
  Future<bool> setBool(String key, bool value) async => fail ? false : inner.setBool(key, value);
  @override
  Future<bool> setStringList(String key, List<String> value) async => fail ? false : inner.setStringList(key, value);
  @override
  Future<bool> remove(String key) async => fail ? false : inner.remove(key);
}
