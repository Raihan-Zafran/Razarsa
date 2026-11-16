/// Data mode Produktif: tugas, agenda (acara & pengingat), dan catatan.
library;

/// Satu sub-tugas (langkah kecil) di dalam tugas.
class SubTask {
  SubTask(this.t, {this.done = false});

  String t;
  bool done;

  Map<String, dynamic> toJson() => {'t': t, 'done': done};

  static SubTask? fromJson(Object? j) {
    if (j is! Map) return null;
    final t = j['t'];
    if (t is! String || t.trim().isEmpty) return null;
    return SubTask(t, done: j['done'] == true);
  }
}

/// Prioritas tugas (kunci, label). Urutan = paling tinggi dulu.
const kPriorities = <(String, String)>[('tinggi', 'Tinggi'), ('sedang', 'Sedang'), ('rendah', 'Rendah')];

int priRank(String p) => p == 'tinggi' ? 3 : (p == 'rendah' ? 1 : 2);

/// Pilihan pengingat: menit sebelum waktunya (0 = tanpa pengingat).
const kRemindOpts = <(int, String)>[(0, 'Tidak'), (10, '10 menit'), (60, '1 jam'), (1440, '1 hari')];

/// Pilihan pengulangan.
const kRepeatOpts = <(String, String)>[('none', 'Tidak'), ('daily', 'Harian'), ('weekly', 'Mingguan'), ('monthly', 'Bulanan')];

String _repeatOf(Object? v) => const ['daily', 'weekly', 'monthly'].contains(v) ? v as String : 'none';

/// Tanggal berikutnya untuk pengulangan [repeat] dari [d] (bulanan: tanggal yang sama, dipotong ke akhir bulan).
DateTime nextRepeat(DateTime d, String repeat) {
  switch (repeat) {
    case 'daily':
      return DateTime(d.year, d.month, d.day + 1, d.hour, d.minute);
    case 'weekly':
      return DateTime(d.year, d.month, d.day + 7, d.hour, d.minute);
    case 'monthly':
      final last = DateTime(d.year, d.month + 2, 0).day;
      return DateTime(d.year, d.month + 1, d.day > last ? last : d.day, d.hour, d.minute);
  }
  return d;
}

class Todo {
  Todo({
    required this.id,
    required this.title,
    required this.cat,
    required this.tone,
    this.due,
    this.done = false,
    this.doneAt,
    this.pri = 'sedang',
    this.notes = '',
    List<SubTask>? subs,
    this.remind = 0,
    this.repeat = 'none',
  }) : subs = subs ?? [];

  final String id;
  String title;
  String cat;
  String tone;
  DateTime? due;
  bool done;
  DateTime? doneAt;

  /// 'tinggi' | 'sedang' | 'rendah'.
  String pri;
  String notes;
  List<SubTask> subs;

  /// Menit sebelum tenggat untuk pengingat; 0 = tanpa pengingat.
  int remind;

  /// 'none' | 'daily' | 'weekly' | 'monthly'. Saat ditandai selesai, tugas berikutnya dibuat otomatis.
  String repeat;

  bool get hasTime => due != null && (due!.hour != 0 || due!.minute != 0);

  /// Waktu pengingat: tenggat (jam 09.00 kalau tanpa jam) dikurangi [remind]. Null kalau tidak ada.
  DateTime? get remindAt {
    final d = due;
    if (d == null || remind <= 0) return null;
    final base = hasTime ? d : DateTime(d.year, d.month, d.day, 9);
    return base.subtract(Duration(minutes: remind));
  }

  /// Nomor notifikasi tetap untuk tugas ini (rentang terpisah dari agenda).
  int get notifId => 500000000 + (int.tryParse(id.length > 8 ? id.substring(id.length - 8) : id) ?? id.hashCode).abs() % 400000000;

  /// Tugas tanpa jam (tersimpan 00:00, mis. dari Tambah Cepat) baru terlambat setelah harinya
  /// lewat; tugas dengan jam terlambat begitu jamnya lewat.
  bool isOverdue([DateTime? now]) {
    final d = due;
    if (done || d == null) return false;
    final n = now ?? DateTime.now();
    if (d.hour == 0 && d.minute == 0) {
      return DateTime(d.year, d.month, d.day).isBefore(DateTime(n.year, n.month, n.day));
    }
    return d.isBefore(n);
  }

  /// Kelompok tenggat: 'late', 'today', 'tomorrow', 'week' (sampai akhir minggu ini), 'later', 'none'.
  String bucket({DateTime? now, bool mondayFirst = true}) {
    final d = due;
    if (d == null) return 'none';
    final n = now ?? DateTime.now();
    if (isOverdue(n)) return 'late';
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff <= 0) return 'today';
    if (diff == 1) return 'tomorrow';
    final weekEnd = today.add(Duration(days: mondayFirst ? 7 - today.weekday : 6 - today.weekday % 7));
    if (!day.isAfter(weekEnd)) return 'week';
    return 'later';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cat': cat,
        'tone': tone,
        'due': due?.toIso8601String(),
        'done': done,
        'doneAt': doneAt?.toIso8601String(),
        'pri': pri,
        'notes': notes,
        'subs': [for (final x in subs) x.toJson()],
        'remind': remind,
        'repeat': repeat,
      };

  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        cat: j['cat'] as String? ?? 'Pribadi',
        tone: j['tone'] as String? ?? 'green',
        due: j['due'] == null ? null : DateTime.tryParse(j['due'] as String),
        done: j['done'] == true,
        doneAt: j['doneAt'] == null ? null : DateTime.tryParse(j['doneAt'] as String),
        pri: const ['tinggi', 'sedang', 'rendah'].contains(j['pri']) ? j['pri'] as String : 'sedang',
        notes: j['notes'] is String ? j['notes'] as String : '',
        subs: j['subs'] is List ? [for (final x in j['subs'] as List) ?SubTask.fromJson(x)] : null,
        remind: j['remind'] is int && (j['remind'] as int) > 0 ? j['remind'] as int : 0,
        repeat: _repeatOf(j['repeat']),
      );
}

