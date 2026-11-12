import 'package:flutter/material.dart';

import '../core/i18n.dart';

/// Kategori transaksi. [tone] adalah nama nada warna di ZColors.
class Category {
  const Category(this.id, this._label, this.tone, this.icon, {this.income = false});

  final String id;
  final String _label;

  /// Label sesuai bahasa aktif (kategori buatan sendiri tidak diterjemahkan).
  String get label => tr(_label);

  /// Nama sumber (bahasa Indonesia), tidak ikut berubah saat bahasa diganti.
  String get idLabel => _label;
  final String tone;
  final IconData icon;
  final bool income;
}

const kExpenseCategories = <Category>[
  Category('food', 'Makan & Minum', 'orange', Icons.restaurant_rounded),
  Category('transport', 'Transportasi', 'blue', Icons.two_wheeler_rounded),
  Category('shopping', 'Belanja', 'amber', Icons.shopping_bag_outlined),
  Category('bills', 'Tagihan', 'teal', Icons.receipt_long_rounded),
  Category('housing', 'Kos/Rumah', 'green', Icons.home_outlined),
  Category('loan', 'Cicilan', 'pink', Icons.credit_card_rounded),
  Category('fun', 'Hiburan', 'purple', Icons.movie_outlined),
  Category('health', 'Kesehatan', 'pink', Icons.favorite_border_rounded),
  Category('edu', 'Pendidikan', 'blue', Icons.menu_book_rounded),
  Category('family', 'Keluarga', 'amber', Icons.family_restroom_rounded),
  Category('kondangan', 'Kondangan', 'pink', Icons.card_giftcard_rounded),
  Category('charity', 'Sedekah', 'green', Icons.volunteer_activism_outlined),
  Category('other', 'Lainnya', 'gray', Icons.more_horiz_rounded),
];

const kIncomeCategories = <Category>[
  Category('salary', 'Gaji', 'green', Icons.work_outline_rounded, income: true),
  Category('bonus', 'THR/Bonus', 'amber', Icons.star_outline_rounded, income: true),
  Category('business', 'Usaha', 'orange', Icons.storefront_outlined, income: true),
  Category('freelance', 'Freelance', 'purple', Icons.laptop_mac_rounded, income: true),
  Category('allowance', 'Uang Saku', 'blue', Icons.account_balance_wallet_outlined, income: true),
  Category('otherIn', 'Lainnya', 'gray', Icons.more_horiz_rounded, income: true),
];

class Txn {
  Txn({
    required this.id,
    required this.name,
    required this.cat,
    required this.amount,
    required this.at,
  });

  final String id;
  final String name;
  final String cat;

  /// Negatif = pengeluaran, positif = pemasukan.
  final int amount;
  final DateTime at;

  bool get isExpense => amount < 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cat': cat,
        'amount': amount,
        'at': at.toIso8601String(),
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        name: j['name'] as String,
        cat: j['cat'] as String,
        amount: (j['amount'] as num).toInt(),
        at: DateTime.parse(j['at'] as String),
      );
}

class CustomCategory {
  CustomCategory(this.id, this.label, this.income);

  final String id;
  final String label;
  final bool income;

  Category toCategory() =>
      Category(id, label, 'gray', Icons.sell_outlined, income: income);

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'income': income};

  factory CustomCategory.fromJson(Map<String, dynamic> j) =>
      CustomCategory(j['id'] as String, j['label'] as String, j['income'] == true);
}

/// Satu kali menabung (positif) atau menarik (negatif) untuk sebuah target.
class SavingEntry {
  const SavingEntry(this.at, this.delta);

  final DateTime at;
  final int delta;
}

class Goal {
  Goal({required this.id, required this.name, required this.target, this.saved = 0, this.tone = 'green', List<SavingEntry>? log})
      : log = log ?? [];

  /// Catatan tabungan dibatasi supaya data tetap kecil.
  static const maxLog = 120;

  final String id;
  String name;
  int target;
  int saved;
  final String tone;

  /// Riwayat menabung (paling lama dulu), dipakai untuk memperkirakan kapan target tercapai.
  final List<SavingEntry> log;

  double get progress => target <= 0 ? 0 : (saved / target).clamp(0, 1).toDouble();

  void addLog(DateTime at, int delta) {
    if (delta == 0) return;
    log.add(SavingEntry(at, delta));
    if (log.length > maxLog) log.removeRange(0, log.length - maxLog);
  }

