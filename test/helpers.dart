import 'package:flutter/services.dart';
import 'package:razarsa/core/crypto.dart';

/// Kunci enkripsi tetap untuk seluruh tes, supaya "buka ulang aplikasi" memakai kunci yang sama.
final testVault = MemoryKeyVault();

/// Memuat font asli aplikasi ke tes, supaya lebar teks sama dengan di HP
/// (font bawaan tes jauh lebih lebar dan memunculkan overflow palsu).
Future<void> loadAppFonts() async {
  final loader = FontLoader('PlusJakartaSans');
  for (final w in [400, 500, 600, 700, 800]) {
    loader.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await loader.load();
}
