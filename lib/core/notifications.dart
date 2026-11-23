import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/productive_models.dart';
import '../data/store.dart';
import 'format.dart';
import 'i18n.dart';

/// Notifikasi lokal: pengingat harian & peringatan anggaran.
class Notif {
  static final _p = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _dailyId = 1;
  static const _budgetId = 2;

  /// Isi notifikasi (judul agenda, nama tagihan, nominal) disembunyikan di layar kunci.
  static NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'razarsa_main',
          'Razarsa',
          channelDescription: 'Pengingat & peringatan anggaran',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility: NotificationVisibility.private,
        ),
      );

  /// Zona waktu yang offsetnya [offset] saat ini; Asia/Jakarta, Makassar, dan Jayapura diutamakan.
  /// UTC kalau tidak ada yang cocok.
  @visibleForTesting
  static tz.Location locationForOffset(Duration offset) {
    const preferred = ['Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura'];
    final now = DateTime.now().toUtc();
    bool matches(tz.Location l) => tz.TZDateTime.from(now, l).timeZoneOffset == offset;
    for (final name in preferred) {
      final l = tz.timeZoneDatabase.locations[name];
      if (l != null && matches(l)) return l;
    }
    for (final l in tz.timeZoneDatabase.locations.values) {
      if (matches(l)) return l;
    }
    return tz.UTC;
  }

  static bool get _win => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// AppUserModelID aplikasi di Windows (harus sama dengan pintasan Start di pemasang).
  static const windowsAumid = 'Razarsa.Razarsa.App';

  /// Ikon toast: berkas PNG di folder aset aplikasi (di sebelah razarsa.exe).
  static String? _windowsIcon() {
    try {
      final dir = File(Platform.resolvedExecutable).parent.path;
      final f = File('$dir\\data\\flutter_assets\\assets\\images\\app_icon.png');
      return f.existsSync() ? f.path : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void>? _initFuture;

  /// Berapa kali penyiapan sungguhan dijalankan (untuk tes: harus 1 walau dipanggil bersamaan).
  @visibleForTesting
  static int initRuns = 0;

  /// Aman dipanggil bersamaan dari banyak tempat: penyiapan hanya jalan sekali. Kalau gagal,
  /// panggilan berikutnya mencoba lagi.
  static Future<void> init() {
    if (kIsWeb || _ready) return Future<void>.value();
    return _initFuture ??= _doInit().whenComplete(() {
      if (!_ready) _initFuture = null;
    });
  }

  static Future<void> _doInit() async {
    initRuns++;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Razarsa: zona waktu gagal: $e');
      // Zona waktu tidak terbaca: cari zona yang offsetnya sama dengan jam HP. Tanpa ini
      // semua pengingat dijadwalkan dalam UTC (bergeser beberapa jam) tanpa peringatan.
      try {
        tz.setLocalLocation(locationForOffset(DateTime.now().timeZoneOffset));
      } catch (e2) {
        debugPrint('Razarsa: zona waktu cadangan gagal: $e2');
      }
    }
    try {
      await _p.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Windows: notifikasi toast. AUMID sama dengan pintasan Start dari pemasang (windows/installer/razarsa.iss).
          windows: _win
              ? WindowsInitializationSettings(
                  appName: 'Razarsa',
                  appUserModelId: windowsAumid,
                  guid: 'a7c3f2e1-5b4d-4e8a-9c21-6f0b3d7e8a14',
                  iconPath: _windowsIcon(),
                )
              : null,
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Razarsa: notifikasi gagal disiapkan: $e');
    }
  }

  /// Apakah notifikasi boleh tampil sekarang (izin diberikan dan tidak diblokir di Pengaturan HP).
  static Future<bool> enabled() async {
    if (kIsWeb || _win) return true;
    await init();
    try {
      final android = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? true;
    } catch (e) {
      debugPrint('Razarsa: gagal membaca status izin notifikasi: $e');
      return true;
    }
  }

  /// Minta izin notifikasi (Android 13+) hanya kalau belum diizinkan. true = notifikasi bisa tampil.
  /// false = ditolak/diblokir; pemanggil wajib memberi tahu pengguna cara mengaktifkannya.
  static Future<bool> requestPermission() async {
    if (kIsWeb || _win) return true; // Windows tidak meminta izin; pengguna mengaturnya di Pengaturan Windows
    await init();
    try {
      final android = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return true; // bukan Android: tidak ada izin yang perlu diminta
      if (await android.areNotificationsEnabled() ?? false) return true;
      await android.requestNotificationsPermission();
      return await android.areNotificationsEnabled() ?? false;
    } catch (e) {
      debugPrint('Razarsa: gagal meminta izin notifikasi: $e');
      return false;
    }
  }

  /// Pasang / matikan pengingat harian pukul 20.00.
  static Future<void> syncDaily(bool on) async {
    await init();
    if (!_ready) return;
    await _p.cancel(id: _dailyId);
    if (!on) return;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _p.zonedSchedule(
      id: _dailyId,
      title: tr('Sudah catat keuanganmu hari ini?'),
      body: tr('Luangkan 1 menit untuk mencatat pengeluaran hari ini.'),
      scheduledDate: at,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Dipanggil setelah pengeluaran dicatat: beri tahu sekali per periode kalau anggaran ≥ 90%.
  /// Nomor notifikasi tetap per kategori: 100..899 (tagihan 500.000+, agenda 1.000.000.000+, tugas 1.500.000.000+).
  /// Hash FNV sendiri karena String.hashCode tidak dijamin sama antar-proses.
  @visibleForTesting
  static int categoryNotifId(String id) {
    var h = 0x811c9dc5;
    for (final u in id.codeUnits) {
      h = ((h ^ u) * 0x01000193) & 0xffffffff;
    }
    return 100 + h % 800;
  }

  static int _categoryNotifId(String id) => categoryNotifId(id);

  static Future<void> checkBudget(AppStore store) async {
    if (store.switches['budgetAlert'] != true) return;
    final period = store.periodStart().toIso8601String().substring(0, 10);
    final alerts = <(int, String, String)>[]; // (id notifikasi, judul, isi)
    if (store.monthlyBudget > 0) {
      final pct = store.monthExpense() / store.monthlyBudget;
      if (pct >= 0.9 && store.budgetAlertSent != period) {
        store.markBudgetAlert(period);
        alerts.add((
          _budgetId,
          tr('Anggaran hampir habis'),
          trf('Pengeluaran bulan ini sudah {0}% dari anggaran.', [(pct * 100).round()]),
        ));
      }
    }
    for (final e in store.catBudgets.entries) {
      if (store.catAlertSent[e.key] == period) continue;
      final pct = store.categorySpent(e.key) / e.value;
      if (pct < 0.9) continue;
      store.markCategoryAlert(e.key, period);
      final label = store.category(e.key).label;
      alerts.add((
        _categoryNotifId(e.key),
        trf('Anggaran {0} hampir habis', [label]),
        trf('Pengeluaran {0} sudah {1}% dari batas.', [label, (pct * 100).round()]),
      ));
    }
    if (alerts.isEmpty) return;
    await init();
    if (!_ready) return;
    for (final a in alerts) {
      await _p.show(id: a.$1, title: a.$2, body: a.$3, notificationDetails: _details);
    }
  }

  /// Waktu notifikasi berikutnya untuk agenda [a] (mulai dikurangi [Agenda.remindMin]), setelah [now].
  /// Null kalau agenda sekali dan waktunya sudah lewat.
  @visibleForTesting
  static tz.TZDateTime? agendaFireAt(Agenda a, tz.TZDateTime now) {
    final lead = Duration(minutes: a.remindMin);
    tz.TZDateTime fireOf(DateTime d) => tz.TZDateTime(now.location, d.year, d.month, d.day, d.hour, d.minute).subtract(lead);
    final first = fireOf(a.at);
    if (a.repeat == 'none') return first.isAfter(now) ? first : null;
    // Agenda berulang: kemunculan ke-k dihitung dari tanggal asli (bulanan tidak bergeser ke tgl 28).
    for (var k = 0; k < 100000; k++) {
      final fire = fireOf(repeatOccurrence(a.at, a.repeat, k));
      if (fire.isAfter(now)) return fire;
    }
    return null;
  }

  /// Jadwalkan / batalkan notifikasi untuk satu agenda di kalender.
  static Future<void> syncAgenda(Agenda a, {bool removed = false, bool enabled = true}) async {
    await init();
    if (!_ready) return;
    await _p.cancel(id: a.notifId);
    await _p.cancel(id: a.legacyNotifId); // jadwal dari versi lama
    if (removed || !enabled || !a.reminder || !a.on) return;
    final at = agendaFireAt(a, tz.TZDateTime.now(tz.local));
    if (at == null) return;
    try {
      await _p.zonedSchedule(
        id: a.notifId,
        title: a.title,
        body: a.loc.isEmpty ? tr('Pengingat dari Razarsa') : '${timeLabel(a.at)} · ${a.loc}',
        scheduledDate: at,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: switch (a.repeat) {
          'daily' => DateTimeComponents.time,
          'weekly' => DateTimeComponents.dayOfWeekAndTime,
          // Tanggal 29–31 tidak ada di semua bulan: jadwal sekali saja, dipasang ulang tiap aplikasi dibuka.
        'monthly' => a.at.day > 28 ? null : DateTimeComponents.dayOfMonthAndTime,
          _ => null,
        },
      );
    } catch (e) {
      debugPrint('Razarsa: pengingat gagal dijadwalkan: $e');
    }
  }

  /// Jadwalkan ulang semua pengingat agenda dan tugas. Dipanggil saat aplikasi dibuka: di Windows
  /// notifikasi berulang tidak diulang otomatis oleh sistem, jadi jadwal berikutnya dipasang setiap kali.
  static Future<void> syncProductive(AppStore store) async {
    final on = store.switches['agenda'] == true;
    for (final a in [...store.agenda]) {
      await syncAgenda(a, enabled: on);
    }
    for (final t in [...store.todos]) {
      await syncTodo(t, enabled: on);
    }
  }

  /// Jadwalkan / batalkan pengingat satu tugas (sekali, [Todo.remind] menit sebelum tenggat).
  static Future<void> syncTodo(Todo t, {bool removed = false, bool enabled = true}) async {
    await init();
    if (!_ready) return;
    await _p.cancel(id: t.notifId);
    await _p.cancel(id: t.legacyNotifId); // jadwal dari versi lama
    final at = t.remindAt;
    if (removed || !enabled || t.done || at == null || !at.isAfter(DateTime.now())) return;
    try {
      await _p.zonedSchedule(
        id: t.notifId,
        title: t.title,
        body: trf('Tugas · tenggat {0}', [t.hasTime ? '${dayLabel(t.due!)}, ${timeLabel(t.due!)}' : dayLabel(t.due!)]),
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Razarsa: pengingat gagal dijadwalkan: $e');
    }
  }

  /// Waktu pengingat tagihan untuk tanggal jatuh tempo [dueDay] (1-28), dihitung dari [now]:
  /// sehari sebelumnya pukul 09.00. Tanggal 1 tidak punya "sehari sebelumnya" di bulan yang
  /// sama, jadi diingatkan di hari-H pukul 08.00. Kalau waktunya sudah lewat bulan ini, bulan depan.
  @visibleForTesting
  static ({tz.TZDateTime at, bool sameDay}) billReminderAt(int dueDay, tz.TZDateTime now) {
    final d = dueDay.clamp(1, 28);
    final sameDay = d <= 1;
    final day = sameDay ? 1 : d - 1;
    final hour = sameDay ? 8 : 9;
    var at = tz.TZDateTime(now.location, now.year, now.month, day, hour);
    if (!at.isAfter(now)) at = tz.TZDateTime(now.location, now.year, now.month + 1, day, hour);
    return (at: at, sameDay: sameDay);
  }

  /// Pengingat tagihan: sehari sebelum transaksi berulang (pengeluaran) jatuh tempo, pukul 09.00.
  static Future<void> syncBills(AppStore store, {List<int> cancelIds = const []}) async {
    await init();
    if (!_ready) return;
    for (final id in cancelIds) {
      await _p.cancel(id: id);
    }
    for (final r in store.recurring) {
      await _p.cancel(id: r.notifId);
      if (store.switches['bill'] != true || !r.isExpense) continue;
      final (:at, :sameDay) = billReminderAt(r.day, tz.TZDateTime.now(tz.local));
      await _p.zonedSchedule(
        id: r.notifId,
        title: trf(sameDay ? 'Hari ini tagihan {0}' : 'Besok tagihan {0}', [r.name]),
        body: trf('Jangan lupa siapkan {0}.', [rp(-r.amount)]),
        scheduledDate: at,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  static const _testId = 3;

  /// Uji kemampuan notifikasi di HP ini: tampil sekarang, lalu jadwalkan satu lagi 1 menit ke depan
  /// (jalur yang dipakai semua pengingat). Mengembalikan kode hasil: 'ok', 'denied', 'notready',
  /// atau 'error: ...'.
  static Future<String> selfTest() async {
    if (kIsWeb) return 'ok';
    await init();
    if (!_ready) return 'notready';
    if (!await enabled()) return 'denied';
    try {
      await _p.show(
        id: _testId,
        title: tr('Tes notifikasi'),
        body: tr('Notifikasi langsung berfungsi.'),
        notificationDetails: _details,
      );
      final at = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
      await _p.zonedSchedule(
        id: _testId + 1,
        title: tr('Tes notifikasi'),
        body: tr('Pengingat terjadwal berfungsi.'),
        scheduledDate: at,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return 'ok';
    } catch (e) {
      debugPrint('Razarsa: tes notifikasi gagal: $e');
      return 'error: $e';
    }
  }
}
