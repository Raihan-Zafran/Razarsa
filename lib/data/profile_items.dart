import '../core/i18n.dart';
import '../widgets/common.dart' show Assets;
import 'store.dart';

/// Avatar bawaan (maskot naga). Semua boleh dipakai.
class AvatarItem {
  const AvatarItem(this.id, this._label);

  final String id;
  final String _label;
  String get label => tr(_label);
  String get asset => 'assets/profile/avatars/$id.webp';
}

const kAvatars = <AvatarItem>[
  AvatarItem('a1', 'Naga ceria'),
  AvatarItem('a2', 'Naga daun'),
  AvatarItem('a3', 'Naga kacamata'),
  AvatarItem('a4', 'Naga penyihir'),
  AvatarItem('a5', 'Naga koin'),
  AvatarItem('a6', 'Naga mengantuk'),
  AvatarItem('a7', 'Naga kaget'),
  AvatarItem('a8', 'Naga kedip'),
];

const kDefaultAvatar = 'a1';

/// Bingkai avatar. Terbuka bertahap menurut level; 'none' = tanpa bingkai (selalu boleh).
class FrameItem {
  const FrameItem(this.id, this._label, this.unlockLevel, this.hole);

  final String id;
  final String _label;
  final int unlockLevel;

  /// Diameter lubang bingkai dibanding lebar gambar (dipakai untuk menempatkan avatar di dalamnya).
  final double hole;
  String get label => tr(_label);
  String get asset => 'assets/profile/frames/$id.webp';
}

const kNoFrame = 'none';

const kFrames = <FrameItem>[
  FrameItem('f1', 'Sulur', 1, 0.74),
  FrameItem('f2', 'Emas', 2, 0.795),
  FrameItem('f3', 'Api', 3, 0.717),
  FrameItem('f4', 'Ungu', 5, 0.693),
];

FrameItem? frameById(String id) {
  for (final f in kFrames) {
    if (f.id == id) return f;
  }
  return null;
}

/// Cover kepala profil: tiap cover punya versi siang dan malam (mengikuti tema).
class CoverItem {
  const CoverItem(this.id, this._label, this.dayAsset, this.nightAsset);

  final String id;
  final String _label;
  final String dayAsset;
  final String nightAsset;
  String get label => tr(_label);
}

const kCovers = <CoverItem>[
  CoverItem('desert', 'Gurun', 'assets/profile/covers/desert_day.webp', 'assets/profile/covers/desert_night.webp'),
  CoverItem('mountain', 'Gunung', Assets.sceneDay, Assets.sceneNight),
];

const kDefaultCover = 'desert';

bool isValidAvatar(String id) => kAvatars.any((a) => a.id == id);

bool isValidFrame(String id) => id == kNoFrame || frameById(id) != null;

bool isValidCover(String id) => kCovers.any((c) => c.id == id);

/// Satu lencana pencapaian beserta aturan terbukanya.
class BadgeDef {
  const BadgeDef(this.id, this._label, this._tag, this.check);

  final String id;
  final String _label;
  final String _tag;
  final bool Function(AppStore) check;
  String get label => tr(_label);
  String get tag => tr(_tag);
  String get asset => 'assets/profile/badges/$id.webp';
}

/// Pengeluaran periode lalu ada dan tidak melebihi anggaran.
bool savedLastPeriod(AppStore s) {
  final (prevFrom, _) = s.periodRange(1);
  return s.monthlyBudget > 0 &&
      s.txns.any((t) => t.isExpense && !t.at.isBefore(prevFrom)) &&
      s.monthExpense(1) > 0 &&
      s.monthExpense(1) <= s.monthlyBudget;
}

final kBadges = <BadgeDef>[
  BadgeDef('b01', 'Langkah pertama', 'Semua mode', (s) => s.totalActivity > 0),
  BadgeDef('b02', '7 hari beruntun', 'Semua mode', (s) => s.streak >= 7),
  BadgeDef('b03', 'Hemat sebulan', 'Keuangan', savedLastPeriod),
  BadgeDef('b04', '10 tugas tuntas', 'Produktif', (s) => s.todos.where((t) => t.done).length >= 10),
  BadgeDef('b05', 'Pencatat rajin', 'Keuangan', (s) => s.txns.length >= 50),
  BadgeDef('b06', 'Target tercapai', 'Keuangan', (s) => s.goals.any((g) => g.target > 0 && g.saved >= g.target)),
  BadgeDef('b07', 'Penulis catatan', 'Produktif', (s) => s.notes.length >= 10),
  BadgeDef('b08', 'Perencana', 'Produktif', (s) => s.agenda.length >= 10),
  BadgeDef('b09', '30 hari aktif', 'Semua mode', (s) => s.activeDays.length >= 30),
  BadgeDef('b10', 'Level 3', 'Semua mode', (s) => s.level >= 3),
  BadgeDef('b11', 'Level 5', 'Semua mode', (s) => s.level >= 5),
  BadgeDef('b12', '100 aktivitas', 'Semua mode', (s) => s.totalActivity >= 100),
];

/// Syarat terbuka dalam kalimat, untuk petunjuk pada lencana yang masih terkunci.
const kBadgeHints = <String, String>{
  'b01': 'Catat satu aktivitas apa saja',
  'b02': 'Pakai aplikasi 7 hari berturut-turut',
  'b03': 'Pengeluaran periode lalu tidak melebihi anggaran',
  'b04': 'Selesaikan 10 tugas',
  'b05': 'Catat 50 transaksi',
  'b06': 'Capai jumlah target di salah satu target tabungan',
  'b07': 'Tulis 10 catatan',
  'b08': 'Buat 10 agenda atau pengingat',
  'b09': 'Pakai aplikasi di 30 hari berbeda',
  'b10': 'Capai Level 3',
  'b11': 'Capai Level 5',
  'b12': 'Kumpulkan 100 aktivitas',
};
