import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/crypto.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import 'backup.dart';
import 'models.dart';
import 'productive_models.dart';
import 'profile_items.dart';

/// Hasil memeriksa PIN.
enum PinResult { ok, wrong, locked }

/// Hasil memulihkan backup.
enum BackupResult { ok, invalid, needPassword, wrongPassword, tooNew, saveFailed }

enum _Export { withoutLocked, all, deviceSealed }

/// Isi sebuah file backup yang sudah dibuka (didekripsi bila perlu) dan diperiksa, sebelum
/// data di HP diganti. Dipakai untuk menampilkan pratinjau dan memulihkan tanpa dekripsi ulang.
class BackupInspection {
  BackupInspection(this.result, {this.data, this.encrypted = false});

  final BackupResult result;
  final Map<String, dynamic>? data;
  final bool encrypted;

  int count(String key) => data?[key] is List ? (data![key] as List).length : 0;

  DateTime? get exportedAt => DateTime.tryParse('${data?['exportedAt'] ?? ''}');
}

/// Semua data aplikasi. Disimpan di HP (shared_preferences), belum ada server.
class AppStore extends ChangeNotifier {
  // ignore: prefer_initializing_formals
  AppStore(this._prefs, {required KeyVault vault}) : _vault = vault {
    _load();
  }

  final SharedPreferences _prefs;
  final KeyVault _vault;

  /// Catatan hanya boleh dikunci kalau kunci enkripsi perangkat tersedia.
  bool get canLockNotes => _vault.available;

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
  List<String> noteFolders = [];

  // ---------- Mode & profil ----------
  /// Mode aktif: 'finance' atau 'productive'.
  String mode = 'finance';

  /// Latar mode Keuangan: 'desert' (bawaan) atau 'sky'.
  String financeBg = 'desert';

  List<QuickEntry> quickItems = [];
  List<Recurring> recurring = [];

  /// Dipanggil setiap transaksi berulang berubah (untuk pengingat tagihan).
  /// [cancelIds] = nomor notifikasi tagihan yang sudah tidak berlaku dan harus dibatalkan.
  void Function({List<int> cancelIds})? onRecurringChanged;
  String bio = '';
  String joinedAt = '';

  /// Tampilan profil: avatar bawaan, bingkai ('none' = tanpa), cover.
  String avatar = kDefaultAvatar;
  String frame = kNoFrame;
  String cover = kDefaultCover;

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

  /// Panjang PIN yang dipakai (4 untuk PIN lama, 6 untuk PIN baru).
  int pinLength = 4;

  /// Salah PIN berturut-turut, dan kapan kunci sementara berakhir (ms sejak epoch).
  int pinFails = 0;
  int pinLockUntilMs = 0;
  String lastBackup = '';
  String budgetAlertSent = '';

  /// Batas pengeluaran per kategori (id kategori -> nominal per periode anggaran).
  Map<String, int> catBudgets = {};

  /// Periode terakhir peringatan per kategori sudah dikirim (id kategori -> awal periode).
  Map<String, String> catAlertSent = {};

  /// Dipanggil setelah transaksi pengeluaran dicatat (untuk peringatan anggaran).
  void Function()? onExpenseAdded;
  Map<String, bool> switches = {
    'daily': true,
    'budgetAlert': true,
    'bill': false,
    'pin': false,
    'bio': false,
    'secure': true,
    'hide': false,
    'agenda': true,
  };

  bool get hideBalance => switches['hide'] == true;

  // ---------- Membaca & menyimpan ----------
  /// Versi format data di HP. Naikkan kalau bentuk data berubah, lalu tulis
  /// langkah migrasinya di [_migrate].
  ///  v1: format awal. v2: catatan terkunci dienkripsi, PIN punya panjang & penghitung salah.
  static const dataVersion = 2;

  /// Data ditulis aplikasi yang lebih baru: jangan diubah sama sekali.
  bool _readOnly = false;

  /// Daftar data yang gagal dibaca saat aplikasi dibuka (isi aslinya diselamatkan
  /// ke kunci `rusak_<nama>` di penyimpanan, tidak dibuang).
  final List<String> loadProblems = [];

  /// Kesalahan terakhir saat menulis ke penyimpanan (null = lancar).
  Object? lastSaveError;

  T _get<T>(String key, T fallback) {
    final v = _prefs.get(key);
    return v is T ? v : fallback;
  }

  String? _rawString(String key) {
    final v = _prefs.get(key);
    return v is String ? v : null;
  }

  List<String> _getStrings(String key) {
    final v = _prefs.get(key);
    return v is List ? v.whereType<String>().toList() : <String>[];
  }

  void _load() {
    final fromVersion = _get<int>('dataVersion', 0);
    _readOnly = fromVersion > dataVersion;
    loggedIn = _get('loggedIn', false);
    userName = _get('userName', '');
    email = _get('email', '');
    monthlyBudget = _get('monthlyBudget', 5000000);
    final ti = _get<int>('themeMode', ThemeMode.system.index);
    themeMode = ti >= 0 && ti < ThemeMode.values.length ? ThemeMode.values[ti] : ThemeMode.system;
    lang = _get('lang', 'id') == 'en' ? 'en' : 'id';
    currency = 'IDR'; // Mode dolar dihapus: nilai lama 'USD' dibaca sebagai Rupiah (angka tidak berubah).
    monthStartDay = _get<int>('monthStartDay', 1).clamp(1, 28);
    weekStartMonday = _get('weekStartMonday', true);
    pinHash = _get('pinHash', '');
    pinLength = _get<int>('pinLength', 4).clamp(4, 6);
    pinFails = _get('pinFails', 0);
    pinLockUntilMs = _get('pinLockUntil', 0);
    lastBackup = _get('lastBackup', '');
    budgetAlertSent = _get('budgetAlertSent', '');
    catBudgets = _parseCatBudgets(_rawString('catBudgets'));
    catAlertSent = _parseCatAlerts(_rawString('catAlertSent'));
    L.lang = lang;
    L.currency = currency;
    txns = _readList('txns', Txn.fromJson);
    goals = _readList('goals', Goal.fromJson);
    customCats = _readList('customCats', CustomCategory.fromJson);
    todos = _readList('todos', Todo.fromJson);
    agenda = _readList('agenda', Agenda.fromJson);
    notes = _readList('notes', _noteFromStorage);
    noteFolders = _getStrings('noteFolders');
    mode = _get('mode', 'finance') == 'productive' ? 'productive' : 'finance';
    financeBg = _get('financeBg', 'desert') == 'sky' ? 'sky' : 'desert';
    recurring = _readList('recurring', Recurring.fromJson);
    quickItems = _rawString('quickItems') == null ? _defaultQuickItems() : _readList('quickItems', QuickEntry.fromJson);
    bio = _get('bio', '');
    joinedAt = _get('joinedAt', '');
    final av = _get('avatar', kDefaultAvatar);
    final fr = _get('frame', kNoFrame);
    final cv = _get('cover', kDefaultCover);
    avatar = isValidAvatar(av) ? av : kDefaultAvatar;
    frame = isValidFrame(fr) ? fr : kNoFrame;
    cover = isValidCover(cv) ? cv : kDefaultCover;
    activeDays = _getStrings('activeDays');
    final sw = _rawString('switches');
    if (sw != null) {
      try {
        final m = jsonDecode(sw) as Map<String, dynamic>;
        m.forEach((k, v) => switches[k] = v == true);
      } catch (e) {
        debugPrint('Razarsa: gagal membaca pengaturan: $e');
      }
    }
    // PIN dan saklarnya harus selalu sejalan.
    switches['pin'] = pinHash.isNotEmpty;
    if (pinHash.isEmpty) switches['bio'] = false;
    _migrate(fromVersion);
    postRecurring();
    _markActive();
    _sortTxns();
    _autoSnapshot();
    if (fromVersion < dataVersion || _needsSeal) _save();
  }

