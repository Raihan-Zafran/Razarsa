import 'package:intl/intl.dart';

/// 12580750 -> "12.580.750"
String dots(num n) {
  final s = n.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// 25000 -> "Rp 25.000"
String rp(num n) => 'Rp ${dots(n)}';

/// Tanda + atau - di depan nominal.
String rpSigned(num n) => '${n < 0 ? '-' : '+'}${rp(n)}';

/// 3240600 -> "Rp 3,2 jt", 25000 -> "Rp 25 rb"
String rpShort(num n) {
  final v = n.abs();
  if (v >= 1000000) {
    final jt = (v / 100000).round() / 10;
    final txt = jt == jt.roundToDouble()
        ? jt.toStringAsFixed(0)
        : jt.toStringAsFixed(1).replaceAll('.', ',');
    return 'Rp $txt jt';
  }
  if (v >= 1000) return 'Rp ${(v / 1000).round()} rb';
  return rp(v);
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Hari ini", "Kemarin", atau "3 November 2026".
String dayLabel(DateTime d, {DateTime? now}) {
  final today = dayOnly(now ?? DateTime.now());
  final day = dayOnly(d);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  return DateFormat('d MMMM y', 'id_ID').format(d);
}

String timeLabel(DateTime d) => DateFormat('HH.mm', 'id_ID').format(d);

String monthShort(DateTime d) => DateFormat('MMM', 'id_ID').format(d);

String monthLong(DateTime d) => DateFormat('MMMM', 'id_ID').format(d);

/// Sapaan sesuai jam.
String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 11) return 'Selamat pagi';
  if (h < 15) return 'Selamat siang';
  if (h < 18) return 'Selamat sore';
  return 'Selamat malam';
}
