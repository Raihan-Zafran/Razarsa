import 'package:intl/intl.dart';

import 'i18n.dart';

bool get _usd => L.currency == 'USD';

/// Simbol mata uang aktif.
String get currencySymbol => _usd ? r'$' : 'Rp';

/// 12580750 -> "12.580.750" (Rupiah) atau "12,580,750" (Dolar)
String dots(num n) {
  final s = n.abs().round().toString();
  final sep = _usd ? ',' : '.';
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(sep);
    b.write(s[i]);
  }
  return b.toString();
}

/// 25000 -> "Rp 25.000" atau "$25,000"
String rp(num n) => _usd ? '\$${dots(n)}' : 'Rp ${dots(n)}';

/// Tanda + atau - di depan nominal.
String rpSigned(num n) => '${n < 0 ? '-' : '+'}${rp(n)}';

/// Nominal tersembunyi.
String get rpHidden => _usd ? r'$ ••••••' : 'Rp ••••••••';

/// 3240600 -> "Rp 3,2 jt" / "$3.2M"; 25000 -> "Rp 25 rb" / "$25K"
String rpShort(num n) {
  final v = n.abs();
  String one(double x) {
    final t = x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1);
    return _usd ? t : t.replaceAll('.', ',');
  }

  if (v >= 1000000) {
    final x = (v / 100000).round() / 10;
    return _usd ? '\$${one(x)}M' : 'Rp ${one(x)} jt';
  }
  if (v >= 1000) {
    return _usd ? '\$${one((v / 100).round() / 10)}K' : 'Rp ${(v / 1000).round()} rb';
  }
  return rp(v);
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Hari ini", "Kemarin", atau "3 November 2026".
String dayLabel(DateTime d, {DateTime? now}) {
  final today = dayOnly(now ?? DateTime.now());
  final diff = today.difference(dayOnly(d)).inDays;
  if (diff == 0) return tr('Hari ini');
  if (diff == 1) return tr('Kemarin');
  return DateFormat(L.en ? 'MMMM d, y' : 'd MMMM y', L.dateLocale).format(d);
}

String shortDate(DateTime d) => DateFormat(L.en ? 'MMM d, y' : 'd MMM y', L.dateLocale).format(d);

String timeLabel(DateTime d) => DateFormat(L.en ? 'h:mm a' : 'HH.mm', L.dateLocale).format(d);

String monthShort(DateTime d) => DateFormat('MMM', L.dateLocale).format(d);

String monthLong(DateTime d) => DateFormat('MMMM', L.dateLocale).format(d);

/// Sapaan sesuai jam.
String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 11) return tr('Selamat pagi');
  if (h < 15) return tr('Selamat siang');
  if (h < 18) return tr('Selamat sore');
  return tr('Selamat malam');
}
