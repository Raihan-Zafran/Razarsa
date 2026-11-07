import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import 'models.dart';
import 'productive_models.dart';

/// Semua data aplikasi. Disimpan di HP (shared_preferences), belum ada server.
class AppStore extends ChangeNotifier {
  AppStore(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  // ---------- Akun ----------
  bool loggedIn = false;
  String userName = '';
  String email = '';

  // ---------- Data keuangan ----------
  List<Txn> txns = [];
  List<Goal> goals = [];
  List<CustomCategory> customCats = [];
  int monthlyBudget = 5000000;

  // ---------- Data produktif ----------
  List<Todo> todos = [];
  List<Agenda> agenda = [];
  List<Note> notes = [];

  // ---------- Mode & profil ----------
  /// Mode aktif: 'finance' atau 'productive'.
  String mode = 'finance';

  /// Latar mode Keuangan: 'desert' (bawaan) atau 'sky'.
  String financeBg = 'desert';

  List<QuickEntry> quickItems = [];
  List<Recurring> recurring = [];

  /// Dipanggil setiap transaksi berulang berubah (untuk pengingat tagihan).
  void Function()? onRecurringChanged;
  String bio = '';
  String joinedAt = '';

  /// Tanggal-tanggal (yyyy-mm-dd) saat aplikasi dipakai.
  List<String> activeDays = [];

  /// Dipanggil setiap agenda berubah (untuk menjadwalkan notifikasi).
  void Function(Agenda a, {bool removed})? onAgendaChanged;

  // ---------- Pengaturan ----------
  ThemeMode themeMode = ThemeMode.system;
  String lang = 'id';
  String currency = 'IDR';
  int monthStartDay = 1;
  bool weekStartMonday = true;
  String pinHash = '';
  String lastBackup = '';
  String budgetAlertSent = '';

  /// Dipanggil setelah transaksi pengeluaran dicatat (untuk peringatan anggaran).
  void Function()? onExpenseAdded;
  Map<String, bool> switches = {
    'daily': true,
    'budgetAlert': true,
    'bill': false,
    'pin': false,
    'bio': false,
    'hide': false,
    'agenda': true,
  };

  bool get hideBalance => switches['hide'] == true;

  void _load() {
    loggedIn = _prefs.getBool('loggedIn') ?? false;
    userName = _prefs.getString('userName') ?? '';
    email = _prefs.getString('email') ?? '';
    monthlyBudget = _prefs.getInt('monthlyBudget') ?? 5000000;
    themeMode = ThemeMode.values[_prefs.getInt('themeMode') ?? ThemeMode.system.index];
    lang = _prefs.getString('lang') ?? 'id';
    currency = _prefs.getString('currency') ?? 'IDR';
    monthStartDay = _prefs.getInt('monthStartDay') ?? 1;
    weekStartMonday = _prefs.getBool('weekStartMonday') ?? true;
    pinHash = _prefs.getString('pinHash') ?? '';
    lastBackup = _prefs.getString('lastBackup') ?? '';
    budgetAlertSent = _prefs.getString('budgetAlertSent') ?? '';
    L.lang = lang;
    L.currency = currency;
    txns = _readList('txns', Txn.fromJson);
    goals = _readList('goals', Goal.fromJson);
    customCats = _readList('customCats', CustomCategory.fromJson);
    todos = _readList('todos', Todo.fromJson);
    agenda = _readList('agenda', Agenda.fromJson);
    notes = _readList('notes', Note.fromJson);
    mode = _prefs.getString('mode') ?? 'finance';
    financeBg = _prefs.getString('financeBg') ?? 'desert';
    recurring = _readList('recurring', Recurring.fromJson);
    quickItems = _prefs.getString('quickItems') == null
        ? kQuickItems.map((q) => QuickEntry(name: q.name, cat: q.cat, amount: q.amount)).toList()
        : _readList('quickItems', QuickEntry.fromJson);
    postRecurring();
    bio = _prefs.getString('bio') ?? '';
    joinedAt = _prefs.getString('joinedAt') ?? '';
    activeDays = _prefs.getStringList('activeDays') ?? [];
    _markActive();
    final sw = _prefs.getString('switches');
    if (sw != null) {
      final m = jsonDecode(sw) as Map<String, dynamic>;
      m.forEach((k, v) => switches[k] = v == true);
    }
    _sortTxns();
  }

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) f) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => f(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    await _prefs.setBool('loggedIn', loggedIn);
    await _prefs.setString('userName', userName);
    await _prefs.setString('email', email);
    await _prefs.setInt('monthlyBudget', monthlyBudget);
    await _prefs.setInt('themeMode', themeMode.index);
    await _prefs.setString('lang', lang);
    await _prefs.setString('currency', currency);
    await _prefs.setInt('monthStartDay', monthStartDay);
    await _prefs.setBool('weekStartMonday', weekStartMonday);
    await _prefs.setString('pinHash', pinHash);
    await _prefs.setString('lastBackup', lastBackup);
    await _prefs.setString('budgetAlertSent', budgetAlertSent);
    await _prefs.setString('txns', jsonEncode(txns.map((e) => e.toJson()).toList()));
    await _prefs.setString('goals', jsonEncode(goals.map((e) => e.toJson()).toList()));
    await _prefs.setString('customCats', jsonEncode(customCats.map((e) => e.toJson()).toList()));
    await _prefs.setString('switches', jsonEncode(switches));
    await _prefs.setString('todos', jsonEncode(todos.map((e) => e.toJson()).toList()));
    await _prefs.setString('agenda', jsonEncode(agenda.map((e) => e.toJson()).toList()));
    await _prefs.setString('notes', jsonEncode(notes.map((e) => e.toJson()).toList()));
    await _prefs.setString('mode', mode);
    await _prefs.setString('financeBg', financeBg);
    await _prefs.setString('recurring', jsonEncode(recurring.map((e) => e.toJson()).toList()));
    await _prefs.setString('quickItems', jsonEncode(quickItems.map((e) => e.toJson()).toList()));
    await _prefs.setString('bio', bio);
    await _prefs.setString('joinedAt', joinedAt);
    await _prefs.setStringList('activeDays', activeDays);
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  void _sortTxns() => txns.sort((a, b) => b.at.compareTo(a.at));

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // ---------- Akun ----------
  void login({String? name, String? mail}) {
    loggedIn = true;
    if (mail != null && mail.isNotEmpty) email = mail;
    if (name != null && name.trim().isNotEmpty) {
      userName = name.trim();
    } else if (userName.isEmpty && email.contains('@')) {
      userName = email.split('@').first;
    }
    _changed();
  }

  void logout() {
    loggedIn = false;
    _changed();
  }

  // ---------- Tema & pengaturan ----------
  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _changed();
  }

  void setLang(String v) {
    lang = v;
    L.lang = v;
    _changed();
  }

  void setCurrency(String v) {
    currency = v;
    L.currency = v;
    _changed();
  }

  void setMonthStart(int day) {
    monthStartDay = day.clamp(1, 28);
    _changed();
  }

  void setWeekStartMonday(bool v) {
    weekStartMonday = v;
    _changed();
  }

  // ---------- PIN ----------
  bool get pinEnabled => pinHash.isNotEmpty;

  // PIN disimpan sebagai "v2$iterasi$salt$hash" (PBKDF2-HMAC-SHA256, salt acak per HP).
  // Format lama (SHA-256 polos tanpa salt) masih bisa dibaca, lalu otomatis di-upgrade
  // saat PIN yang benar dimasukkan.
  static const _pinIterations = 30000;

  static String _hex(List<int> b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _unhex(String h) =>
      [for (var i = 0; i + 1 < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];

  static List<int> _pbkdf2(String pin, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return t;
  }

  static bool _sameHex(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _hashPin(String pin) {
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final hash = _hex(_pbkdf2(pin, salt, _pinIterations));
    return 'v2\$$_pinIterations\$${_hex(salt)}\$$hash';
  }

  bool checkPin(String pin) {
    if (!pinEnabled) return false;
    if (pinHash.startsWith('v2\$')) {
      final parts = pinHash.split('\$');
      if (parts.length != 4) return false;
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations < 1) return false;
      return _sameHex(_hex(_pbkdf2(pin, _unhex(parts[2]), iterations)), parts[3]);
    }
    // Format lama (SHA-256 polos). Kalau cocok, upgrade ke format baru.
    final legacy = sha256.convert(utf8.encode('razarsa:$pin')).toString();
    if (!_sameHex(legacy, pinHash)) return false;
    pinHash = _hashPin(pin);
    _changed();
    return true;
  }

  void setPin(String? pin) {
    pinHash = pin == null ? '' : _hashPin(pin);
    switches['pin'] = pin != null;
    if (pin == null) switches['bio'] = false;
    _changed();
  }

  void setSwitch(String key, bool value) {
    switches[key] = value;
    _changed();
  }

  void setBudget(int value) {
    monthlyBudget = value;
    _changed();
  }

  // ---------- Backup ----------
  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'app': 'razarsa',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'monthlyBudget': monthlyBudget,
        'txns': txns.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'customCats': customCats.map((e) => e.toJson()).toList(),
        'todos': todos.map((e) => e.toJson()).toList(),
        'agenda': agenda.map((e) => e.toJson()).toList(),
        'notes': notes.map((e) => e.toJson()).toList(),
        'recurring': recurring.map((e) => e.toJson()).toList(),
        'quickItems': quickItems.map((e) => e.toJson()).toList(),
      });

  /// Mengganti data dengan isi backup. Mengembalikan false kalau file tidak valid.
  bool importJson(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['app'] != 'razarsa' && m['app'] != 'zevra') return false;
      txns = (m['txns'] as List).map((e) => Txn.fromJson(e as Map<String, dynamic>)).toList();
      goals = (m['goals'] as List).map((e) => Goal.fromJson(e as Map<String, dynamic>)).toList();
      customCats = (m['customCats'] as List).map((e) => CustomCategory.fromJson(e as Map<String, dynamic>)).toList();
      monthlyBudget = (m['monthlyBudget'] as num?)?.toInt() ?? monthlyBudget;
      List<T> opt<T>(String k, T Function(Map<String, dynamic>) f) =>
          ((m[k] as List?) ?? const []).map((e) => f(e as Map<String, dynamic>)).toList();
      todos = opt('todos', Todo.fromJson);
      agenda = opt('agenda', Agenda.fromJson);
      notes = opt('notes', Note.fromJson);
      recurring = opt('recurring', Recurring.fromJson);
      if (m['quickItems'] != null) quickItems = opt('quickItems', QuickEntry.fromJson);
      onRecurringChanged?.call();
      for (final a in agenda) {
        onAgendaChanged?.call(a);
      }
      _sortTxns();
      _changed();
      return true;
    } catch (_) {
      return false;
    }
  }

  String exportCsv() {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('tanggal,jenis,kategori,catatan,jumlah\n');
    for (final t in txns) {
      b.writeln([
        t.at.toIso8601String().substring(0, 16).replaceAll('T', ' '),
        t.isExpense ? 'pengeluaran' : 'pemasukan',
        q(category(t.cat).label),
        q(t.name),
        t.amount,
      ].join(','));
    }
    return b.toString();
  }

  void markBackup() {
    lastBackup = DateTime.now().toIso8601String();
    _changed();
  }

  Future<void> clearAll() async {
    txns = [];
    goals = [];
    customCats = [];
    monthlyBudget = 5000000;
    for (final a in agenda) {
      onAgendaChanged?.call(a, removed: true);
    }
    todos = [];
    agenda = [];
    notes = [];
    recurring = [];
    _changed();
    onRecurringChanged?.call();
  }

  // ---------- Kategori ----------
  List<Category> categories({required bool income}) => [
        ...(income ? kIncomeCategories : kExpenseCategories),
        ...customCats.where((c) => c.income == income).map((c) => c.toCategory()),
      ];

  Category category(String id) {
    for (final c in [...kExpenseCategories, ...kIncomeCategories]) {
      if (c.id == id) return c;
    }
    for (final c in customCats) {
      if (c.id == id) return c.toCategory();
    }
    return kExpenseCategories.last;
  }

  int get categoryCount => kExpenseCategories.length + kIncomeCategories.length + customCats.length;

  Category addCustomCategory(String label, {required bool income}) {
    final c = CustomCategory('c${newId()}', label.trim(), income);
    customCats.add(c);
    _changed();
    return c.toCategory();
  }

  /// Kategori diurutkan dari yang paling sering dipakai.
  List<Category> rankedCategories({required bool income}) {
    final usage = <String, int>{};
    for (final t in txns) {
      usage[t.cat] = (usage[t.cat] ?? 0) + 1;
    }
    final list = categories(income: income);
    final order = {for (var i = 0; i < list.length; i++) list[i].id: i};
    list.sort((a, b) {
      final u = (usage[b.id] ?? 0).compareTo(usage[a.id] ?? 0);
      return u != 0 ? u : order[a.id]!.compareTo(order[b.id]!);
    });
    return list;
  }

  // ---------- Transaksi ----------
  Txn addTxn({required String name, required String cat, required int amount, DateTime? at}) {
    final t = Txn(id: newId(), name: name, cat: cat, amount: amount, at: at ?? DateTime.now());
    txns.add(t);
    _sortTxns();
    _changed();
    if (amount < 0) onExpenseAdded?.call();
    return t;
  }

  void removeTxn(String id) {
    txns.removeWhere((t) => t.id == id);
    _changed();
  }

  int get balance => txns.fold(0, (s, t) => s + t.amount);

  /// Awal periode bulan anggaran yang memuat [ref] (mengikuti tanggal gajian).
  DateTime periodStart([DateTime? ref]) {
    final r = ref ?? DateTime.now();
    final d = monthStartDay;
    return r.day >= d ? DateTime(r.year, r.month, d) : DateTime(r.year, r.month - 1, d);
  }

  /// Rentang periode; back = 0 periode ini, 1 periode sebelumnya, dst.
  (DateTime, DateTime) periodRange([int back = 0]) {
    final p = periodStart();
    final start = DateTime(p.year, p.month - back, monthStartDay);
    return (start, DateTime(start.year, start.month + 1, monthStartDay));
  }

  /// Awal minggu ini (Senin atau Minggu).
  DateTime weekStart([DateTime? ref]) {
    final d = dayOnly(ref ?? DateTime.now());
    final back = weekStartMonday ? d.weekday - 1 : d.weekday % 7;
    return d.subtract(Duration(days: back));
  }

  int _sum(int back, bool expense) {
    final (from, to) = periodRange(back);
    return txns
        .where((t) => t.isExpense == expense && !t.at.isBefore(from) && t.at.isBefore(to))
        .fold(0, (s, t) => s + t.amount.abs());
  }

  int monthIncome([int back = 0]) => _sum(back, false);

  int monthExpense([int back = 0]) => _sum(back, true);

  /// Pengeluaran per kategori dalam rentang waktu.
  Map<String, int> spentByCategory(DateTime from, DateTime to) {
    final m = <String, int>{};
    for (final t in txns) {
      if (!t.isExpense || t.at.isBefore(from) || !t.at.isBefore(to)) continue;
      m[t.cat] = (m[t.cat] ?? 0) - t.amount;
    }
    return m;
  }

  /// Total pengeluaran 6 bulan terakhir (paling lama dulu).
  List<MapEntry<DateTime, int>> lastMonths(int count) => List.generate(count, (i) {
        final back = count - 1 - i;
        return MapEntry(periodRange(back).$1, monthExpense(back));
      });

  // ---------- Target ----------
  void addGoal(String name, int target) {
    const tones = ['green', 'blue', 'purple', 'amber', 'pink', 'teal', 'orange'];
    goals.add(Goal(id: newId(), name: name.trim(), target: target, tone: tones[goals.length % tones.length]));
    _changed();
  }

  void addToGoal(String id, int amount) {
    final g = goals.firstWhere((g) => g.id == id);
    g.saved = (g.saved + amount).clamp(0, 1 << 40).toInt();
    _changed();
  }

  void removeGoal(String id) {
    goals.removeWhere((g) => g.id == id);
    _changed();
  }

  // ---------- Latar, Catat Cepat, transaksi berulang ----------
  void setFinanceBg(String v) {
    financeBg = v;
    _changed();
  }

  void saveQuickItem(QuickEntry q, {int? index}) {
    if (index == null) {
      quickItems.add(q);
    } else {
      quickItems[index] = q;
    }
    _changed();
  }

  void removeQuickItem(int index) {
    quickItems.removeAt(index);
    _changed();
  }

  static String _monthKey(DateTime d) => d.toIso8601String().substring(0, 7);

  /// Tambah transaksi berulang. Kalau tanggalnya sudah lewat bulan ini, mulai bulan depan.
  Recurring addRecurring({required String name, required String cat, required int amount, required int day}) {
    final now = DateTime.now();
    final r = Recurring(id: newId(), name: name.trim(), cat: cat, amount: amount, day: day.clamp(1, 28),
        lastPosted: now.day > day ? _monthKey(now) : '');
    recurring.add(r);
    postRecurring(notify: false);
    _changed();
    onRecurringChanged?.call();
    return r;
  }

  void removeRecurring(String id) {
    recurring.removeWhere((r) => r.id == id);
    _changed();
    onRecurringChanged?.call();
  }

  /// Catat transaksi berulang yang jatuh tempo bulan ini. Mengembalikan jumlah yang dicatat.
  int postRecurring({bool notify = true}) {
    final now = DateTime.now();
    final key = _monthKey(now);
    var n = 0;
    for (final r in recurring) {
      if (r.lastPosted == key || now.day < r.day) continue;
      txns.add(Txn(id: newId(), name: r.name, cat: r.cat, amount: r.amount, at: DateTime(now.year, now.month, r.day, 8)));
      r.lastPosted = key;
      n++;
    }
    if (n > 0) {
      _sortTxns();
      if (notify) _save();
    }
    return n;
  }

  // ---------- Mode & profil ----------
  void setMode(String m) {
    if (mode == m) return;
    mode = m;
    _changed();
  }

  void setBio(String v) {
    bio = v.trim();
    _changed();
  }

  static String _dayKey(DateTime d) => d.toIso8601String().substring(0, 10);

  void _markActive() {
    final today = _dayKey(DateTime.now());
    if (joinedAt.isEmpty) joinedAt = today;
    if (!activeDays.contains(today)) {
      activeDays.add(today);
      if (activeDays.length > 400) activeDays.removeAt(0);
      _save();
    }
  }

  /// Jumlah hari berturut-turut (sampai hari ini atau kemarin) aplikasi dipakai.
  int get streak {
    final set = activeDays.toSet();
    var d = dayOnly(DateTime.now());
    if (!set.contains(_dayKey(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (set.contains(_dayKey(d))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Semua catatan dari semua mode.
  int get totalActivity => txns.length + goals.length + todos.length + agenda.length + notes.length;

  int get xp => totalActivity * 10 + activeDays.length * 20 + todos.where((t) => t.done).length * 10;

  static const xpPerLevel = 500;

  int get level => xp ~/ xpPerLevel + 1;

  int get xpInLevel => xp % xpPerLevel;

  // ---------- Tugas ----------
  Todo addTodo(String title, {required String cat, required String tone, DateTime? due}) {
    final t = Todo(id: newId(), title: title.trim(), cat: cat, tone: tone, due: due);
    todos.add(t);
    _changed();
    return t;
  }

  void toggleTodo(String id) {
    final t = todos.firstWhere((t) => t.id == id);
    t.done = !t.done;
    t.doneAt = t.done ? DateTime.now() : null;
    _changed();
  }

  void removeTodo(String id) {
    todos.removeWhere((t) => t.id == id);
    _changed();
  }

  /// Tugas diurutkan: belum selesai dulu, lalu menurut waktu.
  List<Todo> get sortedTodos {
    final l = [...todos];
    l.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      final ad = a.due, bd = b.due;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return l;
  }

  /// Tugas untuk hari ini: bertanggal hari ini, terlambat, atau tanpa tanggal.
  List<Todo> get todayTodos {
    final end = dayOnly(DateTime.now()).add(const Duration(days: 1));
    return sortedTodos.where((t) => t.due == null || t.due!.isBefore(end)).toList();
  }

  // ---------- Agenda ----------
  Agenda addAgenda(String title, DateTime at, {bool reminder = false, bool daily = false}) {
    final a = Agenda(id: newId(), title: title.trim(), at: at, reminder: reminder, daily: daily, tone: reminder ? 'amber' : 'blue');
    agenda.add(a);
    _changed();
    onAgendaChanged?.call(a);
    return a;
  }

  void toggleAgenda(String id) {
    final a = agenda.firstWhere((a) => a.id == id);
    a.on = !a.on;
    _changed();
    onAgendaChanged?.call(a);
  }

  void removeAgenda(String id) {
    final a = agenda.firstWhere((a) => a.id == id);
    agenda.remove(a);
    _changed();
    onAgendaChanged?.call(a, removed: true);
  }

  List<Agenda> agendaOn(DateTime day) => agenda.where((a) => a.occursOn(day)).toList()
    ..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));

  // ---------- Catatan ----------
  Note addNote({String title = '', String body = '', String tone = 'amber'}) {
    final n = Note(id: newId(), title: title, body: body, tone: tone, updatedAt: DateTime.now());
    notes.insert(0, n);
    _changed();
    return n;
  }

  void updateNote(Note n, {String? title, String? body, String? tone, bool? pinned}) {
    if (title != null) n.title = title;
    if (body != null) n.body = body;
    if (tone != null) n.tone = tone;
    if (pinned != null) n.pinned = pinned;
    n.updatedAt = DateTime.now();
    _changed();
  }

  void removeNote(String id) {
    notes.removeWhere((n) => n.id == id);
    _changed();
  }

  /// Catatan disematkan dulu, lalu yang terbaru.
  List<Note> get sortedNotes => [...notes]..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

  /// Label hari untuk pengelompokan daftar transaksi.
  static String groupLabel(Txn t) => dayLabel(t.at);
}

/// Memberi akses AppStore ke seluruh widget.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
