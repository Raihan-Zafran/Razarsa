import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

final _auth = LocalAuthentication();

/// Bisa pakai sidik jari di HP ini?
Future<bool> biometricAvailable() async {
  try {
    return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
  } catch (_) {
    return false;
  }
}

Future<bool> authenticateBiometric() async {
  try {
    return await _auth.authenticate(localizedReason: tr('Buka Razarsa'), biometricOnly: true);
  } catch (_) {
    return false;
  }
}

/// Mengunci aplikasi dengan PIN saat dibuka / kembali dari latar belakang (lebih dari 30 detik).
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late bool _unlocked = StoreScope.read(context).sessionUnlocked;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (state == AppLifecycleState.resumed && _pausedAt != null) {
      if (DateTime.now().difference(_pausedAt!).inSeconds > 30) setState(() => _unlocked = false);
      _pausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    // Tanpa PIN, sesi dianggap terbuka: PIN yang baru dibuat tidak langsung diminta lagi.
    if (!store.pinEnabled) _unlocked = true;
    if (_unlocked) return widget.child;
    return PinPad(
      title: tr('Masukkan PIN'),
      length: store.pinLength,
      lockRemaining: () => store.pinLockRemaining,
      useBiometric: store.switches['bio'] == true,
      onPin: (pin) {
        final ok = store.checkPin(pin);
        if (ok) setState(() => _unlocked = true);
        return ok;
      },
      onBiometricOk: () => setState(() => _unlocked = true),
    );
  }
}

/// Layar buat PIN baru (masukkan 2 kali). Mengembalikan PIN atau null.
class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  String? _first;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return PinPad(
      key: ValueKey(_first),
      length: AppStore.pinNewLength,
      title: _first == null ? tr('Buat PIN') : tr('Ulangi PIN'),
      error: _error,
      onClose: () => Navigator.pop(context),
      onPin: (pin) {
        if (_first == null) {
          setState(() {
            _first = pin;
            _error = null;
          });
          return true;
        }
        if (pin == _first) {
          Navigator.pop(context, pin);
          return true;
        }
        setState(() {
          _first = null;
          _error = tr('PIN tidak cocok, coba lagi');
        });
        return false;
      },
    );
  }
}

/// Layar cek PIN sekali (misalnya sebelum mematikan PIN). Mengembalikan true kalau benar.
class PinVerifyPage extends StatelessWidget {
  const PinVerifyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    return PinPad(
      title: tr('Masukkan PIN'),
      length: store.pinLength,
      lockRemaining: () => store.pinLockRemaining,
      onClose: () => Navigator.pop(context, false),
      onPin: (pin) {
        final ok = store.checkPin(pin);
        if (ok) Navigator.pop(context, true);
        return ok;
      },
    );
  }
}

/// Papan angka PIN (4-6 digit). Setelah terlalu banyak salah, papan dikunci sementara.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onPin,
    this.length = 4,
    this.lockRemaining,
    this.error,
    this.useBiometric = false,
    this.onBiometricOk,
    this.onClose,
  });

  final String title;
  final String? error;

  /// Jumlah digit PIN; papan memeriksa otomatis setelah digit terakhir.
  final int length;

  /// Sisa waktu papan dikunci (null / nol = tidak dikunci).
  final Duration Function()? lockRemaining;

  /// Kembalikan false kalau PIN salah (titik akan bergetar lalu kosong).
  final bool Function(String pin) onPin;
  final bool useBiometric;
  final VoidCallback? onBiometricOk;
  final VoidCallback? onClose;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _wrong;
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  Timer? _ticker;
  Duration _locked = Duration.zero;

  @override
  void initState() {
    super.initState();
    _refreshLock();
    if (widget.useBiometric) WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shake.dispose();
    super.dispose();
  }

  /// Memperbarui status kunci sementara dan menjalankan hitung mundur per detik.
  void _refreshLock() {
    _locked = widget.lockRemaining?.call() ?? Duration.zero;
    _ticker?.cancel();
    if (_locked > Duration.zero) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _locked = widget.lockRemaining?.call() ?? Duration.zero);
        if (_locked <= Duration.zero) _ticker?.cancel();
      });
    }
  }

  String _lockText() {
    final s = _locked.inSeconds + 1;
    final t = s >= 60 ? '${s ~/ 60} ${tr('menit')} ${s % 60} ${tr('detik')}' : '$s ${tr('detik')}';
    return trf('Terlalu banyak percobaan. Coba lagi dalam {0}', [t]);
  }

  Future<void> _bio() async {
    if (await authenticateBiometric()) widget.onBiometricOk?.call();
  }

  void _tap(String d) {
    if (_locked > Duration.zero || _pin.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _wrong = null;
    });
    if (_pin.length == widget.length) {
      final ok = widget.onPin(_pin);
      if (!ok) {
        HapticFeedback.heavyImpact();
        _shake.forward(from: 0);
        setState(() {
          _pin = '';
          _wrong = widget.error == null ? tr('PIN salah') : null;
        });
        setState(_refreshLock);
      } else {
        setState(() => _pin = '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final msg = _locked > Duration.zero ? _lockText() : (_wrong ?? widget.error);
    Widget key(String d) => _Key(label: d, onTap: () => _tap(d));
    return Scaffold(
      backgroundColor: z.bg,
      body: SafeArea(
        // Bisa digulir supaya semua tombol tetap terjangkau di layar pendek, mode landscape, atau font besar.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(child: Column(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: widget.onClose == null
                ? const SizedBox(height: 48)
                : IconButton(onPressed: widget.onClose, icon: Icon(Icons.close_rounded, color: z.text), tooltip: tr('Kembali')),
          ),
          const Spacer(),
          const AppLogo(size: 64),
          const SizedBox(height: 18),
          Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 22),
          AnimatedBuilder(
            animation: _shake,
            builder: (_, child) => Transform.translate(
              offset: Offset(math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value), 0),
              child: child,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < widget.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? z.primary : Colors.transparent,
                    border: Border.all(color: i < _pin.length ? z.primary : z.chipBorder, width: 2),
                  ),
                ),
            ]),
          ),
          SizedBox(
            height: 40,
            child: Center(
              child: Text(msg ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: z.warn)),
            ),
          ),
          const Spacer(),
          for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) key(d)]),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            widget.useBiometric
                ? _Key(icon: Icons.fingerprint_rounded, onTap: _bio, label: tr('Gunakan sidik jari'))
                : const SizedBox(width: 96, height: 76),
            key('0'),
            _Key(
              icon: Icons.backspace_outlined,
              label: tr('Hapus'),
              onTap: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
            ),
          ]),
          const SizedBox(height: 28),
              ])),
            ),
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: icon == null ? z.card : Colors.transparent,
          shape: CircleBorder(side: BorderSide(color: icon == null ? z.cardBorder : Colors.transparent)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 28, color: z.text)
                    : Text(label, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
