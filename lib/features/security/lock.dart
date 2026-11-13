import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../shell/dusk_background.dart';
import '../../shell/sky_background.dart';
import '../../widgets/common.dart';
import '../../widgets/profile_widgets.dart';

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
  late int _lockTick = StoreScope.read(context).lockTick;
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
    // "Kunci sekarang" dari Pengaturan.
    if (store.lockTick != _lockTick) {
      _lockTick = store.lockTick;
      _unlocked = false;
    }
    // Tanpa PIN, sesi dianggap terbuka: PIN yang baru dibuat tidak langsung diminta lagi.
    if (!store.pinEnabled) _unlocked = true;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Widget? scene = store.mode == 'productive'
        ? null
        : (store.financeBg == 'dusk' ? DuskBackground(dark: dark) : SkyBackground(dark: dark));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _unlocked
          ? KeyedSubtree(key: const ValueKey('app'), child: widget.child)
          : PinPad(
              key: const ValueKey('lock'),
              title: tr('Masukkan PIN'),
              length: store.pinLength,
              lockRemaining: () => store.pinLockRemaining,
              triesLeft: () => AppStore.pinFreeTries - store.pinFails,
              useBiometric: store.switches['bio'] == true,
              scene: scene,
              profile: ProfileAvatar(avatarId: store.avatar, frameId: store.effectiveFrame, size: 76),
              greetingText: greeting(),
              nameText: store.userName.isEmpty ? 'Razarsa' : store.userName,
              onForgot: () => _forgot(context),
              onPin: store.checkPin,
              onUnlocked: () => setState(() => _unlocked = true),
              onBiometricOk: () => setState(() => _unlocked = true),
            ),
    );
  }

  void _forgot(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Lupa PIN?')),
        content: Text(tr('PIN hanya tersimpan di HP ini dan tidak bisa dipulihkan. Jalan satu-satunya: hapus data aplikasi lalu pulihkan dari file backup.')),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(tr('Mengerti')))],
      ),
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
      hint: _first == null
          ? tr('Pilih 6 angka yang mudah diingat tapi sulit ditebak. Hindari tanggal lahir.')
          : tr('Masukkan PIN yang sama sekali lagi untuk memastikan.'),
      step: _first == null ? 1 : 2,
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
///
/// Dua tampilan: layar kunci ([profile] diisi: foto profil, sapaan, nama) dan layar buat/cek PIN
/// (ikon, judul, petunjuk, dan penunjuk langkah kalau [step] diisi).
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onPin,
    this.length = 4,
    this.lockRemaining,
    this.triesLeft,
    this.error,
    this.hint,
    this.step,
    this.useBiometric = false,
    this.onBiometricOk,
    this.onClose,
    this.onUnlocked,
    this.onForgot,
    this.scene,
    this.profile,
    this.greetingText,
    this.nameText,
  });

  final String title;
  final String? error;

  /// Petunjuk di bawah judul (layar buat PIN).
  final String? hint;

  /// Penunjuk langkah 1 atau 2 (layar buat PIN).
  final int? step;

  /// Jumlah digit PIN; papan memeriksa otomatis setelah digit terakhir.
  final int length;

  /// Sisa waktu papan dikunci (null / nol = tidak dikunci).
  final Duration Function()? lockRemaining;

  /// Sisa percobaan gratis sebelum papan dikunci; ditampilkan saat tinggal sedikit.
  final int Function()? triesLeft;

  /// Kembalikan false kalau PIN salah (titik memerah dan bergetar, lalu kosong).
  final bool Function(String pin) onPin;
  final bool useBiometric;
  final VoidCallback? onBiometricOk;
  final VoidCallback? onClose;

  /// Kalau diisi: setelah PIN benar, titik berubah hijau sebentar sebelum ini dipanggil.
  final VoidCallback? onUnlocked;
  final VoidCallback? onForgot;

  /// Latar bergerak di belakang papan (layar kunci).
  final Widget? scene;
  final Widget? profile;
  final String? greetingText;
  final String? nameText;

  @override
  State<PinPad> createState() => _PinPadState();
}

