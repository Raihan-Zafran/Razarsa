import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/auth/login_screen.dart';
import 'package:razarsa/features/finance/add_transaction_page.dart';
import 'package:razarsa/features/finance/goals_page.dart';
import 'package:razarsa/features/finance/home_page.dart';
import 'package:razarsa/features/finance/report_page.dart';
import 'package:razarsa/features/finance/transactions_page.dart';
import 'package:razarsa/features/productive/calendar_page.dart';
import 'package:razarsa/features/productive/notes_page.dart';
import 'package:razarsa/features/productive/prod_home_page.dart';
import 'package:razarsa/features/productive/todo_page.dart';
import 'package:razarsa/features/security/lock.dart';
import 'package:razarsa/features/settings/manage_pages.dart';
import 'package:razarsa/features/settings/profile_page.dart';
import 'package:razarsa/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Semua halaman utama di layar kecil dan font besar: tidak boleh ada overflow
/// (tombol/teks terpotong atau tak terjangkau) maupun error layout lain.
void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
  });

  final pages = <String, Widget Function()>{
    'Login': () => const LoginScreen(),
    'Beranda Keuangan': () => HomePage(onSeeAll: () {}),
    'Transaksi': () => const TransactionsPage(),
    'Laporan': () => const ReportPage(),
    'Target': () => const GoalsPage(),
    'Tambah pengeluaran': () => const AddTransactionPage(income: false),
    'Tambah pemasukan': () => const AddTransactionPage(income: true),
    'Beranda Produktif': () => ProdHomePage(goTo: (_) {}),
    'Tugas': () => const TodoPage(),
    'Kalender': () => const CalendarPage(),
    'Catatan': () => const NotesPage(),
    'Pengaturan': () => const SettingsPage(),
    'Profil': () => const ProfilePage(),
    'Tentang': () => const AboutPage(),
    'Privasi': () => LegalPage.privacy(),
    'Ketentuan': () => LegalPage.terms(),
    'Catat Cepat': () => const QuickItemsPage(),
    'Berulang': () => const RecurringPage(),
    'Kategori': () => const CategoriesPage(),
    'Anggaran per kategori': () => const CategoryBudgetsPage(),
    'Buat PIN': () => const PinSetupPage(),
    'Masukkan PIN': () => const PinVerifyPage(),
  };

  const sizes = <(String, Size)>[
    ('320x568', Size(320, 568)),
    ('360x640', Size(360, 640)),
    ('411x891', Size(411, 891)),
  ];
  const scales = [1.0, 1.5];

  Future<AppStore> seeded() async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(await SharedPreferences.getInstance(), vault: testVault);
    s.setPin('123456');
    s.addTxn(name: 'Makan siang nasi padang pakai ayam bakar dan es teh manis', cat: 'food', amount: -35000);
    s.addTxn(name: 'Gaji', cat: 'salary', amount: 12500000);
    s.addGoal('Laptop baru untuk kuliah dan kerja freelance', 15000000);
    s.addTodo('Mengerjakan tugas besar kuliah', cat: 'Kuliah', tone: 'purple', due: DateTime.now());
    s.addAgenda('Rapat dengan dosen pembimbing skripsi', DateTime.now(), reminder: true);
    s.addNote(title: 'Judul catatan yang sangat panjang sekali supaya terpotong', body: 'Isi ' * 80);
    s.addRecurring(name: 'Kos bulanan', cat: 'housing', amount: -1200000, day: 5);
    return s;
  }

  for (final lang in ['id', 'en']) {
   for (final dark in [false, true]) {
    for (final (sizeName, size) in sizes) {
      for (final scale in scales) {
        testWidgets('tanpa overflow: $lang, $sizeName, font ${scale}x, ${dark ? 'gelap' : 'terang'}', (t) async {
          t.view.physicalSize = size * 2;
          t.view.devicePixelRatio = 2;
          addTearDown(t.view.reset);
          L.lang = lang;
          final store = await seeded();
          final problems = <String>[];
          for (final e in pages.entries) {
            await t.pumpWidget(StoreScope(
              store: store,
              child: MaterialApp(
                theme: buildTheme(dark ? Brightness.dark : Brightness.light),
                builder: (c, child) => MediaQuery(
                  data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(body: e.value()),
              ),
            ));
            await t.pump(const Duration(milliseconds: 700));
            final ex = t.takeException();
            if (ex != null) {
              problems.add('${e.key}: ${ex.toString().split('\n').first}');
              // ignore: avoid_print
              print('OVF|$sizeName|$scale|${dark ? 'gelap' : 'terang'}|${e.key}|${ex.toString().split('\n').first.replaceAll('A RenderFlex overflowed by ', '')}');
            }
          }
          expect(problems, isEmpty, reason: problems.join('\n'));
        });
      }
    }
  }
  }
}
