import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Foto profil dan sampul buatan pengguna. Foto diperkecil dan dipotong (cover) di HP,
/// disimpan sebagai berkas PNG di folder data aplikasi, dan TIDAK ikut backup (hanya jalurnya yang lokal).
class PhotoService {
  PhotoService._();

  /// Ukuran berkas asal maksimal yang diterima.
  static const maxBytes = 10 * 1024 * 1024;

  static const avatarSize = (320, 320);
  static const coverSize = (900, 315);

  /// Memotong [bytes] (gambar apa pun yang didukung Android) menjadi PNG [w]x[h] dengan mode cover
  /// (mengisi penuh, bagian lebih dipotong dari tengah). null kalau bukan gambar yang bisa dibaca.
  @visibleForTesting
  static Future<Uint8List?> process(Uint8List bytes, int w, int h) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: w * 2);
      final frame = await codec.getNextFrame();
      final src = frame.image;
      final iw = src.width.toDouble(), ih = src.height.toDouble();
      final k = math.max(w / iw, h / ih);
      final dw = iw * k, dh = ih * k;
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
      canvas.drawImageRect(
        src,
        ui.Rect.fromLTWH(0, 0, iw, ih),
        ui.Rect.fromLTWH((w - dw) / 2, (h - dh) / 2, dw, dh),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final out = await rec.endRecording().toImage(w, h);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      src.dispose();
      out.dispose();
      return data?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Razarsa: foto tidak bisa diproses: $e');
      return null;
    }
  }

  /// Hasil [pick]: jalur berkas tersimpan, atau alasan gagal untuk ditampilkan ke pengguna.
  static Future<({String? path, String? error})> pick({required String kind, required (int, int) size}) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return (path: null, error: null);
      final file = files.first.xFile;
      if (await file.length() > maxBytes) return (path: null, error: 'big');
      final png = await process(await file.readAsBytes(), size.$1, size.$2);
      if (png == null) return (path: null, error: 'bad');
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/profile');
      await dir.create(recursive: true);
      final out = File('${dir.path}/$kind-${DateTime.now().millisecondsSinceEpoch}.png');
      await out.writeAsBytes(png, flush: true);
      return (path: out.path, error: null);
    } catch (e) {
      debugPrint('Razarsa: memilih foto gagal: $e');
      return (path: null, error: 'bad');
    }
  }

  /// Menghapus berkas foto lama (diam-diam; boleh sudah tidak ada).
  static Future<void> delete(String path) async {
    if (path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('Razarsa: gagal menghapus foto: $e');
    }
  }
}