enum _PadState { idle, bad, ok }

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _wrong;
  _PadState _state = _PadState.idle;
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  Timer? _ticker;
  Timer? _settle;
  Duration _locked = Duration.zero;

  static const _okColor = Color(0xFF22C55E);
  static const _badColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _refreshLock();
    if (widget.useBiometric) WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _settle?.cancel();
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
    if (await authenticateBiometric()) _success(widget.onBiometricOk);
  }

  /// Titik hijau + "Terbuka", lalu lanjut. Tanpa [PinPad.onUnlocked] langsung lanjut.
  void _success(VoidCallback? next) {
    if (next == null) return;
    setState(() => _state = _PadState.ok);
    HapticFeedback.lightImpact();
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 520), () {
      if (mounted) next();
    });
  }

  void _tap(String d) {
    if (_locked > Duration.zero || _pin.length >= widget.length || _state != _PadState.idle) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _wrong = null;
    });
    if (_pin.length == widget.length) {
      final ok = widget.onPin(_pin);
      if (ok) {
        if (widget.onUnlocked != null) {
          _success(widget.onUnlocked);
        } else {
          setState(() => _pin = '');
        }
        return;
      }
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
      setState(() {
        _state = _PadState.bad;
        _wrong = widget.error == null ? tr('PIN salah') : null;
        _refreshLock();
      });
      _settle?.cancel();
      _settle = Timer(const Duration(milliseconds: 480), () {
        if (!mounted) return;
        setState(() {
          _pin = '';
          _state = _PadState.idle;
        });
      });
    }
  }

  void _back() {
    if (_state != _PadState.idle || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final lockScreen = widget.profile != null;
    final tries = widget.triesLeft?.call();
    final String msg;
    final Color msgColor;
    if (_locked > Duration.zero) {
      msg = _lockText();
      msgColor = _badColor;
    } else if (_state == _PadState.ok) {
      msg = tr('Terbuka');
      msgColor = _okColor;
    } else if (_wrong != null || widget.error != null) {
      msg = _wrong ?? widget.error!;
      msgColor = _badColor;
    } else if (lockScreen && tries != null && tries <= 2 && tries > 0) {
      msg = trf('Sisa {0} percobaan', [tries]);
      msgColor = z.warn;
    } else {
      msg = lockScreen ? widget.title : '';
      msgColor = z.muted;
    }
    Widget key(String d) => _Key(label: d, onTap: () => _tap(d));
    final dotColor = _state == _PadState.ok ? _okColor : (_state == _PadState.bad ? _badColor : z.primary);

    final column = Column(children: [
      Align(
        alignment: Alignment.centerLeft,
        child: widget.onClose == null
            ? const SizedBox(height: 48)
            : IconButton(onPressed: widget.onClose, icon: Icon(Icons.close_rounded, color: z.text), tooltip: tr('Kembali')),
      ),
      const Spacer(),
      if (lockScreen) ...[
        Stack(clipBehavior: Clip.none, children: [
          widget.profile!,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: z.primary, border: Border.all(color: z.bg, width: 3)),
              child: Icon(_state == _PadState.ok ? Icons.lock_open_rounded : Icons.lock_rounded, size: 14, color: z.onPrimary),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Text(widget.greetingText ?? '', style: TextStyle(fontSize: 14, color: z.muted)),
        const SizedBox(height: 2),
        Text(widget.nameText ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      ] else ...[
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(shape: BoxShape.circle, color: z.toneBg('blue')),
          child: Icon(widget.step == 2 ? Icons.verified_user_rounded : Icons.lock_rounded, size: 32, color: z.toneFg('blue')),
        ),
        if (widget.step != null) ...[
          const SizedBox(height: 14),
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (final i in [1, 2])
              Container(
                width: 22,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), color: i <= widget.step! ? z.primary : z.track),
              ),
          ]),
        ],
        const SizedBox(height: 14),
        Text(widget.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        if (widget.hint != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(widget.hint!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: z.muted, height: 1.4)),
          ),
        ],
      ],
      const SizedBox(height: 26),
      AnimatedBuilder(
        animation: _shake,
        builder: (_, child) => Transform.translate(
          offset: Offset(math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value), 0),
          child: child,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < widget.length; i++) _Dot(filled: i < _pin.length, color: dotColor, empty: z.chipBorder),
        ]),
      ),
      SizedBox(
        height: 40,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(msg,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: msgColor)),
          ),
        ),
      ),
      const Spacer(),
      for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) key(d)]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        widget.useBiometric
            ? _Key(icon: Icons.fingerprint_rounded, onTap: _bio, label: tr('Gunakan sidik jari'))
            : const SizedBox(width: 96, height: 84),
        key('0'),
        _Key(icon: Icons.backspace_outlined, label: tr('Hapus'), onTap: _back),
      ]),
      if (widget.onForgot != null)
        TextButton(
          onPressed: widget.onForgot,
          child: Text(tr('Lupa PIN?'), style: TextStyle(fontWeight: FontWeight.w700, color: z.accentText)),
        )
      else
        const SizedBox(height: 28),
    ]);

    return Scaffold(
      backgroundColor: z.bg,
      body: Stack(children: [
        if (widget.scene != null) Positioned(top: 0, left: 0, right: 0, child: widget.scene!),
        // Lapisan buram menutupi latar di belakang papan supaya angka tetap terbaca.
        if (widget.scene != null)
          Positioned.fill(child: ColoredBox(color: z.bg.withValues(alpha: 0.55))),
        SafeArea(
          // Bisa digulir supaya semua tombol tetap terjangkau di layar pendek, mode landscape, atau font besar.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(child: column),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Satu titik PIN: membesar sebentar saat terisi (kecuali "kurangi animasi").
class _Dot extends StatelessWidget {
  const _Dot({required this.filled, required this.color, required this.empty});

  final bool filled;
  final Color color;
  final Color empty;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: filled ? color : empty, width: 2),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: filled && !reduce
          ? TweenAnimationBuilder<double>(
              key: const ValueKey('pop'),
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: dot,
            )
          : dot,
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
        child: ExcludeSemantics(
          child: icon != null
              ? Material(
                  type: MaterialType.transparency,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap,
                    child: SizedBox(width: 72, height: 72, child: Center(child: Icon(icon, size: 28, color: z.text))),
                  ),
                )
              : GlassPane(
                  color: z.card,
                  circle: true,
                  border: Border.all(color: z.cardBorder),
                  child: Material(
                    type: MaterialType.transparency,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onTap,
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: Center(child: Text(label, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700))),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
