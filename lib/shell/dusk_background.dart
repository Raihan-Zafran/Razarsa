import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Latar "Gurun Senja": mesa, kaktus, dan langit senja (siang) atau malam berbintang dengan aurora.
/// Lima halaman, tiap halaman punya benda bergerak sendiri.
///
/// Siang: elang (1), angin dan ranting kering (2), awan debu dan ranting menggelinding (3-4),
/// pusaran debu (4), kadal dan kuda (5). Malam: meteor (1), angin (2), aurora (3), kafilah unta
/// dan api unggun (5).
///
/// Semua koordinat memakai satuan desain 780 x 600 (dua kali lebar 390 px), sama dengan [SkyBackground].
class DuskBackground extends StatefulWidget {
  const DuskBackground({super.key, required this.dark, this.tab = 0});

  final bool dark;
  final int tab;

  static double heightFor(double w) => w / 390 * 300;

  @override
  State<DuskBackground> createState() => _DuskBackgroundState();
}

class _DuskBackgroundState extends State<DuskBackground> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  final _fades = _Fades();
  late final Ticker _ticker;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _fades.snap(widget.tab);
    _ticker = createTicker((e) {
      final t = e.inMicroseconds / 1e6;
      final dt = (t - _time.value).clamp(0.0, 0.1).toDouble();
      _fades.step(widget.tab, dt);
      _time.value = t;
    });
    _DuskImages.warm();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    if (_reduce) {
      if (_ticker.isActive) _ticker.stop();
      _fades.snap(widget.tab);
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant DuskBackground old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab && _reduce) {
      _fades.snap(widget.tab);
      _time.value = _time.value + 1e-6;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final h = DuskBackground.heightFor(w);
        return SizedBox(
          width: w,
          height: h,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0, 0.74, 1],
            ).createShader(r),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              child: RepaintBoundary(
                key: ValueKey(widget.dark),
                child: CustomPaint(
                  size: Size(w, h),
                  painter: _DuskPainter(dark: widget.dark, time: _time, fades: _fades, reduce: _reduce),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Seberapa terlihat efek tiap halaman (0..1), bergerak halus menuju halaman yang sedang dibuka.
class _Fades {
  final v = List<double>.filled(5, 0);

  void snap(int page) {
    for (var i = 0; i < v.length; i++) {
      v[i] = i == page ? 1 : 0;
    }
  }

  void step(int page, double dt) {
    final k = math.min(1.0, dt * 3.2);
    for (var i = 0; i < v.length; i++) {
      v[i] += ((i == page ? 1.0 : 0.0) - v[i]) * k;
    }
  }
}

/// Pemuat gambar: dimuat sekali, dipakai bersama, dan memicu gambar ulang saat selesai.
/// Bintang dan meteor memakai berkas yang sama dengan latar Langit.
class _DuskImages {
  static const _own = [
    'skyD', 'skyN', 'mD', 'mN', 'fLD', 'fCD', 'fRD', 'fLN', 'fCN', 'fRN', 'eagle', 'tw', 'dw0', 'dw1', 'dw2', 'dw3',
    'dn0', 'dn1', 'dn2', 'dn3', 'aur0', 'aur1', 'liz', 'horse', 'cara', 'devil', 'fire',
  ];
  static const _shared = ['st', 'met0', 'met1'];

  static final rev = ValueNotifier<int>(0);
  static final _imgs = <String, ui.Image>{};
  static bool _warmed = false;

  static ui.Image? get(String n) => _imgs[n];

  static void warm() {
    if (_warmed) return;
    _warmed = true;
    void load(String key, String path) {
      final stream = AssetImage(path).resolve(ImageConfiguration.empty);
      late ImageStreamListener l;
      l = ImageStreamListener((info, _) {
        _imgs[key] = info.image.clone();
        rev.value++;
        stream.removeListener(l);
      }, onError: (_, _) {
        _warmed = false; // coba lagi pada pemanggilan berikutnya
        stream.removeListener(l);
      });
      stream.addListener(l);
    }

    for (final n in _own) {
      load(n, 'assets/dusk/$n.webp');
    }
    for (final n in _shared) {
      load(n, 'assets/sky/$n.webp');
    }
  }
}

class _DuskPainter extends CustomPainter {
  _DuskPainter({required this.dark, required this.time, required this.fades, required this.reduce})
      : super(repaint: Listenable.merge([time, _DuskImages.rev]));

  final bool dark;
  final ValueNotifier<double> time;
  final _Fades fades;
  final bool reduce;

  String get _th => dark ? 'N' : 'D';

  /// Dasar tanah (satuan desain); tanah baru terlihat penuh di Pengaturan.
  static const _gy = 322.0;

  // ---------- alat gambar ----------
  void _put(Canvas c, String n, Rect dst, {Rect? src, double a = 1, bool add = false}) {
    final im = _DuskImages.get(n);
    if (im == null || a <= 0) return;
    final p = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, a.clamp(0.0, 1.0));
    if (add) p.blendMode = BlendMode.plus;
    c.drawImageRect(im, src ?? Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), dst, p);
  }

  static double _w(String n) => _DuskImages.get(n)?.width.toDouble() ?? 1;
  static double _h(String n) => _DuskImages.get(n)?.height.toDouble() ?? 1;
  static bool _ok(String n) => _DuskImages.get(n) != null;
  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  void _radial(Canvas c, Offset o, double r0, double r1, Color col, double a) {
    final p = Paint()
      ..shader = ui.Gradient.radial(o, r1, [col.withValues(alpha: a), col.withValues(alpha: 0)], [r0 / r1, 1])
      ..blendMode = BlendMode.plus;
    c.drawCircle(o, r1, p);
  }

  /// 0..1..0 bolak-balik dengan perlambatan di ujung (setara ease-in-out alternate di CSS).
  static double _alt(double t, double period, [double delay = 0]) {
    var k = ((t + delay) / period) % 2;
    if (k < 0) k += 2;
    if (k > 1) k = 2 - k;
    return k * k * (3 - 2 * k);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 780);
    final t = time.value;
    final tt = reduce ? 0.0 : t;
    final f = fades.v;

    _sky(canvas, tt);
    final a0 = math.max(f[0], f[4]), a1 = math.max(f[1], f[4]), a2 = math.max(f[2], f[4]);
    if (dark && a2 > 0.02) _aurora(canvas, tt, _clamp01(a2));
    if (a0 > 0.02) dark ? _meteor(canvas, tt, _clamp01(a0)) : _eagle(canvas, tt, _clamp01(a0));
    if (a1 > 0.02) _wind(canvas, tt, _clamp01(a1));

    // Mesa bergeser pelan (parallax), lalu tanah, lalu benda di depan, dan kaktus di paling depan.
    _mesa(canvas, t);
    canvas.drawRect(
      const Rect.fromLTWH(0, 398, 780, 202),
      Paint()..color = dark ? const Color(0xFF0A0F2C) : const Color(0xFF6B2012),
    );
    dark ? _nightFg(canvas, tt, f) : _dayFg(canvas, tt, f);
    _cacti(canvas, t);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DuskPainter old) => old.dark != dark || old.reduce != reduce;

  // ---------- dasar ----------
  void _sky(Canvas c, double tt) {
    _put(c, 'sky$_th', const Rect.fromLTWH(0, -200, 780, 600));
    if (dark) {
      if (!_ok('st')) return;
      for (var n = 0; n < 16; n++) {
        final row = n % 3, col = (n ~/ 3) % 4;
        final sx = (n * 97.3) % 760 + 10, sy = (n * 61.7) % 300 + 6;
        final a = reduce ? 0.8 : 0.3 + 0.7 * (0.5 + 0.5 * math.sin(tt * (0.8 + 0.2 * (n % 5)) + n * 1.9));
        final sz = [30.0, 22.0, 16.0, 12.0][col] * (row == 2 ? 0.8 : 1);
        _put(c, 'st', Rect.fromLTWH(sx - sz / 2, sy - sz / 2, sz, sz),
            src: Rect.fromLTWH(col * 96.0, row * 96.0, 96, 96), a: a * 0.8, add: true);
      }
    } else {
      final pu = reduce ? 0.0 : 0.5 + 0.5 * math.sin(tt * 0.8);
      _radial(c, const Offset(61, 204), 30, 190, const Color(0xFFFFE29A), 0.16 + 0.1 * pu);
    }
  }

  void _mesa(Canvas c, double t) {
    // Lapisan 780 x 439 di y -39; bergeser +-6 dan membesar 1,03 dari tengahnya (parallax 28 dtk).
    final dx = reduce ? 0.0 : (-6 + 12 * _alt(t, 28));
    c.save();
    c.translate(390, -39 + 219.5);
    c.scale(1.03);
    c.translate(-390 + dx, -219.5);
    _put(c, 'm$_th', const Rect.fromLTWH(0, 0, 780, 439));
    c.restore();
  }

  void _cacti(Canvas c, double t) {
    // Kaktus kiri bergoyang dari pangkalnya; tengah dan kanan diam.
    final deg = reduce ? 0.0 : -1.6 + 3.5 * _alt(t, 3.4);
    c.save();
    c.translate(105, 400);
    c.transform((Matrix4.identity()..setEntry(0, 1, math.tan(deg * math.pi / 180))).storage);
    _put(c, 'fL$_th', const Rect.fromLTWH(-105, -439, 210, 439));
    c.restore();
    _put(c, 'fC$_th', const Rect.fromLTWH(210, -39, 320, 439));
    _put(c, 'fR$_th', const Rect.fromLTWH(530, -39, 250, 439));
  }

  // ---------- belakang mesa ----------
  void _aurora(Canvas c, double tt, double ga) {
    if (!_ok('aur0') || !_ok('aur1')) return;
    const w = 860.0;
    final h = w * _h('aur0') / _w('aur0');
    final cy = -235 + (reduce ? 0.0 : 8 * math.sin(tt * 0.17));
    final m = reduce ? 0.5 : 0.5 + 0.5 * math.sin(tt * 0.3);
    final r = Rect.fromLTWH(-40, cy, w, h);
    _put(c, 'aur0', r, a: ga * 0.6 * (0.35 + 0.65 * (1 - m)), add: true);
    _put(c, 'aur1', r, a: ga * 0.6 * (0.35 + 0.65 * m), add: true);
  }

  void _eagle(Canvas c, double tt, double ga) {
    if (!_ok('eagle')) return;
    const ks = 0.4, period = 26.0;
    final k = reduce ? 0.4 : (tt / period) % 1;
    if (k >= 0.8 && !reduce) return;
    final u = k / 0.8;
    final px = -80 + 960 * u, py = 150 + 26 * math.sin(u * 7) - 50 * u;
    final fi = reduce ? 1 : const [1, 1, 0, 1, 1, 2][(tt * 1.6).floor() % 6];
    _put(c, 'eagle', Rect.fromLTWH(px - 128 * ks, py - 88 * ks, 256 * ks, 176 * ks),
        src: Rect.fromLTWH(fi * 256.0, 0, 256, 176), a: ga);
  }

  void _meteor(Canvas c, double tt, double ga) {
    if (reduce) return;
    const cy = 7.0;
    final n = (tt / cy).floor();
    final u = tt % cy;
    if (u > 1) return;
    final name = 'met${n % 2}';
    if (!_ok(name)) return;
    final right = n % 2 == 0;
    final a = right ? 0.38 : math.pi - 0.38;
    final sx = 120 + (n * 211) % 440, sy = 14 + (n * 37) % 120, d = 430 * u;
    const w = 230.0;
    final h = w * _h(name) / _w(name);
    c.save();
    c.translate(sx + math.cos(a) * d, sy + math.sin(a) * d);
    c.rotate(a);
    _put(c, name, Rect.fromLTWH(-w + 8, -h / 2, w, h), a: math.pow(math.sin(math.pi * u), 0.6).toDouble() * ga, add: true);
    c.restore();
  }

  void _wind(Canvas c, double tt, double ga) {
    const defs = [
      [0, 120.0, 0.62, 7.0, 0.0, 20.0],
      [3, 190.0, 0.5, 8.5, 0.28, 300.0],
      [2, 260.0, 0.74, 9.5, 0.55, 470.0],
      [1, 80.0, 0.42, 6.0, 0.8, 120.0],
    ];
    final pre = dark ? 'dn' : 'dw';
    for (var n = 0; n < defs.length; n++) {
      final d = defs[n];
      final name = '$pre${(d[0] as int)}';
      if (!_ok(name)) continue;
      final iw = _w(name), ih = _h(name);
      final y = d[1] as double, sc = d[2] as double, period = d[3] as double, ph = d[4] as double, bx = d[5] as double;
      final w = iw * sc, h = ih * sc;
      if (reduce) {
        if (n < 2) _put(c, name, Rect.fromLTWH(bx, y, w, h), a: 0.55 * ga, add: dark);
        continue;
      }
      final k = (tt / period + ph) % 1;
      final e = _clamp01(k / 0.5), s0 = _clamp01((k - 0.5) / 0.5);
      final ee = 1 - math.pow(1 - e, 2).toDouble(), ss = s0 * s0 * (3 - 2 * s0);
      if (ee - ss < 0.01) continue;
      final ox = bx + 140 * k, sw = (ee - ss) * iw;
      final a = 0.8 * math.pow(math.sin(math.pi * _clamp01(k)), 0.5).toDouble() * ga;
      _put(c, name, Rect.fromLTWH(ox + ss * w, y, sw * sc, h), src: Rect.fromLTWH(ss * iw, 0, sw, ih), a: a, add: dark);
    }
  }

  // ---------- depan mesa: siang ----------
  void _dayFg(Canvas c, double tt, List<double> f) {
    // Pusaran debu: di halaman 4 tinggi dan puncaknya mengintip di atas kartu, di halaman 5 kecil di kejauhan.
    final dA = math.max(f[3], f[4]);
    if (dA > 0.02 && _ok('devil')) {
      final big = f[3] >= f[4];
      final h = big ? 236.0 : 110.0, w = h * 0.75;
      final double px = big ? 500 + (reduce ? 0.0 : 36 * math.sin(tt * 0.2)) : 470 + (reduce ? 0.0 : 20 * math.sin(tt * 0.25));
      final by = big ? 232.0 : _gy - 4;
      final fi = reduce ? 0 : (tt * 6).floor() % 3;
      _put(c, 'devil', Rect.fromLTWH(px - w / 2, by - h, w, h), src: Rect.fromLTWH(fi * 192.0, 0, 192, 256), a: _clamp01(dA) * 0.85);
    }
    // Ranting: halaman 2 terbawa angin di langit; halaman 5 menggelinding di tanah.
    final fa = math.max(f[1], f[4]);
    if (fa > 0.02 && _ok('tw')) {
      final air = f[1] >= f[4];
      for (var i = 0; i < 2; i++) {
        final period = air ? 7 + i * 2.5 : 9 + i * 3.5;
        final k = reduce ? 0.3 + i * 0.35 : (tt / period + i * 0.5) % 1;
        final size = (air ? 30.0 : 36.0) + i * 8;
        final px = -50 + 880 * k;
        final hop = reduce ? 0.0 : (air ? 38 : 12) * math.sin(tt * (air ? 2.4 : 3.2) + i * 2).abs();
        final py = (air ? 128 + i * 34 : _gy + i * 10) - hop;
        final rot = reduce ? 0.0 : k * 2 * math.pi * (5 + i);
        c.save();
        c.translate(px, py);
        c.rotate(rot);
        _put(c, 'tw', Rect.fromLTWH(-size / 2, -size / 2, size, size),
            src: Rect.fromLTWH(i * 200.0, 0, 200, 200), a: _clamp01(fa) * math.min(1.0, math.min(k * 10, (1 - k) * 10)));
        c.restore();
      }
    }
    // Kadal dan kuda berjalan di tanah (halaman 5).
    final a4 = f[4];
    if (a4 > 0.02 && _ok('liz')) {
      const period = 11.0, ks = 0.3;
      final k = reduce ? 0.2 : (tt / period) % 1;
      final u = k / 0.5;
      final fi = reduce ? 0 : (tt * 11).floor() % 4;
      if (u < 1) {
        _put(c, 'liz', Rect.fromLTWH(-80 + 940 * u - 128 * ks, _gy - 64 * ks, 256 * ks, 128 * ks),
            src: Rect.fromLTWH(fi * 256.0, 0, 256, 128), a: _clamp01(a4));
      }
    }
    if (a4 > 0.02 && _ok('horse')) {
      const period = 34.0, ks = 0.4;
      final k = reduce ? 0.35 : (tt / period + 0.3) % 1;
      final u = k / 0.7;
      final fi = reduce ? 0 : const [0, 1, 2, 1][(tt * 4.5).floor() % 4];
      if (u < 1) {
        _put(c, 'horse', Rect.fromLTWH(-120 + 1000 * u - 128 * ks, _gy - 128 * ks + 12, 256 * ks, 128 * ks),
            src: Rect.fromLTWH(fi * 256.0, 0, 256, 128), a: _clamp01(a4));
      }
    }
  }

  // ---------- depan mesa: malam ----------
  void _nightFg(Canvas c, double tt, List<double> f) {
    if (f[4] <= 0.02) return;
    final a4 = _clamp01(f[4]);
    // Kafilah unta berjalan.
    if (_ok('cara')) {
      const period = 46.0, ks = 0.36;
      final k = reduce ? 0.55 : (tt / period) % 1;
      final u = k / 0.75;
      final fi = reduce ? 0 : (tt * 3.2).floor() % 4;
      if (u < 1) {
        _put(c, 'cara', Rect.fromLTWH(-130 + 1040 * u - 128 * ks, _gy - 128 * ks + 8, 256 * ks, 128 * ks),
            src: Rect.fromLTWH(fi * 256.0, 0, 256, 128), a: a4);
      }
    }
    // Api unggun dengan percikan.
    if (_ok('fire')) {
      const fx = 150.0, ks = 0.32;
      final fi = reduce ? 0 : (tt * 7).floor() % 3;
      _radial(c, const Offset(fx, _gy - 14), 4, 70, const Color(0xFFFFAA46), 0.3 * a4);
      _put(c, 'fire', Rect.fromLTWH(fx - 80 * ks, _gy - 192 * ks + 4, 160 * ks, 192 * ks),
          src: Rect.fromLTWH(fi * 160.0, 0, 160, 192), a: a4, add: true);
      for (var j = 0; j < 3; j++) {
        final q = reduce ? 0.4 : ((tt / 2.2 + j / 3) % 1);
        _put(c, 'fire', Rect.fromLTWH(fx - 80 * ks, _gy - 192 * ks - 70 * q, 160 * ks, 192 * ks),
            src: Rect.fromLTWH(((fi + j) % 3) * 160.0, 192, 160, 192), a: a4 * math.sin(math.pi * q) * 0.9, add: true);
      }
    }
  }
}
