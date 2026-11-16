import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/finance/desktop_report.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  test('laporan cetak: ringkasan, kategori, transaksi; teks pengguna di-escape', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(await SharedPreferences.getInstance(), vault: testVault);
    final day = DateTime(2026, 11, 10, 12);
    s.addTxn(name: '<script>alert(1)</script>', amount: -25000, cat: 'food', at: day);
    s.addTxn(name: 'Gaji', amount: 6000000, cat: 'salary', at: day);
    final html = reportHtml(s, DateTime(2026, 11, 1), DateTime(2026, 12, 1), 6000000, 25000, [const MapEntry('food', 25000)], {'food': 1});
    expect(html, contains('Rp 6.000.000'));
    expect(html, contains('Rp 25.000'));
    expect(html, contains('100%'));
    expect(html, contains('Gaji'));
    expect(html, isNot(contains('<script>alert(1)')));
    expect(html, contains('&lt;script&gt;'));
    expect(html, contains('window.print()'));
  });
}
