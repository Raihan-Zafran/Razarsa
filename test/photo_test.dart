import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:razarsa/core/i18n.dart';
import 'package:razarsa/core/theme.dart';
import 'package:razarsa/data/photo_service.dart';
import 'package:razarsa/data/store.dart';
import 'package:razarsa/features/settings/profile_style_sheet.dart';
import 'package:razarsa/widgets/profile_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> newStore([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  return AppStore(await SharedPreferences.getInstance(), vault: testVault);
}

/// PNG polos [w]x[h] berwarna [c].
Future<Uint8List> solidPng(int w, int h, Color c) async {
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = c);
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => L.lang = 'id');

  group('Pengolahan foto', () {
    testWidgets('foto lebar dipotong cover ke ukuran avatar dan sampul', (t) async {
      await t.runAsync(() async {
        final src = await solidPng(1200, 600, const Color(0xFF336699));
        final a = await PhotoService.process(src, 320, 320);
        expect(a, isNotNull);
        final ia = await decodeImageFromList(a!);
        expect((ia.width, ia.height), (320, 320));
        final c = await PhotoService.process(src, 900, 315);
        final ic = await decodeImageFromList(c!);
        expect((ic.width, ic.height), (900, 315));
      });
    });

    testWidgets('berkas yang bukan gambar ditolak (null), tidak melempar galat', (t) async {
      await t.runAsync(() async {
        expect(await PhotoService.process(Uint8List.fromList([1, 2, 3, 4, 5]), 320, 320), isNull);
        expect(await PhotoService.process(Uint8List(0), 320, 320), isNull);
      });
    });
  });

  group('Foto di store', () {
    test('bawaan kosong dan tersimpan di prefs, tetapi tidak ikut backup', () async {
      final s = await newStore();
      expect(s.photoPath, '');
      expect(s.coverPhotoPath, '');
      s.setPhotoPath('/data/foto.png');
      s.setCoverPhotoPath('/data/sampul.png');
      await s.flush();
      final prefs = await SharedPreferences.getInstance();
      final back = AppStore(prefs, vault: testVault);
      expect(back.photoPath, '/data/foto.png');
      expect(back.coverPhotoPath, '/data/sampul.png');
      expect(s.exportJson().contains('/data/foto.png'), isFalse, reason: 'jalur berkas HP ini tidak boleh bocor ke backup');
    });

    test('mengganti foto menghapus berkas lama', () async {
      final dir = Directory.systemTemp.createTempSync('razarsa_foto');
      addTearDown(() => dir.deleteSync(recursive: true));
      final old = File('${dir.path}/lama.png')..writeAsBytesSync([1]);
      final neu = File('${dir.path}/baru.png')..writeAsBytesSync([2]);
      final s = await newStore();
      s.setPhotoPath(old.path);
      s.setPhotoPath(neu.path);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(old.existsSync(), isFalse);
      expect(neu.existsSync(), isTrue);
    });

    test('nilai rusak di penyimpanan menjadi kosong', () async {
      final s = await newStore({'photoPath': 5, 'coverPhotoPath': true});
      expect(s.photoPath, '');
      expect(s.coverPhotoPath, '');
    });
  });

  group('Tampilan foto', () {
    Future<void> pump(WidgetTester t, AppStore s, Widget home) => t.pumpWidget(StoreScope(
          store: s,
          child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
        ));

    testWidgets('berkas foto yang hilang: avatar kembali ke bawaan tanpa galat', (t) async {
      final s = await newStore();
      s.setPhotoPath('/tidak/ada.png');
      await pump(t, s, const Scaffold(body: Center(child: ProfileAvatar(size: 96))));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('lembar tampilan: tombol Unggah foto selalu ada, Hapus foto hanya saat ada foto', (t) async {
      final s = await newStore();
      await pump(t, s, const Scaffold(body: ProfileStyleSheet()));
      expect(find.text('Unggah foto'), findsNWidgets(2)); // foto profil dan cover
      expect(find.text('Hapus foto'), findsNothing);
      s.setPhotoPath('/x/a.png');
      await t.pump();
      expect(find.text('Hapus foto'), findsOneWidget);
      await t.tap(find.text('Hapus foto'));
      await t.pump();
      expect(s.photoPath, '');
      expect(find.text('Hapus foto'), findsNothing);
      s.setCoverPhotoPath('/x/c.png');
      await t.pump();
      expect(find.text('Hapus foto'), findsOneWidget);
      await t.tap(find.text('Hapus foto'));
      await t.pump();
      expect(s.coverPhotoPath, '');
    });

    testWidgets('sampul foto menggantikan sampul bawaan di ProfileCover', (t) async {
      final dir = Directory.systemTemp.createTempSync('razarsa_foto');
      addTearDown(() => dir.deleteSync(recursive: true));
      late File f;
      await t.runAsync(() async => f = File('${dir.path}/c.png')..writeAsBytesSync(await solidPng(20, 10, Colors.red)));
      final s = await newStore();
      s.setCoverPhotoPath(f.path);
      await pump(t, s, const Scaffold(body: SizedBox(height: 100, child: ProfileCover())));
      await t.pump(const Duration(milliseconds: 200));
      final img = t.widget<Image>(find.byType(Image).first);
      expect(img.image, isA<FileImage>());
    });
  });
}
