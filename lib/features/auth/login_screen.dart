import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/store.dart';
import '../../widgets/common.dart';
import 'characters.dart';

enum _View { welcome, login, register }

/// Halaman Masuk / Daftar dengan empat karakter kawaii.
/// Catatan: versi 1 belum punya server, jadi akun disimpan di HP saja.
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
  final _nameF = FocusNode();
  final _emailF = FocusNode();
  final _pwF = FocusNode();
  bool _showPw = false;
  String _msg = '';
  bool _msgOk = false;
  bool _busy = false;
  Timer? _greetT, _blinkT, _moodT;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    for (final f in [_nameF, _emailF, _pwF]) {
      f.addListener(_syncFocus);
    }
    for (final c in [_name, _email, _pw]) {
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
    for (final x in [_name, _email, _pw]) {
      x.dispose();
    }
    for (final x in [_nameF, _emailF, _pwF]) {
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
    final reg = _view == _View.register;
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
      row = reg ? 1 : 0;
    } else if (_pwF.hasFocus) {
      focus = 'pw';
      ctrl = _pw;
      row = reg ? 2 : 1;
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
      _rig.mood = 'none';
      _rig.focus = 'none';
      _rig.target = const Offset(195, 420);
      _rig.welcome = v == _View.welcome;
    });
    if (v == _View.welcome) _greet();
  }

  void _submit(AppStore store) {
    if (_busy) return;
    final reg = _view == _View.register;
    final email = _email.text.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) &&
        _pw.text.length >= 8 &&
        (!reg || _name.text.trim().isNotEmpty);
    FocusScope.of(context).unfocus();
    setState(() {
      _rig.mood = ok ? 'yay' : 'sad';
      _rig.focus = 'none';
      _msgOk = ok;
      _msg = ok
          ? (reg ? 'Akun berhasil dibuat!' : 'Berhasil masuk!')
          : (reg ? 'Lengkapi nama, email yang benar, dan sandi minimal 8 karakter.' : 'Email atau kata sandi belum benar.');
      _busy = ok;
    });
    _moodT?.cancel();
    _moodT = Timer(Duration(milliseconds: ok ? 1500 : 1500), () {
      if (!mounted) return;
      setState(() => _rig.mood = 'none');
      if (ok) store.login(name: reg ? _name.text : null, mail: email);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = _LoginColors(dark);
    final grey = _view == _View.register && !(_msgOk && _busy);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        color: grey ? c.bgGrey : c.bg,
        child: SafeArea(
          child: Listener(
            onPointerDown: (e) {
              if (_rig.focus == 'none' && _view == _View.welcome && !_rig.greeting) _greet();
            },
            child: Center(
              child: FittedBox(
                child: SizedBox(
                  width: 390,
                  height: 844,
                  child: Stack(children: [
                    // Logo
                    Positioned(
                      top: 44,
                      left: 0,
                      right: 0,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const StarLogo(size: 34),
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
      ),
    );
  }

  Widget _welcome(_LoginColors c, AppStore store) {
    return Stack(children: [
      Positioned(
        left: 24,
        right: 24,
        top: 516,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PillButton(label: 'MASUK DENGAN EMAIL', icon: Icons.mail_outline_rounded, bg: c.priBg, fg: c.priFg, onTap: () => _go(_View.login)),
          const SizedBox(height: 14),
          _PillButton(
            label: 'MASUK DENGAN GOOGLE',
            icon: Icons.account_circle_outlined,
            bg: Colors.transparent,
            fg: c.ink,
            border: c.ink,
            onTap: () => showZToast(context, 'Masuk dengan Google segera hadir'),
          ),
          const SizedBox(height: 20),
          _LinkLine(text: 'Belum punya akun? ', link: 'Daftar', c: c, onTap: () => _go(_View.register)),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => store.login(),
              child: Text('Lanjut tanpa akun',
                  style: TextStyle(color: c.muted, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: c.muted)),
            ),
          ),
        ]),
      ),
      Positioned(
        left: 40,
        right: 40,
        bottom: 36,
        child: Text.rich(
          TextSpan(style: TextStyle(fontSize: 12, height: 1.5, color: c.muted), children: [
            const TextSpan(text: 'Dengan melanjutkan, kamu menyetujui\n'),
            TextSpan(text: 'Ketentuan', style: TextStyle(fontWeight: FontWeight.w800, color: c.ink)),
            const TextSpan(text: ' & '),
            TextSpan(text: 'Kebijakan Privasi', style: TextStyle(fontWeight: FontWeight.w800, color: c.ink)),
          ]),
          textAlign: TextAlign.center,
        ),
      ),
    ]);
  }

  Widget _form(_LoginColors c, AppStore store) {
    final reg = _view == _View.register;
    return Stack(children: [
      Positioned(
        left: 8,
        top: 42,
        child: IconButton(
          onPressed: () => _go(_View.welcome),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.ink),
          tooltip: 'Kembali',
        ),
      ),
      Positioned(
        top: 98,
        left: 0,
        right: 0,
        child: Text(reg ? 'Daftar ke Razarsa :)' : 'Masuk ke Razarsa :)',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: c.ink)),
      ),
      Positioned(
        left: 24,
        right: 24,
        top: _fieldsTop,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (reg) ...[
            _Field(controller: _name, focus: _nameF, hint: 'Nama panggilan', icon: Icons.person_outline_rounded, c: c),
            const SizedBox(height: 14),
          ],
          _Field(
            controller: _email,
            focus: _emailF,
            hint: 'nama@email.com',
            icon: Icons.mail_outline_rounded,
            c: c,
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _Field(
            controller: _pw,
            focus: _pwF,
            hint: 'Kata sandi (min. 8 karakter)',
            icon: Icons.key_outlined,
            c: c,
            obscure: !_showPw,
            suffix: IconButton(
              tooltip: _showPw ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi',
              icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: c.muted, size: 20),
              onPressed: () => setState(() {
                _showPw = !_showPw;
                _rig.showPw = _showPw;
              }),
            ),
            onSubmit: () => _submit(store),
          ),
          const SizedBox(height: 14),
          _PillButton(label: reg ? 'DAFTAR DENGAN EMAIL' : 'MASUK DENGAN EMAIL', bg: c.priBg, fg: c.priFg, onTap: () => _submit(store)),
          if (_msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _msgOk ? c.ok : c.err)),
            ),
          const SizedBox(height: 14),
          if (!reg) ...[
            _LinkLine(text: 'Lupa kata sandi? ', link: 'Klik di sini', c: c, onTap: () => showZToast(context, 'Fitur ini segera hadir')),
            const SizedBox(height: 10),
            _LinkLine(text: 'Belum punya akun? ', link: 'Daftar', c: c, onTap: () => _go(_View.register)),
          ] else
            _LinkLine(text: 'Sudah punya akun? ', link: 'Masuk', c: c, onTap: () => _go(_View.login)),
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

class _LinkLine extends StatelessWidget {
  const _LinkLine({required this.text, required this.link, required this.c, required this.onTap});

  final String text, link;
  final _LoginColors c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(text, style: TextStyle(fontSize: 14, color: c.muted)),
      GestureDetector(
        onTap: onTap,
        child: Text(link,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.accent, decoration: TextDecoration.underline, decorationColor: c.accent)),
      ),
    ]);
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
          borderRadius: BorderRadius.circular(26),
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
