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

  static NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'razarsa_main',
          'Razarsa',
          channelDescription: 'Pengingat & peringatan anggaran',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );

  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Razarsa: zona waktu gagal: $e');
      // Zona waktu tidak dikenal: pakai bawaan.
    }
    try {
      await _p.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Razarsa: notifikasi gagal disiapkan: $e');
    }
  }

  /// Minta izin notifikasi (Android 13+). Mengembalikan true kalau diizinkan.
  static Future<bool> requestPermission() async {
    await init();
    final android = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
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
  static Future<void> checkBudget(AppStore store) async {
    if (store.switches['budgetAlert'] != true || store.monthlyBudget <= 0) return;
    final pct = store.monthExpense() / store.monthlyBudget;
    final period = store.periodStart().toIso8601String().substring(0, 10);
    if (pct < 0.9 || store.budgetAlertSent == period) return;
    store.budgetAlertSent = period;
    await init();
    if (!_ready) return;
    await _p.show(
      id: _budgetId,
      title: tr('Anggaran hampir habis'),
      body: trf('Pengeluaran bulan ini sudah {0}% dari anggaran.', [(pct * 100).round()]),
      notificationDetails: _details,
    );
  }

  /// Jadwalkan / batalkan notifikasi untuk satu pengingat di kalender.
  static Future<void> syncAgenda(Agenda a, {bool removed = false, bool enabled = true}) async {
    await init();
    if (!_ready) return;
    await _p.cancel(id: a.notifId);
    if (removed || !enabled || !a.reminder || !a.on) return;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, a.at.year, a.at.month, a.at.day, a.at.hour, a.at.minute);
    if (a.daily) {
      at = tz.TZDateTime(tz.local, now.year, now.month, now.day, a.at.hour, a.at.minute);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    } else if (!at.isAfter(now)) {
      return;
    }
    await _p.zonedSchedule(
      id: a.notifId,
      title: a.title,
      body: tr('Pengingat dari Razarsa'),
      scheduledDate: at,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: a.daily ? DateTimeComponents.time : null,
    );
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
      final day = r.day > 1 ? r.day - 1 : 1;
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(tz.local, now.year, now.month, day, 9);
      if (!at.isAfter(now)) at = tz.TZDateTime(tz.local, now.year, now.month + 1, day, 9);
      await _p.zonedSchedule(
        id: r.notifId,
        title: trf('Besok tagihan {0}', [r.name]),
        body: trf('Jangan lupa siapkan {0}.', [rp(-r.amount)]),
        scheduledDate: at,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }
}