  /// Ada catatan terkunci yang masih tersimpan polos (data versi lama) dan perlu dienkripsi.
  bool _needsSeal = false;

  static List<QuickEntry> _defaultQuickItems() =>
      kQuickItems.map((q) => QuickEntry(name: q.name, cat: q.cat, amount: q.amount)).toList();

  void _migrate(int from) {
    if (_readOnly || from >= dataVersion) return;
    // v0/v1 -> v2: catatan terkunci yang masih polos akan dienkripsi oleh penyimpanan pertama
    // ([_needsSeal]). Cadangan otomatis lama juga memuatnya dalam bentuk polos, jadi isinya
    // dienkripsi di tempat. Cadangannya sendiri tidak dibuang: bisa jadi satu-satunya salinan yang bagus.
    if (from < 2) {
      if (notes.any((n) => n.locked)) _needsSeal = true;
      // Salinan kondisi SEBELUM migrasi (catatan terkunci sudah terenkripsi di dalamnya). Dilewati
      // kalau ada data yang gagal terbaca, supaya cadangan lama yang bagus tidak tertimpa.
      if (loadProblems.isEmpty && _hasAnyData) unawaited(_writeSafetyCopy());
      _sealOldAutoBackup();
    }
  }

  void _sealOldAutoBackup() {
    final raw = _rawString('autoBackup');
    final k = _vault.key;
    if (raw == null || raw.isEmpty || k == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      var changed = false;
      for (final e in (m['notes'] as List? ?? const [])) {
        final j = e as Map<String, dynamic>;
        final body = j['body'];
        if (j['locked'] == true && j['enc'] == null && body is String && body.isNotEmpty) {
          j['enc'] = aesGcmSeal(k, utf8.encode(body), aad: j['id'] as String);
          j['body'] = '';
          changed = true;
        }
      }
      if (changed) _prefs.setString('autoBackup', jsonEncode(m));
    } catch (e) {
      debugPrint('Razarsa: cadangan otomatis lama tidak bisa diproses: $e');
    }
  }

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) f) {
    final raw = _rawString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => f(e as Map<String, dynamic>)).toList();
    } catch (e) {
      // Jangan diam-diam membuang data: simpan salinan mentahnya sebelum
      // penyimpanan berikutnya menimpanya dengan daftar kosong.
      debugPrint('Razarsa: gagal membaca "$key": $e');
      loadProblems.add(key);
      if (!_prefs.containsKey('rusak_$key')) _prefs.setString('rusak_$key', raw);
      return [];
    }
  }

  // ---------- Catatan terkunci: enkripsi ----------
  final Map<String, (String, String)> _sealCache = {};

  Note _noteFromStorage(Map<String, dynamic> j) {
    final n = Note.fromJson(j);
    final enc = j['enc'];
    if (n.locked && enc is String && enc.isNotEmpty) {
      final k = _vault.key;
      final plain = k == null ? null : aesGcmOpen(k, enc, aad: n.id);
      if (plain != null) {
        n.body = utf8.decode(plain);
        _sealCache[n.id] = (n.body, enc);
      } else {
        // Kunci tidak cocok / hilang: simpan apa adanya, jangan dihapus.
        n.body = '';
        n.sealed = enc;
      }
    } else if (n.locked && n.body.isNotEmpty) {
      _needsSeal = true; // data lama: masih polos
    }
    return n;
  }

  Map<String, dynamic> _noteToStorage(Note n) {
    final j = n.toJson();
    if (!n.locked) return j;
    if (n.sealed != null) {
      j['body'] = '';
      j['enc'] = n.sealed;
      return j;
    }
    final k = _vault.key;
    if (k == null || n.body.isEmpty) return j; // tidak bisa/perlu dienkripsi: jangan sampai data hilang
    final cached = _sealCache[n.id];
    final enc = cached != null && cached.$1 == n.body ? cached.$2 : aesGcmSeal(k, utf8.encode(n.body), aad: n.id);
    _sealCache[n.id] = (n.body, enc);
    j['body'] = '';
    j['enc'] = enc;
    return j;
  }

  // ---------- Cadangan otomatis ----------
  /// Salinan data terakhir (maksimal sehari sekali), disimpan di HP.
  /// Isi catatan terkunci di dalamnya terenkripsi dengan kunci perangkat.
  String get autoBackupAt => _get('autoBackupAt', '');
  bool get hasAutoBackup => _get('autoBackup', '').isNotEmpty;

  bool get _hasAnyData =>
      txns.isNotEmpty ||
      goals.isNotEmpty ||
      todos.isNotEmpty ||
      agenda.isNotEmpty ||
      notes.isNotEmpty ||
      recurring.isNotEmpty ||
      customCats.isNotEmpty;

  /// Isi cadangan ditentukan saat dipanggil (sebelum data berubah); penulisannya bisa ditunggu.
  Future<void> _writeSafetyCopy() async {
    final json = jsonEncode(_exportMap(_Export.deviceSealed));
    final at = DateTime.now().toIso8601String();
    // Kedua kunci dikirim bersamaan (tanpa menunggu satu per satu) supaya cadangan dan waktunya selalu sepasang.
    await Future.wait([_prefs.setString('autoBackup', json), _prefs.setString('autoBackupAt', at)]);
  }

  void _autoSnapshot() {
    if (_readOnly) return;
    // Jangan menimpa cadangan yang bagus dengan data yang gagal terbaca.
    if (loadProblems.isNotEmpty) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (autoBackupAt.startsWith(today)) return;
    if (!_hasAnyData) return;
    unawaited(_writeSafetyCopy());
  }

  /// Memulihkan dari cadangan otomatis. Mengembalikan false kalau tidak ada / rusak.
  /// Baru dianggap berhasil setelah data pulih benar-benar tersimpan di penyimpanan.
  Future<bool> restoreAutoBackup() async {
    final raw = _get('autoBackup', '');
    if (raw.isEmpty) return false;
    lastSaveError = null;
    if (!importJson(raw, keepSafetyCopy: false)) return false;
    await flush();
    return lastSaveError == null;
  }

  // ---------- Menulis ke penyimpanan ----------
  // Penulisan diantre satu per satu dan hanya kunci yang isinya berubah yang ditulis.
  Future<void> _saveQueue = Future<void>.value();
  final Map<String, String> _written = {};

  Future<void> _save() {
    if (_readOnly) return Future<void>.value();
    return _saveQueue = _saveQueue.then((_) => _writeAll()).catchError((Object e) {
      lastSaveError = e;
      debugPrint('Razarsa: gagal menyimpan: $e');
    });
  }

  /// Menunggu semua penulisan yang sedang berjalan selesai.
  Future<void> flush() => _saveQueue;

  Future<void> _put(String key, Object value) async {
    final sig = value is List<String> ? 'L${jsonEncode(value)}' : '${value.runtimeType}:$value';
    if (_written[key] == sig) return;
    final bool ok;
    if (value is bool) {
      ok = await _prefs.setBool(key, value);
    } else if (value is int) {
      ok = await _prefs.setInt(key, value);
    } else if (value is String) {
      ok = await _prefs.setString(key, value);
    } else if (value is List<String>) {
      ok = await _prefs.setStringList(key, value);
    } else {
      throw ArgumentError('Tipe tidak didukung untuk $key');
    }
    if (!ok) throw StateError('Gagal menulis $key');
    _written[key] = sig;
  }

  Future<void> _writeAll() async {
    String list<E>(List<E> l, Object? Function(E) f) => jsonEncode(l.map(f).toList());
    await _put('loggedIn', loggedIn);
    await _put('userName', userName);
    await _put('email', email);
    await _put('monthlyBudget', monthlyBudget);
    await _put('themeMode', themeMode.index);
    await _put('lang', lang);
    await _put('currency', currency);
    await _put('monthStartDay', monthStartDay);
    await _put('weekStartMonday', weekStartMonday);
    await _put('pinHash', pinHash);
    await _put('pinLength', pinLength);
    await _put('pinFails', pinFails);
    await _put('pinLockUntil', pinLockUntilMs);
    await _put('lastBackup', lastBackup);
    await _put('budgetAlertSent', budgetAlertSent);
    await _put('catBudgets', jsonEncode(catBudgets));
    await _put('catAlertSent', jsonEncode(catAlertSent));
    await _put('txns', list(txns, (e) => e.toJson()));
    await _put('goals', list(goals, (e) => e.toJson()));
    await _put('customCats', list(customCats, (e) => e.toJson()));
    await _put('switches', jsonEncode(switches));
    await _put('todos', list(todos, (e) => e.toJson()));
    await _put('agenda', list(agenda, (e) => e.toJson()));
    await _put('notes', list(notes, _noteToStorage));
    await _put('noteFolders', noteFolders);
    await _put('mode', mode);
    await _put('financeBg', financeBg);
    await _put('recurring', list(recurring, (e) => e.toJson()));
    await _put('quickItems', list(quickItems, (e) => e.toJson()));
    await _put('bio', bio);
    await _put('joinedAt', joinedAt);
    await _put('avatar', avatar);
    await _put('frame', frame);
    await _put('cover', cover);
    await _put('activeDays', activeDays);
    // Versi ditandai terakhir: kalau penulisan terputus di tengah, migrasi diulang dengan aman.
    await _put('dataVersion', dataVersion);
    lastSaveError = null;
  }

  void _changed() {
    notifyListeners();
    unawaited(_save());
  }

  void _sortTxns() => txns.sort((a, b) => b.at.compareTo(a.at));

  int _lastId = 0;

  /// Id unik yang selalu naik, walau dipanggil berkali-kali dalam satu mikrodetik.
  String newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _lastId = now > _lastId ? now : _lastId + 1;
    return _lastId.toString();
  }

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

  /// Mengubah nama dan email profil. false kalau nama kosong atau email tidak valid.
  bool updateProfile({required String name, String email = ''}) {
    final n = name.trim();
    final m = email.trim();
    if (n.isEmpty || n.length > 30) return false;
    if (m.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(m)) return false;
    userName = n;
    this.email = m; // parameter 'email' menutupi field dengan nama yang sama
    _changed();
    return true;
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
  // saat PIN yang benar dimasukkan. Hash dengan iterasi lebih rendah juga di-upgrade.
  static const _pinIterations = 60000;

  /// PIN baru wajib 6 digit; PIN lama 4 digit tetap berlaku sampai diganti.
  static const pinMinLength = 4;
  static const pinMaxLength = 6;
  static const pinNewLength = 6;

  /// Setelah sekian kali salah berturut-turut, PIN dikunci sementara dengan jeda yang makin lama.
  static const pinFreeTries = 5;
  static const _lockSeconds = [30, 60, 300, 900, 3600];

  static String _hex(List<int> b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _unhex(String h) =>
      [for (var i = 0; i + 1 < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];

  static bool _sameHex(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _hashPin(String pin) {
    final salt = randomBytes(16);
    final hash = _hex(pbkdf2(pin, salt, _pinIterations));
    return 'v2\$$_pinIterations\$${_hex(salt)}\$$hash';
  }

  /// Sisa waktu PIN dikunci karena terlalu banyak salah. Nol kalau tidak dikunci.
  Duration get pinLockRemaining {
    var ms = pinLockUntilMs - DateTime.now().millisecondsSinceEpoch;
    // Jam HP yang dimundurkan tidak boleh membuat kunci lebih lama dari batas tertinggi.
    final cap = _lockSeconds.last * 1000;
    if (ms > cap) ms = cap;
    return ms > 0 ? Duration(milliseconds: ms) : Duration.zero;
  }

  bool _verifyPin(String pin) {
    if (pinHash.startsWith('v2\$')) {
      final parts = pinHash.split('\$');
      if (parts.length != 4) return false;
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations < 1 || iterations > 5000000) return false;
      final ok = _sameHex(_hex(pbkdf2(pin, _unhex(parts[2]), iterations)), parts[3]);
      if (ok && iterations < _pinIterations) {
        pinHash = _hashPin(pin);
        unawaited(_save());
      }
      return ok;
    }
    // Format lama (SHA-256 polos). Kalau cocok, upgrade ke format baru.
    final legacy = sha256.convert(utf8.encode('razarsa:$pin')).toString();
    if (!_sameHex(legacy, pinHash)) return false;
    pinHash = _hashPin(pin);
    unawaited(_save());
    return true;
  }

  /// Memeriksa PIN dengan pembatasan percobaan.
  PinResult tryPin(String pin) {
    if (!pinEnabled) return PinResult.wrong;
    if (pinLockRemaining > Duration.zero) return PinResult.locked;
    if (_verifyPin(pin)) {
      if (pinFails != 0 || pinLockUntilMs != 0) {
        pinFails = 0;
        pinLockUntilMs = 0;
        unawaited(_save());
      }
      return PinResult.ok;
    }
    pinFails++;
    if (pinFails >= pinFreeTries) {
      final step = _lockSeconds[min(pinFails - pinFreeTries, _lockSeconds.length - 1)];
      pinLockUntilMs = DateTime.now().millisecondsSinceEpoch + step * 1000;
    }
    unawaited(_save());
    return PinResult.wrong;
  }

  bool checkPin(String pin) => tryPin(pin) == PinResult.ok;

  /// Memasang PIN baru (4-6 digit angka), atau mematikan PIN kalau [pin] null.
  /// Mematikan PIN juga membuka kunci semua catatan terkunci yang bisa dibaca,
  /// supaya tidak ada catatan yang terjebak tanpa PIN.
  /// Sesi ini sudah terbuka: PIN yang baru saja dibuat tidak langsung diminta lagi. Tidak disimpan;
  /// aplikasi yang dibuka dari nol selalu mulai terkunci.
  bool sessionUnlocked = false;

  void setPin(String? pin) {
    if (pin != null && !RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw ArgumentError('PIN harus 4-6 digit angka');
    }
    pinHash = pin == null ? '' : _hashPin(pin);
    if (pin != null) sessionUnlocked = true;
    pinLength = pin?.length ?? 4;
    pinFails = 0;
    pinLockUntilMs = 0;
    switches['pin'] = pin != null;
    if (pin == null) {
      switches['bio'] = false;
      for (final n in notes) {
        if (n.locked && !n.unreadable) n.locked = false;
      }
    }
    _changed();
  }

  void setSwitch(String key, bool value) {
    switches[key] = value;
    _changed();
  }

  void setBudget(int value) {
    monthlyBudget = value.clamp(0, maxAmount).toInt();
    _changed();
  }

  /// Membaca batas per kategori dari JSON/peta yang tidak dipercaya. Entri tidak valid dibuang.
  static Map<String, int> _parseCatBudgets(Object? raw) {
    try {
      final m = raw is String ? jsonDecode(raw) : raw;
      if (m is! Map) return {};
      final out = <String, int>{};
      m.forEach((k, v) {
        if (k is String && v is num && v > 0 && v <= maxAmount && out.length < 64) out[k] = v.toInt();
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  static Map<String, String> _parseCatAlerts(Object? raw) {
    try {
      final m = raw is String ? jsonDecode(raw) : raw;
      if (m is! Map) return {};
      return {for (final e in m.entries) if (e.key is String && e.value is String) e.key as String: e.value as String};
    } catch (_) {
      return {};
    }
  }

  bool _isExpenseCategory(String id) =>
      kExpenseCategories.any((c) => c.id == id) || customCats.any((c) => c.id == id && !c.income);

  /// Memasang batas pengeluaran untuk satu kategori pengeluaran. [amount] <= 0 menghapus batas.
  /// false kalau kategori tidak ada atau bukan kategori pengeluaran.
  bool setCategoryBudget(String id, int amount) {
    if (!_isExpenseCategory(id)) return false;
    if (amount <= 0) {
      catBudgets.remove(id);
    } else {
      if (!catBudgets.containsKey(id) && catBudgets.length >= 64) return false;
      catBudgets[id] = amount.clamp(1, maxAmount).toInt();
    }
    catAlertSent.remove(id);
    _changed();
    return true;
  }

  /// Pengeluaran kategori [id] pada periode anggaran ini.
  int categorySpent(String id) {
    final (from, to) = periodRange();
    return spentByCategory(from, to)[id] ?? 0;
  }

  /// Menandai peringatan kategori [id] untuk [period] sudah dikirim (tersimpan).
  void markCategoryAlert(String id, String period) {
    catAlertSent[id] = period;
    unawaited(_save());
  }

  /// Menandai peringatan anggaran periode ini sudah dikirim (tersimpan, tidak berulang).
  void markBudgetAlert(String period) {
    budgetAlertSent = period;
    unawaited(_save());
  }

  // ---------- Backup ----------
  /// Versi format file backup yang dibuat dan dipahami aplikasi ini.
  static const backupVersion = 2;

  /// Batas ukuran file backup yang diterima (karakter), dan jumlah item per daftar.
  static const maxBackupChars = 20 * 1000 * 1000;
  static const _maxItems = 200000;

  /// Batas wajar satu nominal uang (1 triliun) supaya hitungan tidak meluap.
  static const maxAmount = 1000000000000;

  bool get hasLockedNotes => notes.any((n) => n.locked);

  Map<String, dynamic> _exportMap(_Export mode) => {
        'app': 'razarsa',
        'version': backupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'monthlyBudget': monthlyBudget,
        'catBudgets': catBudgets,
        // Pengaturan yang memengaruhi isi laporan, dan profil. Pengaturan keamanan (PIN, sidik jari,
        // layar aman) sengaja TIDAK ikut: itu milik perangkat, bukan data pengguna.
        'settings': {
          'monthStartDay': monthStartDay,
          'weekStartMonday': weekStartMonday,
          'currency': currency,
          'lang': lang,
          'financeBg': financeBg,
          'themeMode': themeMode.index,
          'mode': this.mode, // 'mode' sendiri adalah parameter jenis ekspor
        },
        'profile': {
          'bio': bio,
          'joinedAt': joinedAt,
          'activeDays': activeDays,
          'avatar': avatar,
          'frame': frame,
          'cover': cover,
          // Nama dan email hanya di backup berkata sandi / salinan di HP, tidak di backup polos.
          if (mode != _Export.withoutLocked) ...{'name': userName, 'email': email},
        },
        'txns': txns.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'customCats': customCats.map((e) => e.toJson()).toList(),
        'todos': todos.map((e) => e.toJson()).toList(),
        'agenda': agenda.map((e) => e.toJson()).toList(),
        'notes': notes.map((n) {
          switch (mode) {
            case _Export.deviceSealed:
              return _noteToStorage(n);
            case _Export.all:
              final j = n.toJson();
              if (n.sealed != null) j['enc'] = n.sealed;
              return j;
            case _Export.withoutLocked:
              final j = n.toJson();
              if (n.locked) {
                j['body'] = '';
                j['bodyOmitted'] = true;
              }
              return j;
          }
        }).toList(),
        'noteFolders': noteFolders,
        'recurring': recurring.map((e) => e.toJson()).toList(),
        'quickItems': quickItems.map((e) => e.toJson()).toList(),
      };

  /// Backup polos. Isi catatan terkunci TIDAK ikut (hanya penanda); untuk menyertakannya
  /// pakai [exportEncrypted]. Jangan simpan backup polos kalau ada catatan terkunci.
  String exportJson() => const JsonEncoder.withIndent('  ').convert(_exportMap(_Export.withoutLocked));

  /// Backup terenkripsi dengan kata sandi. Berisi semua data termasuk catatan terkunci.
  Future<String> exportEncrypted(String password) =>
      BackupEnvelope.encrypt(jsonEncode(_exportMap(_Export.all)), password);

  /// Membuka dan memeriksa file backup (polos atau terenkripsi) TANPA mengubah data di HP.
  /// Untuk pratinjau; lanjutkan dengan [restoreFrom].
  Future<BackupInspection> inspectBackup(String raw, {String? password}) async {
    if (raw.length > maxBackupChars) return BackupInspection(BackupResult.invalid);
    Map<String, dynamic> m;
    try {
      m = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return BackupInspection(BackupResult.invalid);
    }
    if (m['app'] != 'razarsa' && m['app'] != 'zevra') return BackupInspection(BackupResult.invalid);
    final encrypted = BackupEnvelope.isEncrypted(m);
    if (encrypted) {
      if (password == null || password.isEmpty) return BackupInspection(BackupResult.needPassword, encrypted: true);
      final inner = await BackupEnvelope.decrypt(m, password);
      if (inner == null) return BackupInspection(BackupResult.wrongPassword, encrypted: true);
      try {
        m = jsonDecode(inner) as Map<String, dynamic>;
      } catch (_) {
        return BackupInspection(BackupResult.invalid, encrypted: true);
      }
      if (m['app'] != 'razarsa') return BackupInspection(BackupResult.invalid, encrypted: true);
    }
    if (((m['version'] as num?)?.toInt() ?? 1) > backupVersion) {
      return BackupInspection(BackupResult.tooNew, encrypted: encrypted);
    }
    return BackupInspection(BackupResult.ok, data: m, encrypted: encrypted);
  }

  /// Memasang hasil [inspectBackup] (data lama diganti setelah salinan cadangan dibuat).
  /// "Berhasil" hanya setelah data baru benar-benar tertulis.
  Future<BackupResult> restoreFrom(BackupInspection inspection, {bool keepSafetyCopy = true}) async {
    final data = inspection.data;
    if (inspection.result != BackupResult.ok || data == null) return inspection.result;
    lastSaveError = null;
    if (!_applyBackup(data, keepSafetyCopy: keepSafetyCopy)) return BackupResult.invalid;
    await flush();
    return lastSaveError == null ? BackupResult.ok : BackupResult.saveFailed;
  }

  /// Memulihkan dari teks backup (polos atau terenkripsi) sekaligus.
  Future<BackupResult> importBackup(String raw, {String? password, bool keepSafetyCopy = true}) async =>
      restoreFrom(await inspectBackup(raw, password: password), keepSafetyCopy: keepSafetyCopy);

  /// Versi sederhana untuk backup polos. false kalau tidak valid atau terenkripsi.
  bool importJson(String raw, {bool keepSafetyCopy = true}) {
    try {
      if (raw.length > maxBackupChars) return false;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['app'] != 'razarsa' && m['app'] != 'zevra') return false;
      if (BackupEnvelope.isEncrypted(m)) return false;
      if (((m['version'] as num?)?.toInt() ?? 1) > backupVersion) return false;
      return _applyBackup(m, keepSafetyCopy: keepSafetyCopy);
    } catch (e) {
      debugPrint('Razarsa: impor backup gagal: $e');
      return false;
    }
  }

  static List<T> _dedupe<T>(List<T> l, String Function(T) id) {
    final seen = <String>{};
    return [
      for (final e in l)
        if (seen.add(id(e))) e
    ];
  }

  /// Mengganti data dengan isi backup. Semua isi dibaca & diperiksa dulu; data baru dipasang
  /// hanya kalau seluruhnya valid, jadi file rusak tidak membuat data setengah terganti.
  bool _applyBackup(Map<String, dynamic> m, {required bool keepSafetyCopy}) {
    if (_readOnly) return false;
    try {
      List<T> items<T>(String k, T Function(Map<String, dynamic>) f, {bool required = false}) {
        final raw = m[k];
        if (raw == null && !required) return <T>[];
        final l = raw as List;
        if (l.length > _maxItems) throw FormatException('Terlalu banyak data di "$k"');
        return l.map((e) => f(e as Map<String, dynamic>)).toList();
      }

      void check(bool ok, String what) {
        if (!ok) throw FormatException('Nilai tidak valid: $what');
      }

      final newTxns = _dedupe(items('txns', Txn.fromJson, required: true), (t) => t.id);
      final newGoals = _dedupe(items('goals', Goal.fromJson, required: true), (g) => g.id);
      final newCats = _dedupe(items('customCats', CustomCategory.fromJson, required: true), (c) => c.id);
      final newTodos = _dedupe(items('todos', Todo.fromJson), (t) => t.id);
      final newAgenda = _dedupe(items('agenda', Agenda.fromJson), (a) => a.id);
      final newNotes = _dedupe(items('notes', _noteFromStorage), (n) => n.id);
      final newRecurring = _dedupe(items('recurring', Recurring.fromJson), (r) => r.id);
      for (final t in newTxns) {
        check(t.amount.abs() <= maxAmount, 'jumlah transaksi');
      }
      for (final g in newGoals) {
        check(g.target >= 0 && g.target <= maxAmount && g.saved >= 0 && g.saved <= maxAmount, 'target tabungan');
      }
      for (final r in newRecurring) {
        check(r.amount.abs() <= maxAmount, 'transaksi berulang');
      }
      final newFolders = _getFolders(m['noteFolders']);
      for (final n in newNotes) {
        if (n.folder.isNotEmpty && !newFolders.contains(n.folder)) newFolders.add(n.folder);
      }
      final newQuick = m['quickItems'] != null ? items('quickItems', QuickEntry.fromJson) : null;
      final newBudget = (m['monthlyBudget'] as num?)?.toInt() ?? monthlyBudget;
      check(newBudget >= 0 && newBudget <= maxAmount, 'anggaran');
      final expenseIds = {...kExpenseCategories.map((c) => c.id), ...newCats.where((c) => !c.income).map((c) => c.id)};
      final newCatBudgets = m.containsKey('catBudgets')
          ? (Map.of(_parseCatBudgets(m['catBudgets']))..removeWhere((k, _) => !expenseIds.contains(k)))
          : <String, int>{};
      final st = m['settings'] is Map ? m['settings'] as Map : const {};
      final pf = m['profile'] is Map ? m['profile'] as Map : const {};
      final dayRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      final newMonthStart = st['monthStartDay'] is num ? (st['monthStartDay'] as num).toInt().clamp(1, 28) : monthStartDay;
      final newWeekMon = st['weekStartMonday'] is bool ? st['weekStartMonday'] as bool : weekStartMonday;
      const newCurrency = 'IDR';
      final newLang = st['lang'] == 'en' || st['lang'] == 'id' ? st['lang'] as String : lang;
      final ti = st['themeMode'];
      final newTheme = ti is int && ti >= 0 && ti < ThemeMode.values.length ? ThemeMode.values[ti] : themeMode;
      final newAppMode = st['mode'] == 'finance' || st['mode'] == 'productive' ? st['mode'] as String : mode;
      final pn = pf['name'], pe = pf['email'];
      final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      final newName = pn is String && pn.trim().isNotEmpty && pn.trim().length <= 30 ? pn.trim() : userName;
      final newEmail = pe is String && (pe.isEmpty || (pe.length <= 120 && emailOk.hasMatch(pe))) && pn is String ? pe : email;
      final newBg = st['financeBg'] == 'sky' || st['financeBg'] == 'desert' ? st['financeBg'] as String : financeBg;
      final newBio = pf['bio'] is String && (pf['bio'] as String).length <= 1000 ? pf['bio'] as String : bio;
      final newJoined = pf['joinedAt'] is String && dayRe.hasMatch(pf['joinedAt'] as String) ? pf['joinedAt'] as String : joinedAt;
      final newAvatar = pf['avatar'] is String && isValidAvatar(pf['avatar'] as String) ? pf['avatar'] as String : avatar;
      final newFrame = pf['frame'] is String && isValidFrame(pf['frame'] as String) ? pf['frame'] as String : frame;
      final newCover = pf['cover'] is String && isValidCover(pf['cover'] as String) ? pf['cover'] as String : cover;
      final newDays = pf['activeDays'] is List
          ? (pf['activeDays'] as List).whereType<String>().where(dayRe.hasMatch).toSet().take(400).toList()
          : activeDays;

      if (keepSafetyCopy && _hasAnyData) unawaited(_writeSafetyCopy());
      final oldAgenda = agenda;
      final oldBills = recurring.map((r) => r.notifId).toList();
      txns = newTxns;
      goals = newGoals;
      customCats = newCats;
      todos = newTodos;
      agenda = newAgenda;
      notes = newNotes;
      noteFolders = newFolders;
      recurring = newRecurring;
      if (newQuick != null) quickItems = newQuick;
      monthlyBudget = newBudget;
      catBudgets = newCatBudgets;
      catAlertSent = {};
      monthStartDay = newMonthStart;
      weekStartMonday = newWeekMon;
      currency = newCurrency;
      lang = newLang;
      L.currency = newCurrency;
      L.lang = newLang;
      financeBg = newBg;
      themeMode = newTheme;
      mode = newAppMode;
      userName = newName;
      email = newEmail;
      bio = newBio;
      avatar = newAvatar;
      frame = newFrame;
      cover = newCover;
      joinedAt = newJoined;
      activeDays = newDays;
      _markActive();
      // Pengingat lama yang tidak ada di backup harus dibatalkan, bukan dibiarkan menggantung.
      for (final a in oldAgenda) {
        onAgendaChanged?.call(a, removed: true);
      }
      for (final a in agenda) {
        onAgendaChanged?.call(a);
      }
      onRecurringChanged?.call(cancelIds: oldBills);
      _sortTxns();
      _changed();
      return true;
    } catch (e) {
      debugPrint('Razarsa: impor backup gagal: $e');
      return false;
    }
  }

  static List<String> _getFolders(Object? raw) =>
      raw is List ? raw.whereType<String>().toSet().toList() : <String>[];

  /// Sel CSV: teks yang diawali = + - @ (juga setelah spasi di depan) atau tab/CR/LF bisa dibaca
  /// Excel/Sheets sebagai rumus, jadi diberi tanda petik.
  static String _csvText(String s) {
    final t = s.trimLeft();
    final danger = s.isNotEmpty && ('\t\r\n'.contains(s[0]) || (t.isNotEmpty && '=+-@'.contains(t[0])));
    final safe = danger ? "'$s" : s;
    return '"${safe.replaceAll('"', '""')}"';
  }

  String exportCsv() {
    final b = StringBuffer('tanggal,jenis,kategori,catatan,jumlah\n');
    for (final t in txns) {
      b.writeln([
        t.at.toIso8601String().substring(0, 16).replaceAll('T', ' '),
        t.isExpense ? 'pengeluaran' : 'pemasukan',
        _csvText(category(t.cat).label),
        _csvText(t.name),
        t.amount,
      ].join(','));
    }
    return b.toString();
  }

  void markBackup() {
    lastBackup = DateTime.now().toIso8601String();
    _changed();
  }

  /// Menghapus semua data pengguna dan baru selesai setelah penyimpanan benar-benar bersih.
  /// [keepSafetyCopy] true: satu salinan cadangan otomatis disimpan supaya hapus yang tidak sengaja
  /// bisa dipulihkan. false: cadangan otomatis ikut dihapus (hapus permanen).
  Future<void> clearAll({bool keepSafetyCopy = true}) async {
    if (keepSafetyCopy) {
      if (_hasAnyData) await _writeSafetyCopy();
    } else {
      await _prefs.remove('autoBackup');
      await _prefs.remove('autoBackupAt');
    }
    final oldBills = recurring.map((r) => r.notifId).toList();
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
    noteFolders = [];
    recurring = [];
    quickItems = _defaultQuickItems();
    // Profil dan kemajuan (XP, hari aktif) juga data pengguna. Akun (nama, email) dan pengaturan tampilan tetap.
    bio = '';
    avatar = kDefaultAvatar;
    frame = kNoFrame;
    cover = kDefaultCover;
    joinedAt = '';
    activeDays = [];
    lastBackup = '';
    budgetAlertSent = '';
    catBudgets = {};
    catAlertSent = {};
    _markActive();
    _sealCache.clear();
    // Salinan data rusak (rusak_*) juga bagian dari data pengguna.
    for (final k in _prefs.getKeys().where((k) => k.startsWith('rusak_')).toList()) {
      await _prefs.remove(k);
    }
    loadProblems.clear();
    _changed();
    await flush();
    onRecurringChanged?.call(cancelIds: oldBills);
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

  static const maxCategoryLabel = 16;

  static String _normLabel(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// Menambah kategori buatan sendiri. Nama yang sama (tanpa membedakan huruf besar/kecil dan spasi
  /// berlebih) dengan kategori bawaan atau buatan sendiri yang sejenis TIDAK dibuat ulang: kategori yang
  /// sudah ada dikembalikan. Nama kosong jatuh ke "Lainnya". Nama dipotong [maxCategoryLabel] karakter.
  Category addCustomCategory(String label, {required bool income}) {
    var clean = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length > maxCategoryLabel) clean = clean.substring(0, maxCategoryLabel).trimRight();
    if (clean.isEmpty) return income ? kIncomeCategories.last : kExpenseCategories.last;
    final key = _normLabel(clean);
    for (final c in income ? kIncomeCategories : kExpenseCategories) {
      if (_normLabel(c.idLabel) == key || _normLabel(c.label) == key) return c;
    }
    for (final c in customCats) {
      if (c.income == income && _normLabel(c.label) == key) return c.toCategory();
    }
    final c = CustomCategory('c${newId()}', clean, income);
    customCats.add(c);
    _changed();
    return c.toCategory();
  }

  /// Berapa data (transaksi, berulang, Catat Cepat) yang memakai kategori [id].
  int categoryUsage(String id) =>
      txns.where((t) => t.cat == id).length + recurring.where((r) => r.cat == id).length + quickItems.where((q) => q.cat == id).length;

  /// Mengganti nama kategori buatan sendiri. false kalau id tidak ada, nama kosong, atau
  /// kembar dengan kategori lain yang sejenis. Transaksi lama ikut memakai nama baru (terikat id).
  bool renameCustomCategory(String id, String label) {
    final i = customCats.indexWhere((c) => c.id == id);
    if (i < 0) return false;
    var clean = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length > maxCategoryLabel) clean = clean.substring(0, maxCategoryLabel).trimRight();
    if (clean.isEmpty) return false;
    final income = customCats[i].income;
    final key = _normLabel(clean);
    for (final c in income ? kIncomeCategories : kExpenseCategories) {
      if (_normLabel(c.idLabel) == key || _normLabel(c.label) == key) return false;
    }
    for (final c in customCats) {
      if (c.id != id && c.income == income && _normLabel(c.label) == key) return false;
    }
    customCats[i] = CustomCategory(id, clean, income);
    _changed();
    return true;
  }

  /// Menghapus kategori buatan sendiri. Data yang memakainya dipindahkan ke "Lainnya" (tidak ada
  /// transaksi yang hilang). Mengembalikan jumlah data yang dipindahkan, atau -1 kalau id tidak ada.
  int removeCustomCategory(String id) {
    final i = customCats.indexWhere((c) => c.id == id);
    if (i < 0) return -1;
    final fallback = customCats[i].income ? kIncomeCategories.last.id : kExpenseCategories.last.id;
    final moved = categoryUsage(id);
    for (var k = 0; k < txns.length; k++) {
      final t = txns[k];
      if (t.cat == id) txns[k] = Txn(id: t.id, name: t.name, cat: fallback, amount: t.amount, at: t.at);
    }
    for (final r in recurring) {
      if (r.cat == id) r.cat = fallback;
    }
    for (final q in quickItems) {
      if (q.cat == id) q.cat = fallback;
    }
    customCats.removeAt(i);
    catBudgets.remove(id);
    catAlertSent.remove(id);
    _changed();
    return moved;
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
    final t = Txn(
      id: newId(),
      name: name.length > 200 ? name.substring(0, 200) : name,
      cat: cat,
      amount: amount.clamp(-maxAmount, maxAmount).toInt(),
      at: at ?? DateTime.now(),
    );
    txns.add(t);
    _sortTxns();
    _changed();
    if (t.amount < 0) onExpenseAdded?.call();
    return t;
  }

  void removeTxn(String id) {
    txns.removeWhere((t) => t.id == id);
    _changed();
  }

  int get balance => txns.fold(0, (s, t) => s + t.amount);

  /// Selisih hari kalender (aman terhadap pergantian jam musim panas).
  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  /// Saldo di akhir tiap hari selama [days] hari terakhir (paling lama dulu, hari ini terakhir).
  List<int> balanceSeries(int days, [DateTime? now]) {
    final today = dayOnly(now ?? DateTime.now());
    // Satu putaran lewat transaksi: jumlah per hari, lalu dijumlahkan dari awal.
    final perDay = List<int>.filled(days, 0);
    var before = 0;
    final first = DateTime(today.year, today.month, today.day - (days - 1));
    for (final t in txns) {
      final d = dayOnly(t.at);
      if (d.isBefore(first)) {
        before += t.amount;
      } else if (!d.isAfter(today)) {
        perDay[_daysBetween(first, d)] += t.amount;
      }
    }
    var run = before;
    return [for (final v in perDay) run += v];
  }

  /// Total pengeluaran tiap hari selama [days] hari terakhir (paling lama dulu, hari ini terakhir).
  List<int> dailyExpense(int days, [DateTime? now]) {
    final today = dayOnly(now ?? DateTime.now());
    final first = DateTime(today.year, today.month, today.day - (days - 1));
    final out = List<int>.filled(days, 0);
    for (final t in txns) {
      if (!t.isExpense) continue;
      final d = dayOnly(t.at);
      if (d.isBefore(first) || d.isAfter(today)) continue;
      out[_daysBetween(first, d)] += t.amount.abs();
    }
    return out;
  }

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
    final i = goals.indexWhere((g) => g.id == id);
    if (i < 0) return;
    final before = goals[i].saved;
    goals[i].saved = (goals[i].saved + amount).clamp(0, maxAmount).toInt();
    goals[i].addLog(DateTime.now(), goals[i].saved - before);
    _changed();
  }

  /// Mengurangi tabungan (mis. dipakai/ditarik). false kalau jumlah tidak valid atau melebihi tabungan.
  bool withdrawFromGoal(String id, int amount) {
    final i = goals.indexWhere((g) => g.id == id);
    if (i < 0 || amount <= 0 || amount > goals[i].saved) return false;
    goals[i].saved -= amount;
    goals[i].addLog(DateTime.now(), -amount);
    _changed();
    return true;
  }

  /// Mengubah nama dan/atau target. false kalau tidak valid (kosong, target <= 0 atau terlalu besar).
  bool editGoal(String id, {String? name, int? target}) {
    final i = goals.indexWhere((g) => g.id == id);
    if (i < 0) return false;
    final newName = name?.trim();
    if (newName != null && (newName.isEmpty || newName.length > 60)) return false;
    if (target != null && (target <= 0 || target > maxAmount)) return false;
    if (newName != null) goals[i].name = newName;
    if (target != null) goals[i].target = target;
    _changed();
    return true;
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
    final d = day.clamp(1, 28);
    final r = Recurring(id: newId(), name: name.trim(), cat: cat, amount: amount, day: d,
        lastPosted: now.day > d ? _monthKey(now) : '');
    recurring.add(r);
    postRecurring(notify: false);
    _changed();
    onRecurringChanged?.call();
    return r;
  }

  void removeRecurring(String id) {
    final gone = recurring.where((r) => r.id == id).map((r) => r.notifId).toList();
    recurring.removeWhere((r) => r.id == id);
    _changed();
    onRecurringChanged?.call(cancelIds: gone);
  }

  /// Catat transaksi berulang yang sudah jatuh tempo. Bulan yang terlewat karena aplikasi
  /// tidak dibuka ikut dicatat (maksimal 12 bulan ke belakang). Mengembalikan jumlah yang dicatat.
  int postRecurring({bool notify = true}) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final earliest = DateTime(now.year, now.month - 11);
    var n = 0;
    var expensePosted = false;
    for (final r in recurring) {
      final last = r.lastPosted.length == 7 ? DateTime.tryParse('${r.lastPosted}-01') : null;
      var m = last == null ? thisMonth : DateTime(last.year, last.month + 1);
      if (m.isBefore(earliest)) m = earliest;
      for (; !m.isAfter(thisMonth); m = DateTime(m.year, m.month + 1)) {
        if (m == thisMonth && now.day < r.day) break; // belum jatuh tempo bulan ini
        txns.add(Txn(id: newId(), name: r.name, cat: r.cat, amount: r.amount, at: DateTime(m.year, m.month, r.day, 8)));
        r.lastPosted = _monthKey(m);
        if (r.amount < 0) expensePosted = true;
        n++;
      }
    }
    if (n > 0) {
      _sortTxns();
      if (notify) {
        _changed(); // layar ikut diperbarui, bukan hanya disimpan
        if (expensePosted) onExpenseAdded?.call();
      }
    }
    return n;
  }

  // ---------- Mode & profil ----------
  void setMode(String m) {
    if (mode == m) return;
    mode = m;
    _changed();
  }

  /// Bingkai yang benar-benar tampil: bingkai yang belum terbuka (mis. level turun setelah data
  /// dihapus) dianggap tanpa bingkai, pilihan tetap tersimpan.
  String get effectiveFrame {
    final f = frameById(frame);
    return f != null && level >= f.unlockLevel ? frame : kNoFrame;
  }

  bool frameUnlocked(String id) {
    if (id == kNoFrame) return true;
    final f = frameById(id);
    return f != null && level >= f.unlockLevel;
  }

  /// false kalau id tidak dikenal.
  bool setAvatar(String id) {
    if (!isValidAvatar(id)) return false;
    avatar = id;
    _changed();
    return true;
  }

  /// false kalau id tidak dikenal atau bingkai belum terbuka di level sekarang.
  bool setFrame(String id) {
    if (!isValidFrame(id) || !frameUnlocked(id)) return false;
    frame = id;
    _changed();
    return true;
  }

  bool setCover(String id) {
    if (!isValidCover(id)) return false;
    cover = id;
    _changed();
    return true;
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
    final i = todos.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final t = todos[i];
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
    final i = agenda.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final a = agenda[i];
    a.on = !a.on;
    _changed();
    onAgendaChanged?.call(a);
  }

  void removeAgenda(String id) {
    final i = agenda.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final a = agenda.removeAt(i);
    _changed();
    onAgendaChanged?.call(a, removed: true);
  }

  List<Agenda> agendaOn(DateTime day) => agenda.where((a) => a.occursOn(day)).toList()
    ..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));

  // ---------- Catatan ----------
  Note addNote({String title = '', String body = '', String tone = 'amber', String folder = ''}) {
    final n = Note(id: newId(), title: title, body: body, tone: tone, folder: folder, updatedAt: DateTime.now());
    notes.insert(0, n);
    _changed();
    return n;
  }

  /// Mengubah catatan. Mengembalikan false kalau permintaan ditolak: mengunci tanpa kunci
  /// enkripsi perangkat, atau mengubah catatan terkunci yang isinya tidak bisa dibuka.
  bool updateNote(Note n, {String? title, String? body, String? tone, bool? pinned, String? folder, bool? locked}) {
    if (locked == true && !n.locked && !_vault.available) return false;
    if (n.unreadable && (locked == false || body != null)) return false;
    if (title != null) n.title = title;
    if (body != null) n.body = body;
    if (tone != null) n.tone = tone;
    if (pinned != null) n.pinned = pinned;
    if (folder != null) n.folder = folder;
    if (locked != null) n.locked = locked;
    // Memindah folder atau mengunci tidak mengubah "terakhir diubah".
    if (title != null || body != null || tone != null || pinned != null) n.updatedAt = DateTime.now();
    _changed();
    return true;
  }

  /// Membuat folder catatan. false kalau kosong, kepanjangan, atau sudah ada.
  bool addNoteFolder(String name) {
    final f = name.trim();
    if (f.isEmpty || f.length > 20 || noteFolders.contains(f)) return false;
    noteFolders.add(f);
    _changed();
    return true;
  }

  /// Menghapus folder; catatan di dalamnya tidak dihapus, hanya jadi tanpa folder.
  void removeNoteFolder(String name) {
    noteFolders.remove(name);
    for (final n in notes) {
      if (n.folder == name) n.folder = '';
    }
    _changed();
  }

  void removeNote(String id) {
    notes.removeWhere((n) => n.id == id);
    _sealCache.remove(id);
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
