import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../data/store.dart';
import '../../widgets/common.dart';
import 'characters.dart';
import '../../core/i18n.dart';

enum _View { welcome, form }

/// Layar awal "Mulai pakai" dengan empat karakter kawaii: membuat profil LOKAL (nama, email opsional)
/// dan, kalau mau, PIN. Tidak ada akun online dan tidak ada kata sandi akun: data hanya ada di HP ini,
/// dan PIN adalah satu-satunya kunci aplikasi.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  _View _view = _View.welcome;
  final _rig = CharacterRig();
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _nameF = FocusNode();
  final _emailF = FocusNode();
  final _pwF = FocusNode();
  final _pw2F = FocusNode();
  bool _showPw = false;
  String _msg = '';
  bool _msgOk = false;
  bool _busy = false;
  Timer? _greetT, _blinkT, _moodT;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    for (final f in [_nameF, _emailF, _pwF, _pw2F]) {
      f.addListener(_syncFocus);
    }
    for (final c in [_name, _email, _pw, _pw2]) {
      c.addListener(_syncFocus);
    }
    _greet();
    _blinkT = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      _rig.blink = math.Random().nextInt(4);
      Future.delayed(const Duration(milliseconds: 150), () => _rig.blink = -1);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _greetT?.cancel();
    _blinkT?.cancel();
    _moodT?.cancel();
    for (final x in [_name, _email, _pw, _pw2]) {
      x.dispose();
    }
    for (final x in [_nameF, _emailF, _pwF, _pw2F]) {
      x.dispose();
    }
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _rig.step(elapsed.inMicroseconds / 1e6, dt);
    setState(() {});
  }

  void _greet() {
    _rig.greeting = true;
    _greetT?.cancel();
    _greetT = Timer(const Duration(milliseconds: 3200), () => _rig.greeting = false);
  }

  // Posisi kolom isian dalam kanvas 390 x 844.
  double get _fieldsTop => 372;
  double _rowY(int i) => _fieldsTop + 26 + i * 66;

  void _syncFocus() {
    String focus = 'none';
    TextEditingController? ctrl;
    var row = 0;
    if (_nameF.hasFocus) {
      focus = 'name';
      ctrl = _name;
      row = 0;
    } else if (_emailF.hasFocus) {
      focus = 'email';
      ctrl = _email;
      row = 1;
    } else if (_pwF.hasFocus) {
      focus = 'pw'; // karakter menutup mata saat PIN diketik
      ctrl = _pw;
      row = 2;
    } else if (_pw2F.hasFocus) {
      focus = 'pw';
      ctrl = _pw2;
      row = 3;
    }
    _rig.focus = focus;
    _rig.showPw = _showPw;
    if (ctrl != null) {
      final len = ctrl.selection.baseOffset < 0 ? ctrl.text.length : ctrl.selection.baseOffset;
      _rig.target = Offset(math.min(24 + 50 + len * 8.4, 340), _rowY(row));
    }
  }

  void _go(_View v) {
    FocusScope.of(context).unfocus();
    setState(() {
      _view = v;
      _msg = '';
      _showPw = false;
      _name.clear();
      _email.clear();
      _pw.clear();
      _pw2.clear();
      _rig.mood = 'none';
      _rig.focus = 'none';
      _rig.target = const Offset(195, 420);
      _rig.welcome = v == _View.welcome;
    });
    if (v == _View.welcome) _greet();
  }

  /// Hasil pemeriksaan isian profil: null = valid, selain itu pesan kesalahan.
  String? _validate() {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) return tr('Isi nama panggilanmu dulu.');
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return tr('Email belum benar (boleh dikosongkan).');
    }
    if (_pw.text.isNotEmpty || _pw2.text.isNotEmpty) {
      if (!RegExp(r'^\d{6}$').hasMatch(_pw.text)) return tr('PIN harus 6 angka.');
      if (_pw.text != _pw2.text) return tr('PIN dan ulangannya belum sama.');
    }
    return null;
  }

  void _submit(AppStore store) {
    if (_busy) return;
    final error = _validate();
    final ok = error == null;
    final name = _name.text.trim().length > 30 ? _name.text.trim().substring(0, 30) : _name.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _rig.mood = ok ? 'yay' : 'sad';
      _rig.focus = 'none';
      _msgOk = ok;
      _msg = ok ? trf('Selamat datang, {0}!', [name]) : error;
      _busy = ok;
    });
    _moodT?.cancel();
    _moodT = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _rig.mood = 'none');
      if (ok) {
        // PIN dipasang dulu: begitu masuk, sesi ini sudah terbuka (tidak diminta PIN yang baru dibuat).
        if (_pw.text.isNotEmpty) store.setPin(_pw.text);
        store.login(name: name, mail: _email.text.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = _LoginColors(dark);
    final grey = _view == _View.form && !(_msgOk && _busy);
    // Dibaca di sini (di atas Scaffold): Scaffold menghapus inset keyboard dari MediaQuery untuk isinya.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      // Tata letak keyboard diatur sendiri (lihat _fitCanvas): kanvas tidak boleh ikut mengecil.
      resizeToAvoidBottomInset: false,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        color: grey ? c.bgGrey : c.bg,
        child: SafeArea(
          child: Listener(
            onPointerDown: (e) {
              if (_rig.focus == 'none' && _view == _View.welcome && !_rig.greeting) _greet();
            },
            child: _fitCanvas(
              inset: keyboard,
              canvas: SizedBox(
                key: const ValueKey('login-canvas'),
                width: 390,
                height: 844,
                child: Stack(children: [
                    // Logo
                    Positioned(
                      top: 44,
                      left: 0,
                      right: 0,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const AppLogo(size: 42),
                        const SizedBox(width: 8),
                        Text('razarsa', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1.1, color: c.ink)),
                      ]),
                    ),
                    // Karakter
                    Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: CharacterPainter(_rig)))),
                    // Isi halaman
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_view),
                          child: _view == _View.welcome ? _welcome(c, store) : _form(c, store),
                        ),
                      ),
                    ),
                  ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Menempatkan kanvas 390x844. Tanpa keyboard: seluruh kanvas muat di layar (seperti semula).
  /// Keyboard terbuka: hanya bagian isian + tombol yang ditampilkan, tetap berukuran hampir normal
  /// dan berada di atas keyboard (sebelumnya seluruh kanvas ikut mengecil jadi sangat kecil).
  Widget _fitCanvas({required Widget canvas, required double inset}) {
    return LayoutBuilder(builder: (context, bc) {
      final w = bc.maxWidth, h = bc.maxHeight;
      // Bagian kanvas yang harus terlihat saat mengetik (daftar punya satu isian lebih banyak).
      // Karakter (y≈135–320) ikut terlihat selama skalanya masih nyaman; di layar sangat pendek
      // hanya bagian bawah karakter yang menyembul di atas isian, lalu hanya isian.
      const bottom = 740.0;
      final avail = math.max(h - inset, 160.0);
      final sFull = math.min(w / 390, h / 844);
      var top = 340.0;
      var sKb = math.min(w / 390, avail / (bottom - top));
      for (final cand in const [125.0, 290.0]) {
        final sc = math.min(w / 390, avail / (bottom - cand));
        if (sc >= 0.72) {
          top = cand;
          sKb = sc;
          break;
        }
      }
      return TweenAnimationBuilder<double>(
        tween: Tween(end: inset > 0 ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        builder: (context, t, _) {
          final s = sFull + (sKb - sFull) * t;
          final dx = (w - 390 * s) / 2;
          final dyFull = (h - 844 * sFull) / 2;
          final dyKb = -top * sKb + (avail - (bottom - top) * sKb) / 2;
          final dy = dyFull + (dyKb - dyFull) * t;
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(dx, dy, 0, 1)
                  ..scaleByDouble(s, s, 1, 1),
                child: canvas,
              ),
            ),
          );
        },
      );
    });
  }

  Widget _welcome(_LoginColors c, AppStore store) {
    return Stack(children: [
      Positioned(
        left: 24,
        right: 24,
        top: 516,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PillButton(label: tr('BUAT PROFIL'), icon: Icons.person_add_alt_1_rounded, bg: c.priBg, fg: c.priFg, onTap: () => _go(_View.form)),
          const SizedBox(height: 14),
          _PillButton(
            label: tr('LEWATI DULU'),
            icon: Icons.arrow_forward_rounded,
            bg: Colors.transparent,
            fg: c.ink,
            border: c.ink,
            onTap: () => store.login(),
          ),
          const SizedBox(height: 18),
          Text(
            tr('Datamu hanya tersimpan di HP ini. Tidak ada akun online.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.45, color: c.muted),
          ),
        ]),
      ),
      Positioned(
        left: 40,
        right: 40,
        bottom: 36,
        child: Text.rich(
          TextSpan(style: TextStyle(fontSize: 12, height: 1.5, color: c.muted), children: [
            TextSpan(text: tr('Dengan melanjutkan, kamu menyetujui\n')),
            TextSpan(text: tr('Ketentuan'), style: TextStyle(fontWeight: FontWeight.w800, color: c.ink)),
            const TextSpan(text: ' & '),
            TextSpan(text: tr('Kebijakan Privasi'), style: TextStyle(fontWeight: FontWeight.w800, color: c.ink)),
          ]),
          textAlign: TextAlign.center,
        ),
      ),
    ]);
  }

  Widget _form(_LoginColors c, AppStore store) {
    final pinFormatters = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)];
    return Stack(children: [
      Positioned(
        left: 8,
        top: 42,
        child: IconButton(
          onPressed: () => _go(_View.welcome),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.ink),
          tooltip: tr('Kembali'),
        ),
      ),
      Positioned(
        top: 98,
        left: 0,
        right: 0,
        child: Text(tr('Buat profilmu :)'),
            textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: c.ink)),
      ),
      Positioned(
        left: 24,
        right: 24,
        top: _fieldsTop,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Field(controller: _name, focus: _nameF, hint: tr('Nama panggilan'), icon: Icons.person_outline_rounded, c: c),
          const SizedBox(height: 14),
          _Field(
            controller: _email,
            focus: _emailF,
            hint: tr('Email (opsional)'),
            icon: Icons.mail_outline_rounded,
            c: c,
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _Field(
            controller: _pw,
            focus: _pwF,
            hint: tr('PIN 6 angka (disarankan)'),
            icon: Icons.key_outlined,
            c: c,
            obscure: !_showPw,
            keyboard: TextInputType.number,
            formatters: pinFormatters,
            suffix: IconButton(
              tooltip: _showPw ? tr('Sembunyikan PIN') : tr('Tampilkan PIN'),
              icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: c.muted, size: 20),
              onPressed: () => setState(() {
                _showPw = !_showPw;
                _rig.showPw = _showPw;
              }),
            ),
          ),
          const SizedBox(height: 14),
          _Field(
            controller: _pw2,
            focus: _pw2F,
            hint: tr('Ulangi PIN'),
            icon: Icons.key_outlined,
            c: c,
            obscure: !_showPw,
            keyboard: TextInputType.number,
            formatters: pinFormatters,
            onSubmit: () => _submit(store),
          ),
          const SizedBox(height: 14),
          _PillButton(label: tr('MULAI'), bg: c.priBg, fg: c.priFg, onTap: () => _submit(store)),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _msg.isNotEmpty ? _msg : tr('PIN tidak bisa dipulihkan kalau lupa. Kosongkan kalau belum mau dikunci.'),
              textAlign: TextAlign.center,
              style: _msg.isNotEmpty
                  ? TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _msgOk ? c.ok : c.err)
                  : TextStyle(fontSize: 12.5, height: 1.4, color: c.muted),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _LoginColors {
  _LoginColors(bool d)
      : bg = d ? const Color(0xFF0A100D) : const Color(0xFFF4F7F5),
        bgGrey = d ? const Color(0xFF111A15) : const Color(0xFFE3EEE7),
        ink = d ? const Color(0xFFEEF5F0) : const Color(0xFF111827),
        muted = d ? const Color(0xFFA3B4AA) : const Color(0xFF4B5563),
        field = d ? const Color(0xFF1B2721) : Colors.white,
        line = d ? const Color(0xFF2C3E33) : const Color(0xFFD1DDD5),
        focus = d ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
        priBg = d ? const Color(0xFF22C55E) : const Color(0xFF15803D),
        priFg = d ? const Color(0xFF052E16) : Colors.white,
        accent = d ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
        ok = d ? const Color(0xFF7DD3A0) : const Color(0xFF1F7A3A),
        err = d ? const Color(0xFFFF8A80) : const Color(0xFFB3261E);

  final Color bg, bgGrey, ink, muted, field, line, focus, priBg, priFg, accent, ok, err;
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.bg, required this.fg, required this.onTap, this.icon, this.border});

  final String label;
  final IconData? icon;
  final Color bg, fg;
  final Color? border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: StadiumBorder(side: border == null ? BorderSide.none : BorderSide(color: border!, width: 2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: 12)],
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.5)),
          ]),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focus,
    required this.hint,
    required this.icon,
    required this.c,
    this.obscure = false,
    this.suffix,
    this.keyboard,
    this.formatters,
    this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final IconData icon;
  final _LoginColors c;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focus,
      builder: (context, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        padding: EdgeInsets.only(left: 18, right: suffix == null ? 18 : 4),
        decoration: BoxDecoration(
          color: c.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: focus.hasFocus ? c.focus : c.line, width: 2),
        ),
        child: Row(children: [
          Icon(icon, color: c.muted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              obscureText: obscure,
              keyboardType: keyboard,
              inputFormatters: formatters,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => onSubmit?.call(),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.ink),
              cursorColor: c.focus,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: c.muted.withValues(alpha: 0.7)),
              ),
            ),
          ),
          ?suffix,
        ]),
      ),
    );
  }
}
