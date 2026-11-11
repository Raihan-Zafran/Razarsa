import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/data/models.dart';
import 'package:razarsa/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'package:razarsa/core/notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tzdata.initializeTimeZones(); // sebelum grup di bawah membaca zona waktu

  group('Zona waktu cadangan', () {
    test('offset +7 jatuh ke Asia/Jakarta (bukan UTC)', () {
      final l = Notif.locationForOffset(const Duration(hours: 7));
      expect(l.name, 'Asia/Jakarta');
      expect(tz.TZDateTime.now(l).timeZoneOffset, const Duration(hours: 7));
    });

    test('offset +8 dan +9 jatuh ke zona Indonesia timur', () {
      expect(Notif.locationForOffset(const Duration(hours: 8)).name, 'Asia/Makassar');
      expect(Notif.locationForOffset(const Duration(hours: 9)).name, 'Asia/Jayapura');
    });

    test('offset lain dapat zona yang offsetnya sama', () {
      final l = Notif.locationForOffset(const Duration(hours: 1));
      expect(tz.TZDateTime.now(l).timeZoneOffset, const Duration(hours: 1));
    });

    test('offset yang tidak ada di dunia jatuh ke UTC', () {
      expect(Notif.locationForOffset(const Duration(hours: 5, minutes: 7)), tz.UTC);
    });
  });

  group('Pengingat tagihan: jadwal', () {
    final jkt = tz.getLocation('Asia/Jakarta');
    tz.TZDateTime at(int y, int m, int d, [int h = 12, int min = 0]) => tz.TZDateTime(jkt, y, m, d, h, min);

    test('tanggal 1: diingatkan di hari-H pukul 08.00 (bukan "besok")', () {
      final r = Notif.billReminderAt(1, at(2026, 11, 10));
      expect(r.sameDay, isTrue);
      expect(r.at, at(2026, 12, 1, 8)); // 1 Nov sudah lewat -> 1 Des
    });

    test('tanggal 1 sebelum waktunya: bulan ini', () {
      final r = Notif.billReminderAt(1, tz.TZDateTime(jkt, 2026, 11, 1, 7, 0));
      expect(r.at, tz.TZDateTime(jkt, 2026, 11, 1, 8));
    });

    test('tanggal 5: sehari sebelumnya (tanggal 4) pukul 09.00', () {
      final r = Notif.billReminderAt(5, at(2026, 11, 2));
      expect(r.sameDay, isFalse);
      expect(r.at, at(2026, 11, 4, 9));
    });

    test('waktu pengingat bulan ini sudah lewat: bulan depan', () {
      expect(Notif.billReminderAt(5, at(2026, 11, 4, 10)).at, at(2026, 12, 4, 9));
      // tepat pada waktunya juga dianggap lewat
      expect(Notif.billReminderAt(5, at(2026, 11, 4, 9)).at, at(2026, 12, 4, 9));
    });

    test('pergantian tahun: Desember -> Januari tahun berikutnya', () {
      expect(Notif.billReminderAt(5, at(2026, 12, 20)).at, at(2027, 1, 4, 9));
      expect(Notif.billReminderAt(1, at(2026, 12, 20)).at, at(2027, 1, 1, 8));
    });

    test('tanggal di luar 1-28 dijepit (tanggal 31 -> 28 -> diingatkan tanggal 27)', () {
      expect(Notif.billReminderAt(31, at(2026, 11, 2)).at, at(2026, 11, 27, 9));
      expect(Notif.billReminderAt(0, at(2026, 11, 2)).sameDay, isTrue);
    });
  });

  group('Inisialisasi notifikasi', () {
    test('dipanggil bersamaan dari banyak tempat: penyiapan hanya berjalan sekali', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Notif.initRuns = 0;
      await Future.wait(List.generate(12, (_) => Notif.init()));
      expect(Notif.initRuns, 1);
    });
  });

  group('Izin notifikasi', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    var enabled = false;
    var grantsOnRequest = false;
    var requests = 0;
    var throwOnCheck = false;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'areNotificationsEnabled':
            if (throwOnCheck) throw PlatformException(code: 'x');
            return enabled;
          case 'requestNotificationsPermission':
            requests++;
            if (grantsOnRequest) enabled = true;
            return grantsOnRequest;
          case 'initialize':
            return true;
          default:
            return null;
        }
      });
    });

    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    setUp(() {
      enabled = false;
      grantsOnRequest = false;
      requests = 0;
      throwOnCheck = false;
    });

    test('sudah diizinkan: tidak meminta lagi', () async {
      enabled = true;
      expect(await Notif.requestPermission(), isTrue);
      expect(requests, 0);
    });

    test('belum diizinkan lalu pengguna menyetujui: true', () async {
      grantsOnRequest = true;
      expect(await Notif.requestPermission(), isTrue);
      expect(requests, 1);
    });

    test('pengguna menolak: false (pemanggil menampilkan petunjuk, saklar tidak dinyalakan)', () async {
      expect(await Notif.requestPermission(), isFalse);
      expect(requests, 1);
    });

    test('kegagalan membaca/meminta izin: dianggap tidak diizinkan, tidak crash', () async {
      throwOnCheck = true;
      expect(await Notif.requestPermission(), isFalse);
    });

    test('enabled() mencerminkan status sebenarnya (mis. diblokir di Pengaturan HP)', () async {
      enabled = false;
      expect(await Notif.enabled(), isFalse);
      enabled = true;
      expect(await Notif.enabled(), isTrue);
    });
  });

  group('Transaksi berulang diproses saat aplikasi dibuka kembali', () {
    Future<AppStore> store() async {
      SharedPreferences.setMockInitialValues({});
      return AppStore(await SharedPreferences.getInstance(), vault: testVault);
    }

    String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

    test('pergantian bulan saat app tetap hidup: dicatat dan layar diberi tahu', () async {
      final s = await store();
      final now = DateTime.now();
      final prev = DateTime(now.year, now.month - 1);
      s.recurring.add(Recurring(id: 'r', name: 'Kos', cat: 'housing', amount: -800000, day: 1, lastPosted: key(prev)));
      var notified = 0;
      s.addListener(() => notified++);
      var budgetChecks = 0;
      s.onExpenseAdded = () => budgetChecks++;
      expect(s.postRecurring(), 1); // = yang dipanggil saat aplikasi kembali ke depan
      expect(s.txns.single.name, 'Kos');
      expect(notified, greaterThan(0));
      expect(budgetChecks, 1);
      expect(s.postRecurring(), 0); // dibuka lagi: tidak ganda
      expect(budgetChecks, 1);
    });

    test('pemasukan berulang tidak memicu peringatan anggaran', () async {
      final s = await store();
      final prev = DateTime(DateTime.now().year, DateTime.now().month - 1);
      s.recurring.add(Recurring(id: 'g', name: 'Gaji', cat: 'salary', amount: 5000000, day: 1, lastPosted: key(prev)));
      var budgetChecks = 0;
      s.onExpenseAdded = () => budgetChecks++;
      expect(s.postRecurring(), 1);
      expect(budgetChecks, 0);
    });

    test('hasil tersimpan permanen (tidak hilang bila app ditutup setelahnya)', () async {
      final s = await store();
      final prev = DateTime(DateTime.now().year, DateTime.now().month - 2);
      s.recurring.add(Recurring(id: 'r', name: 'Kos', cat: 'housing', amount: -1, day: 1, lastPosted: key(prev)));
      s.postRecurring();
      await s.flush();
      final p = await SharedPreferences.getInstance();
      expect((jsonDecode(p.getString('txns')!) as List).length, 2);
      expect(jsonDecode(p.getString('recurring')!)[0]['lastPosted'], key(DateTime(DateTime.now().year, DateTime.now().month)));
    });
  });

  group('Notifikasi ikut terhapus (sampai ke sistem notifikasi)', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'initialize' ? true : null;
      });
    });
    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });
    setUp(calls.clear);

    List<int> cancelled() => [
          for (final c in calls)
            if (c.method == 'cancel') (c.arguments as Map)['id'] as int
        ];
    List<int> scheduled() => [
          for (final c in calls)
            if (c.method == 'zonedSchedule') (c.arguments as Map)['id'] as int
        ];

    Future<AppStore> wired() async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      s.setSwitch('bill', true);
      // Sama persis dengan penyambungan di main().
      s.onRecurringChanged = ({List<int> cancelIds = const []}) => Notif.syncBills(s, cancelIds: cancelIds);
      return s;
    }

    test('hapus transaksi berulang: notifikasi tagihannya dibatalkan, yang lain tetap terjadwal', () async {
      final s = await wired();
      final a = s.addRecurring(name: 'Kos', cat: 'housing', amount: -800000, day: 5);
      final b = s.addRecurring(name: 'Netflix', cat: 'bills', amount: -54000, day: 12);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(scheduled(), containsAll([a.notifId, b.notifId]));
      calls.clear();
      s.removeRecurring(a.id);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cancelled(), contains(a.notifId), reason: 'yang dihapus harus dibatalkan');
      expect(scheduled(), isNot(contains(a.notifId)));
      expect(scheduled(), contains(b.notifId));
    });

    test('hapus semua data: semua notifikasi tagihan dibatalkan', () async {
      final s = await wired();
      final a = s.addRecurring(name: 'Kos', cat: 'housing', amount: -800000, day: 5);
      final b = s.addRecurring(name: 'Netflix', cat: 'bills', amount: -54000, day: 12);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      calls.clear();
      await s.clearAll();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cancelled(), containsAll([a.notifId, b.notifId]));
      expect(scheduled(), isEmpty);
    });

    test('mematikan saklar pengingat tagihan: semua dibatalkan dan tidak dijadwalkan ulang', () async {
      final s = await wired();
      final a = s.addRecurring(name: 'Kos', cat: 'housing', amount: -800000, day: 5);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      calls.clear();
      s.setSwitch('bill', false);
      await Notif.syncBills(s);
      expect(cancelled(), contains(a.notifId));
      expect(scheduled(), isEmpty);
    });

    test('pemasukan berulang tidak dapat pengingat tagihan', () async {
      final s = await wired();
      final g = s.addRecurring(name: 'Gaji', cat: 'salary', amount: 5000000, day: 25);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(scheduled(), isNot(contains(g.notifId)));
    });

    test('impor backup: pengingat tagihan dari data lama dibatalkan', () async {
      final s = await wired();
      final old = s.addRecurring(name: 'Kos', cat: 'housing', amount: -800000, day: 5);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      calls.clear();
      final r = await s.importBackup(jsonEncode({'app': 'razarsa', 'version': 2, 'txns': [], 'goals': [], 'customCats': []}));
      expect(r, BackupResult.ok);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cancelled(), contains(old.notifId));
    });
  });
}
