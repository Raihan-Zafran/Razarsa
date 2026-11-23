import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/format.dart';
import 'package:razarsa/core/notifications.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/productive_models.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/productive/todo_detail.dart';
import 'package:razarsa/features/productive/todo_page.dart';
import 'package:razarsa/features/productive/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'helpers.dart';

Future<AppStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    tzdata.initializeTimeZones();
  });

  group('Tugas: data baru', () {
    test('prioritas, catatan, sub-tugas, pengingat, ulangi tersimpan dan terbaca lagi', () async {
      final s = await newStore();
      final t = s.addTodo('Laporan', cat: 'Kerja', tone: 'orange', due: DateTime(2026, 11, 20, 10), pri: 'tinggi', notes: 'kirim ke atasan', remind: 60, repeat: 'weekly');
      t.subs.add(SubTask('Kumpulkan data', done: true));
      t.subs.add(SubTask('Tulis ringkasan'));
      s.updateTodo(t);
      final back = Todo.fromJson(t.toJson());
      expect(back.pri, 'tinggi');
      expect(back.notes, 'kirim ke atasan');
      expect(back.subs.map((x) => (x.t, x.done)).toList(), [('Kumpulkan data', true), ('Tulis ringkasan', false)]);
      expect(back.remind, 60);
      expect(back.repeat, 'weekly');
      expect(back.remindAt, DateTime(2026, 11, 20, 9));
    });

    test('data lama tanpa kolom baru tetap terbaca dengan nilai bawaan; data rusak tidak membuat galat', () {
      final old = Todo.fromJson({'id': '1', 'title': 'Lama', 'cat': 'Kerja', 'tone': 'orange'});
      expect((old.pri, old.notes, old.subs.length, old.remind, old.repeat), ('sedang', '', 0, 0, 'none'));
      final bad = Todo.fromJson({'id': '2', 'title': 'x', 'pri': 'aneh', 'subs': [1, null, {'t': ''}, {'t': 'ok'}], 'remind': -5, 'repeat': 'tiap jam'});
      expect((bad.pri, bad.subs.length, bad.remind, bad.repeat), ('sedang', 1, 0, 'none'));
    });

    test('tugas berulang: selesai membuat satu tugas berikutnya; batal-selesai menghapusnya lagi (tidak dobel)', () async {
      final s = await newStore();
      final now = DateTime(2026, 1, 31, 12);
      final t = s.addTodo('Olahraga', cat: 'Sehat', tone: 'pink', due: DateTime(2026, 1, 31, 6), repeat: 'monthly');
      t.subs.add(SubTask('Pemanasan', done: true));
      s.toggleTodo(t.id, now: now);
      expect(s.todos.length, 2);
      final next = s.todos.last;
      expect(next.due, DateTime(2026, 2, 28, 6), reason: '31 Januari + 1 bulan = akhir Februari');
      expect((next.done, next.subs.single.done, next.repeat, t.repeat), (false, false, 'monthly', 'monthly'));
      // Batal-selesai: tugas berikutnya hilang lagi.
      s.toggleTodo(t.id, now: now);
      expect(s.todos.map((x) => x.id), [t.id]);
      // Selesai lagi: tetap satu tugas berikutnya.
      s.toggleTodo(t.id, now: now);
      s.toggleTodo(t.id, now: now);
      s.toggleTodo(t.id, now: now);
      expect(s.todos.length, 2);
    });

    test('tugas berulang tanpa tenggat tetap berulang; yang terlambat lanjut ke tanggal sesudah hari ini', () async {
      final s = await newStore();
      final now = DateTime(2026, 11, 20, 9);
      final a = s.addTodo('Baca buku', cat: 'Pribadi', tone: 'teal', repeat: 'daily');
      s.toggleTodo(a.id, now: now);
      expect(s.todos.last.due, DateTime(2026, 11, 21), reason: 'tanpa tenggat: berikutnya besok');
      final b = s.addTodo('Lapor', cat: 'Kerja', tone: 'orange', due: DateTime(2026, 11, 10), repeat: 'daily');
      s.toggleTodo(b.id, now: now);
      expect(s.todos.last.due, DateTime(2026, 11, 21), reason: 'terlambat 10 hari: tidak membuat tugas yang juga terlambat');
      final c = s.addTodo('Rapat', cat: 'Kerja', tone: 'orange', due: DateTime(2026, 11, 20, 8), repeat: 'weekly');
      s.toggleTodo(c.id, now: now);
      expect(s.todos.last.due, DateTime(2026, 11, 27, 8));
    });

    test('pengulangan bulanan dihitung dari tanggal asli, tidak bergeser ke tanggal 28', () {
      final a = DateTime(2026, 1, 31, 9);
      expect([for (var k = 0; k < 4; k++) repeatOccurrence(a, 'monthly', k)],
          [DateTime(2026, 1, 31, 9), DateTime(2026, 2, 28, 9), DateTime(2026, 3, 31, 9), DateTime(2026, 4, 30, 9)]);
    });

    test('nomor notifikasi tugas, agenda, dan tagihan tidak pernah bertabrakan', () {
      final ids = ['1', '999999999', '1763290000123456', '1763290000999999', '1500000000000000'];
      for (final id in ids) {
        final t = Todo(id: id, title: 'x', cat: 'Kerja', tone: 'orange').notifId;
        final a = Agenda(id: id, title: 'x', at: DateTime(2026)).notifId;
        expect(t, inInclusiveRange(1500000000, 2099999999));
        expect(a, inInclusiveRange(1000000000, 1499999999));
        expect(t, lessThanOrEqualTo(2147483647));
      }
    });

    test('hapus lalu urungkan mengembalikan tugas yang sama', () async {
      final s = await newStore();
      final t = s.addTodo('A', cat: 'Kerja', tone: 'orange');
      s.removeTodo(t.id);
      expect(s.todos, isEmpty);
      s.restoreTodo(t);
      expect(s.todos.single.id, t.id);
    });

    test('kelompok tenggat', () {
      final now = DateTime(2026, 11, 12, 12); // Kamis
      Todo at(DateTime? d) => Todo(id: 'x', title: 'x', cat: 'Kerja', tone: 'orange', due: d);
      expect(at(DateTime(2026, 11, 11)).bucket(now: now), 'late');
      expect(at(DateTime(2026, 11, 12, 9)).bucket(now: now), 'late', reason: 'jamnya sudah lewat');
      expect(at(DateTime(2026, 11, 12)).bucket(now: now), 'today');
      expect(at(DateTime(2026, 11, 13)).bucket(now: now), 'tomorrow');
      expect(at(DateTime(2026, 11, 15)).bucket(now: now), 'week', reason: 'Minggu masih minggu ini (mulai Senin)');
      expect(at(DateTime(2026, 11, 16)).bucket(now: now), 'later');
      expect(at(null).bucket(now: now), 'none');
    });

    test('saring dan urutkan: kata kunci juga mencari catatan; prioritas; status', () async {
      final s = await newStore();
      final now = dayOnly(DateTime.now());
      s.addTodo('Balas email', cat: 'Kerja', tone: 'orange', due: now.add(const Duration(days: 3)), pri: 'rendah');
      s.addTodo('Servis motor', cat: 'Pribadi', tone: 'teal', due: now.add(const Duration(days: 1)), pri: 'tinggi', notes: 'ganti oli');
      final done = s.addTodo('Bayar listrik', cat: 'Tagihan', tone: 'blue', due: now);
      s.toggleTodo(done.id);
      final q = TaskQuery()..q = 'oli';
      expect(q.apply(s).map((t) => t.title), ['Servis motor']);
      q
        ..q = ''
        ..sort = 'pri';
      expect(q.apply(s).first.title, 'Servis motor');
      q.pri = 'rendah';
      expect(q.apply(s).map((t) => t.title), ['Balas email']);
      q
        ..pri = ''
        ..status = 'done';
      expect(q.apply(s).map((t) => t.title), ['Bayar listrik']);
      expect(q.counts(s), {'all': 3, 'open': 2, 'today': 0, 'late': 0, 'done': 1});
      final groups = TaskQuery().groups(s, TaskQuery().apply(s));
      expect(groups.map((g) => g.$1), ['tomorrow', 'week', 'done'].where((k) => groups.any((g) => g.$1 == k)).toList());
      expect(groups.last.$1, 'done');
    });
  });

  group('Agenda: data baru', () {
    test('ulangi mingguan / bulanan muncul di tanggal yang benar', () {
      final w = Agenda(id: '1', title: 'Rapat', at: DateTime(2026, 11, 12, 10), repeat: 'weekly');
      expect(w.occursOn(DateTime(2026, 11, 19)), isTrue);
      expect(w.occursOn(DateTime(2026, 11, 20)), isFalse);
      expect(w.occursOn(DateTime(2026, 11, 5)), isFalse, reason: 'sebelum mulai');
      final m = Agenda(id: '2', title: 'Gajian', at: DateTime(2026, 1, 31, 9), repeat: 'monthly');
      expect(m.occursOn(DateTime(2026, 2, 28)), isTrue, reason: 'hari terakhir Februari');
      expect(m.occursOn(DateTime(2026, 3, 31)), isTrue);
      expect(m.occursOn(DateTime(2026, 3, 30)), isFalse);
    });

    test('data lama "daily" terbaca sebagai harian; lokasi, durasi, warna tersimpan', () {
      final old = Agenda.fromJson({'id': '1', 'title': 'Obat', 'at': '2026-11-06T07:00:00.000', 'reminder': true, 'daily': true});
      expect(old.repeat, 'daily');
      expect(old.durMin, 60);
      final a = Agenda(id: '3', title: 'Futsal', at: DateTime(2026, 11, 12, 19, 30), loc: 'GOR', durMin: 120, tone: 'green', repeat: 'weekly', reminder: true, remindMin: 10);
      final back = Agenda.fromJson(a.toJson());
      expect((back.loc, back.durMin, back.tone, back.repeat, back.remindMin), ('GOR', 120, 'green', 'weekly', 10));
      expect(back.end, DateTime(2026, 11, 12, 21, 30));
    });

    test('waktu notifikasi: sekali / berulang, dikurangi menit pengingat', () {
      final loc = tz.getLocation('Asia/Jakarta');
      final now = tz.TZDateTime(loc, 2026, 11, 12, 12);
      final once = Agenda(id: '1', title: 'x', at: DateTime(2026, 11, 12, 15), reminder: true, remindMin: 60);
      expect(Notif.agendaFireAt(once, now), tz.TZDateTime(loc, 2026, 11, 12, 14));
      final past = Agenda(id: '2', title: 'x', at: DateTime(2026, 11, 12, 9), reminder: true);
      expect(Notif.agendaFireAt(past, now), isNull);
      final weekly = Agenda(id: '3', title: 'x', at: DateTime(2026, 11, 5, 9), reminder: true, remindMin: 10, repeat: 'weekly');
      expect(Notif.agendaFireAt(weekly, now), tz.TZDateTime(loc, 2026, 11, 19, 8, 50));
      final monthly = Agenda(id: '4', title: 'x', at: DateTime(2026, 1, 31, 8), reminder: true, repeat: 'monthly');
      expect(Notif.agendaFireAt(monthly, tz.TZDateTime(loc, 2026, 3, 1)), tz.TZDateTime(loc, 2026, 3, 31, 8), reason: 'bukan 28 Maret');
    });
  });

  group('Tampilan', () {
    Future<void> show(WidgetTester t, AppStore s, Widget home, {double w = 390, double h = 844}) async {
      t.view.physicalSize = Size(w * 2, h * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(StoreScope(store: s, child: MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: home))));
      await t.pump(const Duration(milliseconds: 600));
    }

    testWidgets('HP: Tugas dikelompokkan, detail mengubah prioritas dan menambah sub-tugas', (t) async {
      await loadAppFonts();
      final s = await newStore();
      final today = dayOnly(DateTime.now());
      s.addTodo('Susun laporan', cat: 'Kerja', tone: 'orange', due: today.add(const Duration(days: 1)));
      await show(t, s, const TodoPage());
      expect(find.text('Besok'), findsWidgets);
      await t.tap(find.text('Susun laporan'));
      await t.pumpAndSettle();
      expect(find.text('Detail tugas'), findsOneWidget);
      await t.tap(find.text('Tinggi'));
      await t.pump();
      expect(s.todos.single.pri, 'tinggi');
      await t.enterText(find.widgetWithText(TextField, 'Tambah sub-tugas'), 'Kumpulkan data');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      expect(s.todos.single.subs.single.t, 'Kumpulkan data');
      expect(find.text('0 dari 1'), findsOneWidget);
    });

    testWidgets('Windows: klik tugas membuka panel detail; Papan menampilkan tiga kolom', (t) async {
      await loadAppFonts();
      final s = await newStore();
      final today = dayOnly(DateTime.now());
      s.addTodo('Susun laporan', cat: 'Kerja', tone: 'orange', due: today.add(const Duration(days: 1)), pri: 'tinggi');
      final d = s.addTodo('Olahraga', cat: 'Sehat', tone: 'pink', due: today);
      s.toggleTodo(d.id);
      await show(t, s, const TodoPage(), w: 1440, h: 900);
      expect(find.text('Aktivitas 7 hari'), findsOneWidget);
      await t.tap(find.text('Susun laporan'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Detail tugas'), findsOneWidget);
      expect(find.text('Aktivitas 7 hari'), findsNothing);
      await t.tap(find.text('Papan'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Terlambat & hari ini'), findsOneWidget);
      expect(find.text('Mendatang'), findsOneWidget);
      expect(find.text('Selesai'), findsWidgets);
    });

    testWidgets('menutup detail tugas saat catatan masih diketik: tersimpan, tanpa galat', (t) async {
      await loadAppFonts();
      final s = await newStore();
      s.addTodo('Susun laporan', cat: 'Kerja', tone: 'orange', due: dayOnly(DateTime.now()).add(const Duration(days: 1)));
      await show(t, s, const TodoPage());
      await t.tap(find.text('Susun laporan'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Tambahkan catatan…'), 'kirim sebelum jam 5');
      await t.pump();
      await t.tap(find.byTooltip('Tutup'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(s.todos.single.notes, 'kirim sebelum jam 5');
    });

    testWidgets('HP: Kalender tampilan Agenda dan saring warna', (t) async {
      await loadAppFonts();
      final s = await newStore();
      final today = dayOnly(DateTime.now());
      s.addAgenda('Rapat tim', today.add(const Duration(hours: 10)), tone: 'blue', loc: 'Ruang meeting');
      s.addAgenda('Futsal', today.add(const Duration(hours: 19)), tone: 'green');
      await show(t, s, const CalendarPage());
      expect(find.text('Ruang meeting'), findsOneWidget);
      expect(find.text('Futsal'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('Warna Biru'));
      await t.pump();
      expect(find.text('Futsal'), findsNothing);
      expect(find.text('Rapat tim'), findsOneWidget);
      await t.tap(find.text('Agenda'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Rapat tim'), findsOneWidget);
    });
  });
}