/// Satu agenda di kalender. [reminder] = true berarti diingatkan lewat notifikasi
/// ([remindMin] menit sebelum mulai), bisa dinyalakan/dimatikan lewat [on].
class Agenda {
  Agenda({
    required this.id,
    required this.title,
    required this.at,
    this.reminder = false,
    this.on = true,
    bool daily = false,
    String? repeat,
    this.tone = 'blue',
    this.loc = '',
    this.durMin = 60,
    this.remindMin = 0,
  }) : repeat = repeat ?? (daily ? 'daily' : 'none');

  final String id;
  String title;
  DateTime at;
  bool reminder;
  bool on;

  /// 'none' | 'daily' | 'weekly' | 'monthly'.
  String repeat;
  String tone;

  /// Lokasi (boleh kosong).
  String loc;

  /// Lama acara dalam menit.
  int durMin;

  /// Menit sebelum mulai untuk notifikasi (0 = tepat saat mulai).
  int remindMin;

  bool get daily => repeat == 'daily';

  DateTime get end => at.add(Duration(minutes: durMin));

  /// Apakah agenda ini muncul pada tanggal [day].
  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(at.year, at.month, at.day);
    if (d.isBefore(start)) return false;
    switch (repeat) {
      case 'daily':
        return true;
      case 'weekly':
        return d.weekday == start.weekday;
      case 'monthly':
        // Tanggal 29-31 jatuh di hari terakhir bulan yang lebih pendek.
        final last = DateTime(d.year, d.month + 1, 0).day;
        return d.day == (start.day > last ? last : start.day);
    }
    return d == start;
  }

  /// Menit sejak tengah malam (untuk mengurutkan dalam satu hari).
  int get minuteOfDay => at.hour * 60 + at.minute;

  /// Nomor notifikasi tetap untuk agenda ini.
  int get notifId => 1000 + (int.tryParse(id.length > 9 ? id.substring(id.length - 9) : id) ?? id.hashCode).abs() % 2000000000;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'at': at.toIso8601String(),
        'reminder': reminder,
        'on': on,
        'daily': daily, // dibaca versi lama
        'repeat': repeat,
        'tone': tone,
        'loc': loc,
        'dur': durMin,
        'remindMin': remindMin,
      };

  factory Agenda.fromJson(Map<String, dynamic> j) => Agenda(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        reminder: j['reminder'] == true,
        on: j['on'] != false,
        repeat: j['repeat'] != null ? _repeatOf(j['repeat']) : (j['daily'] == true ? 'daily' : 'none'),
        tone: j['tone'] as String? ?? 'blue',
        loc: j['loc'] is String ? j['loc'] as String : '',
        durMin: j['dur'] is int && (j['dur'] as int) > 0 ? j['dur'] as int : 60,
        remindMin: j['remindMin'] is int && (j['remindMin'] as int) >= 0 ? j['remindMin'] as int : 0,
      );
}

/// Warna agenda yang bisa dipilih (kunci warna, label).
const kAgendaTones = <(String, String)>[
  ('blue', 'Biru'),
  ('green', 'Hijau'),
  ('orange', 'Oranye'),
  ('pink', 'Merah muda'),
  ('purple', 'Ungu'),
  ('amber', 'Kuning'),
];

class Note {
  Note({required this.id, required this.title, required this.body, required this.tone, this.pinned = false, this.folder = '', this.locked = false, required this.updatedAt});

  final String id;
  String title;
  String body;
  String tone;
  bool pinned;

  /// Nama folder; kosong = tanpa folder.
  String folder;

  /// Terkunci PIN: isi dienkripsi (AES-256-GCM) di penyimpanan dan disembunyikan di layar.
  bool locked;
  DateTime updatedAt;

  /// Isi terenkripsi yang tidak bisa dibuka (kunci perangkat hilang). Disimpan apa adanya
  /// supaya tidak terhapus; [body] kosong selama ini ada.
  String? sealed;

  bool get unreadable => sealed != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'tone': tone,
        'pinned': pinned,
        'folder': folder,
        'locked': locked,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        tone: j['tone'] as String? ?? 'amber',
        pinned: j['pinned'] == true,
        folder: j['folder'] as String? ?? '',
        locked: j['locked'] == true,
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Kategori tugas bawaan beserta warnanya.
const kTodoCats = <(String, String)>[
  ('Kerja', 'orange'),
  ('Pribadi', 'teal'),
  ('Belanja', 'green'),
  ('Kuliah', 'purple'),
  ('Tagihan', 'blue'),
  ('Sehat', 'pink'),
];

/// Warna catatan yang bisa dipilih.
const kNoteTones = ['amber', 'green', 'blue', 'pink', 'purple', 'orange'];
