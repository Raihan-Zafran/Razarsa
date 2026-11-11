/// Data mode Produktif: tugas, agenda (acara & pengingat), dan catatan.
library;

class Todo {
  Todo({required this.id, required this.title, required this.cat, required this.tone, this.due, this.done = false, this.doneAt});

  final String id;
  String title;
  String cat;
  String tone;
  DateTime? due;
  bool done;
  DateTime? doneAt;

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cat': cat,
        'tone': tone,
        'due': due?.toIso8601String(),
        'done': done,
        'doneAt': doneAt?.toIso8601String(),
      };

  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        cat: j['cat'] as String? ?? 'Pribadi',
        tone: j['tone'] as String? ?? 'green',
        due: j['due'] == null ? null : DateTime.tryParse(j['due'] as String),
        done: j['done'] == true,
        doneAt: j['doneAt'] == null ? null : DateTime.tryParse(j['doneAt'] as String),
      );
}

/// Satu agenda di kalender. [reminder] = true berarti pengingat (bisa dinyalakan/dimatikan).
class Agenda {
  Agenda({
    required this.id,
    required this.title,
    required this.at,
    this.reminder = false,
    this.on = true,
    this.daily = false,
    this.tone = 'blue',
  });

  final String id;
  String title;
  DateTime at;
  bool reminder;
  bool on;
  bool daily;
  String tone;

  /// Apakah agenda ini muncul pada tanggal [day].
  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(at.year, at.month, at.day);
    if (daily) return !d.isBefore(start);
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
        'daily': daily,
        'tone': tone,
      };

  factory Agenda.fromJson(Map<String, dynamic> j) => Agenda(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        reminder: j['reminder'] == true,
        on: j['on'] != false,
        daily: j['daily'] == true,
        tone: j['tone'] as String? ?? 'blue',
      );
}

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
