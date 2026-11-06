import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import 'models.dart';

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

  String _hash(String pin) => sha256.convert(utf8.encode('razarsa:$pin')).toString();

  bool checkPin(String pin) => pinEnabled && _hash(pin) == pinHash;

  void setPin(String? pin) {
    pinHash = pin == null ? '' : _hash(pin);
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
    _changed();
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
