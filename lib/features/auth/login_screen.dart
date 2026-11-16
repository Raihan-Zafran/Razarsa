import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../shell/layout.dart';
import '../../widgets/common.dart';
import '../../widgets/shape_art.dart';

enum _View { welcome, form }

/// Layar awal "Mulai pakai": membuat profil LOKAL (nama, email opsional) dan, kalau mau, PIN.
/// Tidak ada akun online dan tidak ada kata sandi akun: data hanya ada di HP ini,
/// dan PIN adalah satu-satunya kunci aplikasi. Ilustrasinya dari bentuk saja dan mengikuti tema.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _View _view = _View.welcome;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _showPw = false;
  String _msg = '';
  bool _msgOk = false;
  bool _busy = false;
  Timer? _doneT;

  @override
  void dispose() {
    _doneT?.cancel();
    for (final x in [_name, _email, _pw, _pw2]) {
      x.dispose();
    }
    super.dispose();
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
    });
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
      _msgOk = ok;
      _msg = ok ? trf('Selamat datang, {0}!', [name]) : error;
      _busy = ok;
    });
    if (!ok) return;
    _doneT?.cancel();
    _doneT = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      // PIN dipasang dulu: begitu masuk, sesi ini sudah terbuka (tidak diminta PIN yang baru dibuat).
      if (_pw.text.isNotEmpty) store.setPin(_pw.text);
      store.login(name: name, mail: _email.text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final z = ZColors.of(context);
    final wide = isWide(context);
    final switcher = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a), child: child),
      ),
      child: KeyedSubtree(
        key: ValueKey(_view),
        child: _view == _View.welcome ? _welcome(z, store, wide: wide) : _form(z, store),
      ),
    );
    // Jendela lebar (Windows): panel kiri berwarna utama berisi ilustrasi, panel kanan berisi isi.
    if (wide) {
      return Scaffold(
        backgroundColor: z.bg,
        body: Row(children: [
          Expanded(flex: 11, child: _artPanel(z)),
          Expanded(
            flex: 10,
            child: Stack(children: [
              Positioned(right: -70, top: -70, child: _Disc(250, const Color(0xFFE8C86A), 0.28)),
              Positioned(left: -70, bottom: -70, child: _Disc(220, z.primary, 0.07)),
              Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: SafeArea(child: switcher))),
            ]),
          ),
        ]),
      );
    }
    return Scaffold(
      backgroundColor: z.bg,
      body: Stack(children: [
        // Bentuk-bentuk dekoratif: lingkaran emas di kanan atas, lingkaran tema di kiri bawah.
        Positioned(right: -70, top: -70, child: _Disc(230, const Color(0xFFE8C86A), 0.3)),
        Positioned(left: -80, bottom: -80, child: _Disc(240, z.primary, 0.07)),
        Positioned(right: 46, top: 112, child: _Disc(16, z.primary, 1)),
        Positioned(left: 34, bottom: 210, child: _Disc(12, const Color(0xFF7FD6DE), 1)),
        SafeArea(child: switcher),
      ]),
    );
  }

  /// Panel ilustrasi untuk jendela lebar.
  Widget _artPanel(ZColors z) {
    return Container(
      color: z.primary,
      child: Stack(children: [
        Positioned(left: -120, top: -120, child: _Disc(320, const Color(0xFFE8C86A), 0.16)),
        Positioned(right: -90, bottom: -110, child: _Disc(300, z.onPrimary, 0.06)),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const AppLogo(size: 54),
              const SizedBox(width: 12),
              Text('razarsa', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.4, color: z.onPrimary)),
            ]),
            const SizedBox(height: 18),
            HeroArt(width: 420, color: z.onPrimary),
            const SizedBox(height: 14),
            SizedBox(
              width: 380,
              child: Text(tr('Catat uang dan kegiatanmu dalam satu aplikasi. Datamu tidak keluar dari komputer ini.'),
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.55, color: z.onPrimary.withValues(alpha: 0.82))),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _welcome(ZColors z, AppStore store, {bool wide = false}) {
    return LayoutBuilder(builder: (context, bc) {
      final art = math.min(360.0, bc.maxWidth - 30);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bc.maxHeight - 42),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!wide) ...[
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const AppLogo(size: 38),
                const SizedBox(width: 8),
                Text('razarsa', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.9, color: z.text)),
              ]),
              const SizedBox(height: 6),
              Center(child: HeroArt(width: art)),
              const SizedBox(height: 4),
            ],
            Text(tr('Catat uang dan kegiatanmu,\nsantai aja.'),
                style: TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -1, color: z.text)),
            const SizedBox(height: 10),
            Text(tr('Uang, tugas, dan jadwal dalam satu aplikasi. Datamu tetap di HP ini.'),
                style: TextStyle(fontSize: 14.5, height: 1.45, color: z.muted)),
            const SizedBox(height: 22),
            _Btn(label: tr('Buat profil'), bg: z.primary, fg: z.onPrimary, onTap: () => _go(_View.form)),
            const SizedBox(height: 10),
            _Btn(label: tr('Lewati dulu'), bg: Colors.transparent, fg: z.accentText, border: z.primary, onTap: () => store.login()),
            const SizedBox(height: 16),
            Text(tr('Datamu hanya tersimpan di HP ini. Tidak ada akun online.'),
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, height: 1.45, color: z.muted2)),
          ]),
        ),
      );
    });
  }

  Widget _form(ZColors z, AppStore store) {
    final pinFormatters = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)];
    return Stack(children: [
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: ListenableBuilder(
              listenable: _name,
              builder: (context, _) {
                final n = _name.text.trim();
                return ShapeEmblem(size: 104, child: Text(n.isEmpty ? '?' : String.fromCharCodes(n.runes.take(1)).toUpperCase()));
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(tr('Siap mulai?'),
              textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.9, color: z.text)),
          const SizedBox(height: 4),
          Text(tr('Cukup nama panggilan. Sisanya boleh dikosongkan.'),
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: z.muted)),
          const SizedBox(height: 20),
          _Field(controller: _name, hint: tr('Nama panggilan'), icon: Icons.person_outline_rounded, z: z),
          const SizedBox(height: 11),
          _Field(controller: _email, hint: tr('Email (opsional)'), icon: Icons.mail_outline_rounded, z: z, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 11),
          _Field(
            controller: _pw,
            hint: tr('PIN 6 angka (disarankan)'),
            icon: Icons.key_outlined,
            z: z,
            obscure: !_showPw,
            keyboard: TextInputType.number,
            formatters: pinFormatters,
            suffix: IconButton(
              tooltip: _showPw ? tr('Sembunyikan PIN') : tr('Tampilkan PIN'),
              icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: z.muted2, size: 20),
              onPressed: () => setState(() => _showPw = !_showPw),
            ),
          ),
          const SizedBox(height: 11),
          _Field(
            controller: _pw2,
            hint: tr('Ulangi PIN'),
            icon: Icons.key_outlined,
            z: z,
            obscure: !_showPw,
            keyboard: TextInputType.number,
            formatters: pinFormatters,
            action: TextInputAction.done,
            onSubmit: () => _submit(store),
          ),
          const SizedBox(height: 20),
          _Btn(label: tr('Ayo mulai!'), bg: z.primary, fg: z.onPrimary, onTap: () => _submit(store)),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _msg.isNotEmpty ? _msg : tr('PIN tidak bisa dipulihkan kalau lupa. Kosongkan kalau belum mau dikunci.'),
              textAlign: TextAlign.center,
              style: _msg.isNotEmpty
                  ? TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _msgOk ? z.pos : z.warn)
                  : TextStyle(fontSize: 12.5, height: 1.4, color: z.muted2),
            ),
          ),
        ]),
      ),
      Positioned(
        left: 8,
        top: 4,
        child: IconButton(
          onPressed: () => _go(_View.welcome),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: z.text),
          tooltip: tr('Kembali'),
        ),
      ),
    ]);
  }
}

class _Disc extends StatelessWidget {
  const _Disc(this.size, this.color, this.alpha);

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: alpha))));
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.bg, required this.fg, required this.onTap, this.border});

  final String label;
  final Color bg, fg;
  final Color? border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: border == null ? BorderSide.none : BorderSide(color: border!, width: 2),
    );
    return Material(
      color: bg,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 15))),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.z,
    this.obscure = false,
    this.suffix,
    this.keyboard,
    this.formatters,
    this.onSubmit,
    this.action = TextInputAction.next,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ZColors z;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final VoidCallback? onSubmit;
  final TextInputAction action;

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 50,
          padding: EdgeInsets.only(left: 16, right: suffix == null ? 16 : 4),
          decoration: BoxDecoration(
            color: z.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: focused ? z.primary : z.border, width: 1.5),
          ),
          child: Row(children: [
            Icon(icon, color: z.muted2, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                keyboardType: keyboard,
                inputFormatters: formatters,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: action,
                scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 56),
                onSubmitted: (_) => onSubmit?.call(),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: z.text),
                cursorColor: z.primary,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: TextStyle(color: z.muted2),
                ),
              ),
            ),
            ?suffix,
          ]),
        );
      }),
    );
  }
}