  /// Rata-rata tabungan per bulan dari 90 hari terakhir. null kalau belum ada kebiasaan menabung.
  int? monthlyRate([DateTime? now]) {
    final n = now ?? DateTime.now();
    final from = n.subtract(const Duration(days: 90));
    final recent = log.where((e) => !e.at.isBefore(from) && !e.at.isAfter(n)).toList();
    if (recent.isEmpty) return null;
    final net = recent.fold<int>(0, (s, e) => s + e.delta);
    if (net <= 0) return null;
    final span = n.difference(recent.first.at).inDays.clamp(30, 90);
    final rate = (net * 30 / span).round();
    return rate > 0 ? rate : null;
  }

  /// Perkiraan bulan target tercapai. null kalau sudah tercapai atau belum ada perkiraan.
  DateTime? eta([DateTime? now]) {
    final n = now ?? DateTime.now();
    if (target <= 0 || saved >= target) return null;
    final rate = monthlyRate(n);
    if (rate == null) return null;
    final months = ((target - saved) / rate).ceil();
    if (months > 600) return null;
    return DateTime(n.year, n.month + months);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'saved': saved,
        'tone': tone,
        if (log.isNotEmpty) 'log': [for (final e in log) [e.at.millisecondsSinceEpoch, e.delta]],
      };

  factory Goal.fromJson(Map<String, dynamic> j) {
    final log = <SavingEntry>[];
    final raw = j['log'];
    if (raw is List) {
      for (final e in raw.take(maxLog)) {
        if (e is List && e.length == 2 && e[0] is num && e[1] is num) {
          final ms = (e[0] as num).toInt();
          final d = (e[1] as num).toInt();
          // Catatan yang rusak dilewati, bukan menggagalkan seluruh data.
          if (ms < 0 || ms > 4102444800000 || d.abs() > 1000000000000) continue;
          log.add(SavingEntry(DateTime.fromMillisecondsSinceEpoch(ms), d));
        }
      }
    }
    return Goal(
      id: j['id'] as String,
      name: j['name'] as String,
      target: (j['target'] as num).toInt(),
      saved: (j['saved'] as num? ?? 0).toInt(),
      tone: (j['tone'] as String?) ?? 'green',
      log: log,
    );
  }
}

class QuickItem {
  const QuickItem(this.name, this.cat, this.idr, this.usd);

  final String name;
  final String cat;
  final int idr;
  final int usd;

  int get amount => L.currency == 'USD' ? usd : idr;
}

const kQuickItems = <QuickItem>[
  QuickItem('Kopi', 'food', 25000, 5),
  QuickItem('Ojol', 'transport', 20000, 10),
  QuickItem('Makan siang', 'food', 35000, 12),
  QuickItem('Parkir', 'transport', 5000, 3),
  QuickItem('Pulsa', 'bills', 50000, 20),
];

/// Tombol Catat Cepat yang bisa diatur sendiri.
class QuickEntry {
  QuickEntry({required this.name, required this.cat, required this.amount});

  String name;
  String cat;
  int amount;

  Map<String, dynamic> toJson() => {'name': name, 'cat': cat, 'amount': amount};

  factory QuickEntry.fromJson(Map<String, dynamic> j) =>
      QuickEntry(name: j['name'] as String? ?? '', cat: j['cat'] as String? ?? 'other', amount: (j['amount'] as num? ?? 0).toInt());
}

/// Transaksi berulang: tercatat otomatis setiap bulan pada tanggal [day].
class Recurring {
  Recurring({required this.id, required this.name, required this.cat, required this.amount, required this.day, this.lastPosted = ''});

  final String id;
  String name;
  String cat;

  /// Negatif = pengeluaran, positif = pemasukan.
  int amount;
  int day;

  /// Bulan terakhir tercatat, format yyyy-mm.
  String lastPosted;

  bool get isExpense => amount < 0;

  /// Nomor notifikasi pengingat tagihan.
  int get notifId => 500000 + (int.tryParse(id.length > 8 ? id.substring(id.length - 8) : id) ?? id.hashCode).abs() % 400000;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'cat': cat, 'amount': amount, 'day': day, 'lastPosted': lastPosted};

  factory Recurring.fromJson(Map<String, dynamic> j) => Recurring(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        cat: j['cat'] as String? ?? 'other',
        amount: (j['amount'] as num? ?? 0).toInt(),
        day: (j['day'] as num? ?? 1).toInt().clamp(1, 28),
        lastPosted: j['lastPosted'] as String? ?? '',
      );
}
