import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Byte acak dari generator aman milik sistem.
Uint8List randomBytes(int n) {
  final rnd = Random.secure();
  return Uint8List.fromList(List<int>.generate(n, (_) => rnd.nextInt(256)));
}

/// PBKDF2-HMAC-SHA256. Hasilnya sama dengan implementasi lama untuk panjang 32 byte,
/// jadi hash PIN versi sebelumnya tetap bisa diperiksa.
Uint8List pbkdf2(String secret, List<int> salt, int iterations, {int length = 32}) {
  final d = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(Uint8List.fromList(salt), iterations, length));
  return d.process(Uint8List.fromList(utf8.encode(secret)));
}

/// Untuk dijalankan lewat `compute` supaya KDF berat tidak membekukan layar.
Uint8List _pbkdf2Job((String, List<int>, int) a) => pbkdf2(a.$1, a.$2, a.$3);

Future<Uint8List> pbkdf2Async(String secret, List<int> salt, int iterations) =>
    compute(_pbkdf2Job, (secret, salt, iterations));

const _nonceLen = 12;
const _tagBits = 128;

/// AES-256-GCM. Hasil: base64(nonce 12 byte + ciphertext + tag 16 byte).
/// [aad] ikut diautentikasi (dipakai untuk mengikat ciphertext ke id catatan).
String aesGcmSeal(Uint8List key, List<int> plain, {String aad = ''}) {
  assert(key.length == 32);
  final nonce = randomBytes(_nonceLen);
  final c = GCMBlockCipher(AESEngine())
    ..init(true, AEADParameters(KeyParameter(key), _tagBits, nonce, Uint8List.fromList(utf8.encode(aad))));
  final out = c.process(Uint8List.fromList(plain));
  return base64.encode([...nonce, ...out]);
}

/// Kebalikan [aesGcmSeal]. null kalau kunci salah atau data diubah orang lain.
Uint8List? aesGcmOpen(Uint8List key, String sealed, {String aad = ''}) {
  try {
    final raw = base64.decode(sealed);
    if (raw.length < _nonceLen + 16) return null;
    final c = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), _tagBits, Uint8List.fromList(raw.sublist(0, _nonceLen)),
          Uint8List.fromList(utf8.encode(aad))));
    return c.process(Uint8List.fromList(raw.sublist(_nonceLen)));
  } catch (_) {
    return null;
  }
}

/// Pemegang kunci utama perangkat (AES-256) untuk catatan terkunci.
abstract class KeyVault {
  /// Kunci 32 byte, atau null kalau penyimpanan aman tidak bisa dipakai.
  Uint8List? get key;

  bool get available => key != null;
}

/// Kunci di memori. Untuk tes.
class MemoryKeyVault extends KeyVault {
  MemoryKeyVault([Uint8List? key]) : _key = key ?? randomBytes(32);

  MemoryKeyVault.unavailable() : _key = null;

  final Uint8List? _key;

  @override
  Uint8List? get key => _key;
}

/// Kunci disimpan di Android Keystore lewat flutter_secure_storage.
/// Kunci dibuat sekali, tidak pernah ikut backup, dan hilang kalau data aplikasi dihapus.
class SecureKeyVault extends KeyVault {
  SecureKeyVault._(this._key);

  final Uint8List? _key;

  @override
  Uint8List? get key => _key;

  static const _name = 'razarsa_master_key_v1';

  static Future<SecureKeyVault> open([FlutterSecureStorage storage = const FlutterSecureStorage()]) async {
    try {
      final stored = await storage.read(key: _name);
      if (stored != null) {
        final k = base64.decode(stored);
        if (k.length == 32) return SecureKeyVault._(Uint8List.fromList(k));
      }
      final fresh = randomBytes(32);
      await storage.write(key: _name, value: base64.encode(fresh));
      return SecureKeyVault._(fresh);
    } catch (e) {
      // Jangan menimpa kunci lama kalau Keystore bermasalah: catatan terkunci tetap utuh
      // (tidak terbaca) dan tidak ada kunci baru yang membuat data lama hilang.
      debugPrint('Razarsa: penyimpanan aman tidak tersedia: $e');
      return SecureKeyVault._(null);
    }
  }
}
