import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show ImageByteFormat;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/profile_items.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/settings/profile_page.dart';
import 'package:razarsa/features/settings/profile_share.dart';
import 'package:razarsa/features/settings/profile_style_sheet.dart';
import 'package:razarsa/widgets/profile_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

/// Memberi pengalaman sampai [level] (xp = aktivitas*10 + hari aktif*20 + tugas selesai*10).
void giveLevel(AppStore s, int level) {
  final need = (level - 1) * AppStore.xpPerLevel;
  var i = 0;
  while (s.xp < need) {
    s.addTxn(name: 'x${i++}', cat: 'food', amount: -1);
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadAppFonts();
  });
  setUp(() => L.lang = 'id');

  group('Aset profil', () {
    test('semua berkas yang dirujuk ada, valid WebP, dan ringan', () {
      final files = <String>[
        for (final a in kAvatars) a.asset,
        for (final f in kFrames) f.asset,
        for (final b in kBadges) b.asset,
        for (final c in kCovers.where((c) => c.id == 'desert')) ...[c.dayAsset, c.nightAsset],
      ];
      var total = 0;
      for (final path in files) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: 'hilang: $path');
        final bytes = f.readAsBytesSync();
        total += bytes.length;
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF', reason: path);
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP', reason: path);
        expect(bytes.length, lessThan(120 * 1024), reason: 'terlalu besar: $path (${bytes.length} B)');
      }
      expect(total, lessThan(1024 * 1024), reason: 'aset profil membengkak: ${total ~/ 1024} KB');
    });

    test('tidak ada berkas aset yatim (semua berkas di folder profil terpakai)', () {
      final used = {
        for (final a in kAvatars) a.asset,
        for (final f in kFrames) f.asset,
        for (final b in kBadges) b.asset,
        for (final c in kCovers) c.dayAsset,
        for (final c in kCovers) c.nightAsset,
      };
      for (final dir in ['avatars', 'frames', 'badges', 'covers']) {
        for (final e in Directory('assets/profile/$dir').listSync().whereType<File>()) {
          expect(used, contains(e.path.replaceAll('\\', '/')), reason: 'tidak dipakai: ${e.path}');
        }
      }
    });

    test('id unik dan semua terdaftar di pubspec', () {
      expect({for (final a in kAvatars) a.id}.length, kAvatars.length);
      expect({for (final f in kFrames) f.id}.length, kFrames.length);
      expect({for (final b in kBadges) b.id}.length, kBadges.length);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final dir in ['avatars', 'frames', 'badges', 'covers']) {
        expect(pubspec, contains('assets/profile/$dir/'));
      }
    });

    test('ukuran lubang bingkai masuk akal (avatar tidak lebih besar dari bingkai)', () {
      for (final f in kFrames) {
        expect(f.hole, inInclusiveRange(0.6, 0.9), reason: f.id);
      }
    });

    test('setiap lencana punya petunjuk cara membukanya', () {
      for (final b in kBadges) {
        expect(kBadgeHints[b.id], isNotNull, reason: b.id);
      }
    });
  });

  group('Pilihan avatar, bingkai, cover', () {
    test('nilai awal: avatar bawaan, tanpa bingkai, cover gurun', () async {
      final s = await newStore();
      expect((s.avatar, s.frame, s.cover), (kDefaultAvatar, kNoFrame, kDefaultCover));
    });

    test('setAvatar menerima id valid dan menolak yang tidak dikenal', () async {
      final s = await newStore();
      expect(s.setAvatar('a5'), isTrue);
      expect(s.avatar, 'a5');
      expect(s.setAvatar('../../etc/passwd'), isFalse);
      expect(s.setAvatar(''), isFalse);
      expect(s.avatar, 'a5');
    });

    test('bingkai terbuka bertahap menurut level', () async {
      final s = await newStore();
      expect(s.level, 1);
      expect(s.frameUnlocked('f1'), isTrue);
      expect(s.frameUnlocked('f2'), isFalse);
      expect(s.setFrame('f2'), isFalse, reason: 'belum terbuka di level 1');
      expect(s.frame, kNoFrame);
      giveLevel(s, 3);
      expect(s.setFrame('f3'), isTrue);
      expect(s.frame, 'f3');
      expect(s.setFrame('f4'), isFalse, reason: 'f4 butuh level 5');
      expect(s.setFrame(kNoFrame), isTrue);
      expect(s.setFrame('tidak-ada'), isFalse);
    });

    test('bingkai yang belum terbuka tidak tampil walau pilihan tersimpan (level turun)', () async {
      final s = await newStore();
      giveLevel(s, 3);
      s.setFrame('f3');
      expect(s.effectiveFrame, 'f3');
      await s.clearAll(); // XP kembali ke awal
      s.frame = 'f3'; // pilihan lama masih ada
      expect(s.level, 1);
      expect(s.effectiveFrame, kNoFrame);
    });

    test('setCover memeriksa id', () async {
      final s = await newStore();
      expect(s.setCover('mountain'), isTrue);
      expect(s.setCover('lava'), isFalse);
      expect(s.cover, 'mountain');
    });

    test('pilihan tersimpan permanen', () async {
      final s = await newStore();
      giveLevel(s, 2);
      s.setAvatar('a3');
      s.setFrame('f2');
      s.setCover('mountain');
      await s.flush();
      final b = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      expect((b.avatar, b.frame, b.cover), ('a3', 'f2', 'mountain'));
    });

    test('data tersimpan yang rusak/tidak dikenal jatuh ke bawaan, tanpa crash', () async {
      SharedPreferences.setMockInitialValues({'avatar': 'hacked', 'frame': 5, 'cover': '<script>'});
      final s = AppStore(await SharedPreferences.getInstance(), vault: testVault);
      expect((s.avatar, s.frame, s.cover), (kDefaultAvatar, kNoFrame, kDefaultCover));
    });

    test('hapus semua data mengembalikan tampilan profil ke bawaan', () async {
      final s = await newStore();
      giveLevel(s, 2);
      s.setAvatar('a7');
      s.setFrame('f2');
      s.setCover('mountain');
      await s.clearAll();
      expect((s.avatar, s.frame, s.cover), (kDefaultAvatar, kNoFrame, kDefaultCover));
    });

    test('ikut backup, dan nilai di file backup diperiksa saat dipulihkan', () async {
      final a = await newStore();
      giveLevel(a, 2);
      a.setAvatar('a6');
      a.setFrame('f2');
      a.setCover('mountain');
      final file = a.exportJson();
      final b = await newStore();
      expect(await b.importBackup(file), BackupResult.ok);
      expect((b.avatar, b.frame, b.cover), ('a6', 'f2', 'mountain'));

      final bad = jsonDecode(file) as Map<String, dynamic>;
      (bad['profile'] as Map)['avatar'] = '../x';
      (bad['profile'] as Map)['frame'] = 'f999';
      (bad['profile'] as Map)['cover'] = 7;
      final c = await newStore();
      expect(await c.importBackup(jsonEncode(bad)), BackupResult.ok);
      expect((c.avatar, c.frame, c.cover), (kDefaultAvatar, kNoFrame, kDefaultCover));
    });
  });

  group('Lencana', () {
    Future<Set<String>> unlocked(AppStore s) async => {for (final b in kBadges.where((b) => b.check(s))) b.id};

    test('profil baru: belum ada lencana', () async {
      final s = await newStore();
      expect(await unlocked(s), isEmpty);
    });

    test('Langkah pertama: satu aktivitas apa saja', () async {
      final s = await newStore();
      s.addTodo('x', cat: 'Pribadi', tone: 'teal');
      expect(await unlocked(s), {'b01'});
    });

    test('Pencatat rajin: 50 transaksi (49 belum)', () async {
      final s = await newStore();
      for (var i = 0; i < 49; i++) {
        s.addTxn(name: 't$i', cat: 'food', amount: -1);
      }
      expect((await unlocked(s)).contains('b05'), isFalse);
      s.addTxn(name: 'ke-50', cat: 'food', amount: -1);
      expect((await unlocked(s)).contains('b05'), isTrue);
    });

    test('Target tercapai: saat tabungan mencapai jumlah target', () async {
      final s = await newStore();
      s.addGoal('Laptop', 1000);
      s.addToGoal(s.goals.single.id, 999);
      expect((await unlocked(s)).contains('b06'), isFalse);
      s.addToGoal(s.goals.single.id, 1);
      expect((await unlocked(s)).contains('b06'), isTrue);
    });

    test('10 tugas tuntas, 10 catatan, 10 agenda', () async {
      final s = await newStore();
      for (var i = 0; i < 10; i++) {
        final t = s.addTodo('t$i', cat: 'Pribadi', tone: 'teal');
        s.toggleTodo(t.id);
        s.addNote(title: 'n$i');
        s.addAgenda('a$i', DateTime.now());
      }
      final got = await unlocked(s);
      expect(got, containsAll(['b04', 'b07', 'b08']));
    });

    test('Level 3 dan Level 5 mengikuti level', () async {
      final s = await newStore();
      giveLevel(s, 3);
      expect(await unlocked(s), contains('b10'));
      expect(await unlocked(s), isNot(contains('b11')));
      giveLevel(s, 5);
      expect(await unlocked(s), containsAll(['b10', 'b11', 'b12']));
    });

    test('7 hari beruntun dan 30 hari aktif', () async {
      final s = await newStore();
      String day(int n) => DateTime.now().subtract(Duration(days: n)).toIso8601String().substring(0, 10);
      s.activeDays = [for (var i = 0; i < 7; i++) day(i)];
      expect(await unlocked(s), contains('b02'));
      expect(await unlocked(s), isNot(contains('b09')));
      s.activeDays = [for (var i = 0; i < 30; i++) day(i)];
      expect(await unlocked(s), containsAll(['b02', 'b09']));
    });

    test('Hemat sebulan: pengeluaran periode lalu ada dan tidak melebihi anggaran', () async {
      final s = await newStore();
      final (from, _) = s.periodRange(1);
      s.setBudget(1000000);
      s.addTxn(name: 'lalu', cat: 'food', amount: -400000, at: from.add(const Duration(days: 2)));
      expect(await unlocked(s), contains('b03'));
      s.addTxn(name: 'boros', cat: 'food', amount: -700000, at: from.add(const Duration(days: 3)));
      expect(await unlocked(s), isNot(contains('b03')));
    });
  });

  group('Tampilan', () {
    Future<void> pumpProfile(WidgetTester t, AppStore s, {Widget? home, bool dark = false}) async {
      t.view.physicalSize = const Size(390 * 2, 844 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(StoreScope(
        store: s,
        child: MaterialApp(theme: buildTheme(dark ? Brightness.dark : Brightness.light), home: home ?? const ProfilePage()),
      ));
      await t.pump(const Duration(milliseconds: 800));
    }

    testWidgets('halaman profil memakai avatar pilihan dan 12 lencana tanpa placeholder', (t) async {
      final s = await newStore();
      s.setAvatar('a4');
      await pumpProfile(t, s);
      expect(find.byType(ProfileAvatar), findsOneWidget);
      expect(find.byType(BadgeImage), findsNWidgets(kBadges.length));
      expect(find.textContaining('segera hadir'), findsNothing);
      expect(find.text('Tampilan'), findsOneWidget);
      expect(find.text('Bagikan'), findsOneWidget);
    });

    testWidgets('lembar tampilan: pilih avatar dan cover; bingkai terkunci memberi petunjuk level', (t) async {
      final s = await newStore();
      await pumpProfile(t, s, home: const Scaffold(body: ProfileStyleSheet()));
      await t.tap(find.byKey(const ValueKey('avatar-a5')));
      await t.pump();
      expect(s.avatar, 'a5');
      await t.tap(find.byKey(const ValueKey('cover-mountain')));
      await t.pump();
      expect(s.cover, 'mountain');
      await t.ensureVisible(find.byKey(const ValueKey('frame-f4')));
      await t.tap(find.byKey(const ValueKey('frame-f4')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(s.frame, kNoFrame, reason: 'f4 masih terkunci');
      expect(find.byKey(const ValueKey('frame-hint')), findsOneWidget); // di dalam lembar, bukan toast yang tertutup lembar
      expect(find.textContaining('terbuka di Level 5'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('frame-f1')));
      await t.pump();
      expect(s.frame, 'f1');
      await t.tap(find.byKey(const ValueKey('frame-none')));
      await t.pump();
      expect(s.frame, kNoFrame);
    });

    testWidgets('mengetuk avatar di profil membuka lembar tampilan', (t) async {
      final s = await newStore();
      await pumpProfile(t, s);
      await t.tap(find.byType(ProfileAvatar));
      await t.pumpAndSettle();
      expect(find.text('Ubah tampilan profil'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
    });

    testWidgets('tema gelap: halaman profil dan lembar tampil tanpa error', (t) async {
      final s = await newStore();
      giveLevel(s, 5);
      s.setFrame('f4');
      await pumpProfile(t, s, dark: true);
      expect(t.takeException(), isNull);
      await t.tap(find.byType(ProfileAvatar));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('ketuk lencana terkunci menampilkan cara membukanya', (t) async {
      final s = await newStore();
      await pumpProfile(t, s);
      await t.tap(find.text('Pencatat rajin'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Catat 50 transaksi'), findsOneWidget);
    });
  });

  group('Kartu bagikan', () {
    testWidgets('berisi nama, level, statistik, dan lencana; TANPA nominal uang atau data keuangan', (t) async {
      final s = await newStore();
      s.login(name: 'Budi');
      s.addTxn(name: 'Gaji', cat: 'salary', amount: 12345678);
      s.addTxn(name: 'Kopi rahasia', cat: 'food', amount: -25000);
      s.addGoal('Rumah impian', 999000000);
      t.view.physicalSize = const Size(400 * 2, 500 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Center(child: ProfileShareCard(store: s, dark: false)),
      ));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Budi'), findsOneWidget);
      expect(find.textContaining('Level 1'), findsOneWidget);
      expect(find.text('razarsa'), findsOneWidget);
      final texts = [for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? ''].join(' | ');
      for (final forbidden in ['Rp', r'$', '12.345', '25.000', 'Gaji', 'Kopi', 'Rumah', 'Saldo', 'Anggaran']) {
        expect(texts, isNot(contains(forbidden)), reason: 'kartu tidak boleh memuat "$forbidden"');
      }
      expect(noRupiahText(t), isTrue);
    });

    testWidgets('kartu bisa dipotret menjadi PNG 1080x1350 (pixelRatio 3)', (t) async {
      final s = await newStore();
      s.login(name: 'Budi');
      s.addTodo('x', cat: 'Pribadi', tone: 'teal');
      final key = GlobalKey();
      t.view.physicalSize = const Size(400 * 2, 500 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Center(child: RepaintBoundary(key: key, child: ProfileShareCard(store: s, dark: false))),
      ));
      await t.runAsync(() async {
        final ctx = key.currentContext!;
        for (final a in shareCardAssets(s)) {
          await precacheImage(AssetImage(a), ctx);
        }
      });
      await t.pump(const Duration(milliseconds: 300));
      final bytes = await t.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        return (await image.toByteData(format: ImageByteFormat.png))!.buffer.asUint8List();
      });
      expect(bytes!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10], reason: 'tanda tangan PNG');
      final bd = ByteData.sublistView(bytes);
      expect((bd.getUint32(16), bd.getUint32(20)), (1080, 1350));
      expect(bytes.length, greaterThan(20 * 1024), reason: 'gambar tidak boleh kosong');
      final dir = Platform.environment['RAZARSA_CARD_OUT'];
      if (dir != null) File('$dir/share_card.png').writeAsBytesSync(bytes);
    });
  });
}

/// Pemeriksaan tambahan: tidak ada widget teks yang memuat angka berformat rupiah.
bool noRupiahText(WidgetTester t) {
  final rupiah = RegExp(r'\d{1,3}(\.\d{3})+');
  return !t.widgetList<Text>(find.byType(Text)).any((w) => rupiah.hasMatch(w.data ?? ''));
}
