import 'package:flutter/material.dart' show IconData, Icons;

import '../core/i18n.dart';
import 'store.dart';

/// Satu lencana pencapaian beserta aturan terbukanya.
class BadgeDef {
  const BadgeDef(this.id, this._label, this._tag, this.icon, this.check);

  final String id;
  final String _label;
  final String _tag;
  final IconData icon;
  final bool Function(AppStore) check;
  String get label => tr(_label);
  String get tag => tr(_tag);
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
  BadgeDef('b01', 'Langkah pertama', 'Semua mode', Icons.flag_rounded, (s) => s.totalActivity > 0),
  BadgeDef('b02', '7 hari beruntun', 'Semua mode', Icons.local_fire_department_rounded, (s) => s.streak >= 7),
  BadgeDef('b03', 'Hemat sebulan', 'Keuangan', Icons.savings_rounded, savedLastPeriod),
  BadgeDef('b04', '10 tugas tuntas', 'Produktif', Icons.task_alt_rounded, (s) => s.todos.where((t) => t.done).length >= 10),
  BadgeDef('b05', 'Pencatat rajin', 'Keuangan', Icons.edit_note_rounded, (s) => s.txns.length >= 50),
  BadgeDef('b06', 'Target tercapai', 'Keuangan', Icons.emoji_events_rounded, (s) => s.goals.any((g) => g.target > 0 && g.saved >= g.target)),
  BadgeDef('b07', 'Penulis catatan', 'Produktif', Icons.sticky_note_2_rounded, (s) => s.notes.length >= 10),
  BadgeDef('b08', 'Perencana', 'Produktif', Icons.event_available_rounded, (s) => s.agenda.length >= 10),
  BadgeDef('b09', '30 hari aktif', 'Semua mode', Icons.calendar_month_rounded, (s) => s.activeDays.length >= 30),
  BadgeDef('b10', 'Level 3', 'Semua mode', Icons.military_tech_rounded, (s) => s.level >= 3),
  BadgeDef('b11', 'Level 5', 'Semua mode', Icons.workspace_premium_rounded, (s) => s.level >= 5),
  BadgeDef('b12', '100 aktivitas', 'Semua mode', Icons.bolt_rounded, (s) => s.totalActivity >= 100),
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
