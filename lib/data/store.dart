import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
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

  void setSwitch(String key, bool value) {
    switches[key] = value;
    _changed();
  }

  void setBudget(int value) {
    monthlyBudget = value;
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
    return t;
  }

  void removeTxn(String id) {
    txns.removeWhere((t) => t.id == id);
    _changed();
  }

  int get balance => txns.fold(0, (s, t) => s + t.amount);

  bool _sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  int monthIncome([DateTime? m]) {
    final now = m ?? DateTime.now();
    return txns.where((t) => !t.isExpense && _sameMonth(t.at, now)).fold(0, (s, t) => s + t.amount);
  }

  int monthExpense([DateTime? m]) {
    final now = m ?? DateTime.now();
    return txns.where((t) => t.isExpense && _sameMonth(t.at, now)).fold(0, (s, t) => s - t.amount);
  }

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
  List<MapEntry<DateTime, int>> lastMonths(int count) {
    final now = DateTime.now();
    return List.generate(count, (i) {
      final d = DateTime(now.year, now.month - (count - 1 - i));
      return MapEntry(d, monthExpense(d));
    });
  }

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
