import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/data/models.dart';
import 'package:razarsa/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> open() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

void main() {
  setUp(() => L.lang = 'id');

  group('Kategori khusus tidak boleh duplikat', () {
    test('nama sama dua kali: kategori yang sama dipakai, daftar tidak bertambah', () async {
      final s = await open();
      final a = s.addCustomCategory('Hobi', income: false);
      final b = s.addCustomCategory('Hobi', income: false);
      expect(b.id, a.id);
      expect(s.customCats.length, 1);
    });

    test('huruf besar/kecil dan spasi tidak membedakan', () async {
      final s = await open();
      final a = s.addCustomCategory('Hobi Baru', income: false);
      expect(s.addCustomCategory('  hobi   BARU ', income: false).id, a.id);
      expect(s.addCustomCategory('HOBI BARU', income: false).id, a.id);
      expect(s.customCats.length, 1);
    });

    test('sama dengan kategori bawaan: memakai kategori bawaan, tidak membuat tiruan', () async {
      final s = await open();
      final food = s.addCustomCategory('makan & minum', income: false);
      expect(food.id, 'food');
      final salary = s.addCustomCategory('GAJI', income: true);
      expect(salary.id, 'salary');
      expect(s.customCats, isEmpty);
    });

    test('nama bawaan versi Inggris juga dikenali saat bahasa Inggris', () async {
      final s = await open();
      L.lang = 'en';
      final enName = kExpenseCategories.firstWhere((c) => c.id == 'transport').label; // nama Inggris saat ini
      expect(enName, isNot('Transportasi'));
      expect(s.addCustomCategory(enName.toUpperCase(), income: false).id, 'transport');
      expect(s.customCats, isEmpty);
    });

    test('nama yang sama boleh ada di pengeluaran dan pemasukan (jenis berbeda)', () async {
      final s = await open();
      final out = s.addCustomCategory('Proyek', income: false);
      final inc = s.addCustomCategory('Proyek', income: true);
      expect(inc.id, isNot(out.id));
      expect(s.customCats.length, 2);
    });

    test('kosong atau hanya spasi: tidak membuat kategori (jatuh ke "Lainnya")', () async {
      final s = await open();
      expect(s.addCustomCategory('   ', income: false).id, 'other');
      expect(s.addCustomCategory('', income: true).id, 'otherIn');
      expect(s.customCats, isEmpty);
    });

    test('nama terlalu panjang dipotong 16 karakter, lalu diperiksa duplikatnya', () async {
      final s = await open();
      final a = s.addCustomCategory('Belanja bulanan keluarga besar', income: false);
      expect(a.label.length, lessThanOrEqualTo(16));
      expect(s.addCustomCategory('Belanja bulanan keluarga besar sekali', income: false).id, a.id);
      expect(s.customCats.length, 1);
    });

    test('id unik untuk kategori yang memang berbeda', () async {
      final s = await open();
      final ids = {for (final n in ['A', 'B', 'C', 'D']) s.addCustomCategory(n, income: false).id};
      expect(ids.length, 4);
    });

    test('kategori tersimpan dan tidak digandakan setelah aplikasi dibuka ulang', () async {
      final s = await open();
      s.addCustomCategory('Hobi', income: false);
      await s.flush();
      final b = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      b.addCustomCategory('hobi', income: false);
      expect(b.customCats.length, 1);
    });

    test('daftar kategori yang tampil di form tidak memuat nama kembar', () async {
      final s = await open();
      s.addCustomCategory('Hobi', income: false);
      s.addCustomCategory('hobi', income: false);
      s.addCustomCategory('Makan & Minum', income: false);
      final labels = s.categories(income: false).map((c) => c.label.toLowerCase()).toList();
      expect(labels.toSet().length, labels.length);
    });

    test('Category.idLabel menyimpan nama sumber (Indonesia) untuk perbandingan lintas bahasa', () {
      expect(kExpenseCategories.first.idLabel, 'Makan & Minum');
    });
  });
}
