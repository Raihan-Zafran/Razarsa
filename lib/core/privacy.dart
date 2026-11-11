import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mencegah tangkapan layar dan pratinjau di daftar aplikasi terbaru (Android FLAG_SECURE).
class Privacy {
  static const _channel = MethodChannel('razarsa/privacy');
  static bool? _last;

  static Future<void> setSecure(bool on) async {
    if (_last == on) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'on': on});
      _last = on;
    } on MissingPluginException {
      // Platform tanpa dukungan (tes, web): abaikan.
    } catch (e) {
      debugPrint('Razarsa: gagal mengatur layar aman: $e');
    }
  }
}
