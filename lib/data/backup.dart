import 'dart:convert';
import 'dart:typed_data';

import '../core/crypto.dart';

enum BackupPasswordProblem { tooShort, weak }

/// Pembungkus backup berkata sandi: seluruh isi backup dienkripsi AES-256-GCM,
/// kuncinya diturunkan dari kata sandi dengan PBKDF2-HMAC-SHA256.
class BackupEnvelope {
  static const kdfIterations = 210000;
  static const _aad = 'razarsa-backup-v2';

  /// Kata sandi minimal sepanjang ini.
  static const minPasswordLength = 8;

  static const _common = {
    '12345678', '123456789', '1234567890', '87654321', 'password', 'password1', 'password123', 'qwertyui',
    'qwertyuiop', 'asdfghjk', 'abcdefgh', 'abcd1234', '11111111', '00000000', 'iloveyou', 'admin123',
    'razarsa1', 'razarsa123', 'rahasia1', 'rahasia123', 'sandi1234', 'katasandi',
  };

  /// Memeriksa kata sandi backup: null kalau layak.
  static BackupPasswordProblem? passwordProblem(String p) {
    if (p.length < minPasswordLength) return BackupPasswordProblem.tooShort;
    if (p.split('').toSet().length < 4) return BackupPasswordProblem.weak; // mis. "aaaaaaaa", "1212121212"
    if (_common.contains(p.toLowerCase())) return BackupPasswordProblem.weak;
    return null;
  }

  static bool isEncrypted(Map<String, dynamic> m) => m['enc'] == 'aes-256-gcm';

  static Future<String> encrypt(String plainJson, String password) async {
    final salt = randomBytes(16);
    final key = await pbkdf2Async(password, salt, kdfIterations);
    return jsonEncode({
      'app': 'razarsa',
      'version': 2,
      'enc': 'aes-256-gcm',
      'kdf': 'pbkdf2-hmac-sha256',
      'iter': kdfIterations,
      'salt': base64.encode(salt),
      'data': aesGcmSeal(key, utf8.encode(plainJson), aad: _aad),
    });
  }

  /// Isi backup, atau null kalau kata sandi salah / file diubah.
  static Future<String?> decrypt(Map<String, dynamic> m, String password) async {
    try {
      final iter = (m['iter'] as num).toInt();
      // Batas atas mencegah file berbahaya membuat HP sibuk berjam-jam.
      if (iter < 10000 || iter > 2000000) return null;
      final salt = base64.decode(m['salt'] as String);
      final key = await pbkdf2Async(password, salt, iter);
      final Uint8List? plain = aesGcmOpen(key, m['data'] as String, aad: _aad);
      return plain == null ? null : utf8.decode(plain);
    } catch (_) {
      return null;
    }
  }
}
