import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Latar "Langit": satu dunia (bukit, pohon palem, rumput, dan tokoh pengamat bintang) yang sama di
/// kelima halaman, dengan benda bergerak yang berbeda per halaman. Siang dan malam punya set sendiri.
///
/// Halaman 1: pesawat (siang) / roket (malam). Halaman 2: angin dan daun kering / kunang-kunang.
/// Halaman 3: awan beraneka bentuk / planet dan bintang. Halaman 4: layang-layang dan anak-anak /
/// burung malam dan meteor. Halaman 5: gabungan semuanya, ditambah balon udara (siang) atau
/// lampion, pita galaksi (malam).
///
/// Semua koordinat di bawah memakai satuan desain 780 x 600 (dua kali lebar 390 px).
class SkyBackground extends StatefulWidget {
  const SkyBackground({super.key, required this.dark, this.tab = 0});

  final bool dark;
  final int tab;

  static double heightFor(double w) => w / 390 * 300;

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  final _fades = _Fades();
  final _day = _FxState();
  final _night = _FxState();
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
    _SkyImages.warm();
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
  void didUpdateWidget(covariant SkyBackground old) {
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
        final h = SkyBackground.heightFor(w);
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
                  painter: _ScenePainter(
                    dark: widget.dark,
                    time: _time,
                    fades: _fades,
                    fx: widget.dark ? _night : _day,
                    reduce: _reduce,
                  ),
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

class _Pt {
  const _Pt(this.x, this.y, this.t);
  final double x, y, t;
}

class _Puff {
  _Puff(this.x, this.y, this.t0, this.k, this.vx);
  final double x, y, t0, vx;
  final int k;
}

/// Keadaan yang ikut bertahan antar bingkai (jejak pesawat, asap roket).
class _FxState {
  final pts = <_Pt>[];
  final smoke = <_Puff>[];
  double acc = 0;
  double last = 0;
  final rnd = math.Random(5);
}

/// Pemuat gambar: dimuat sekali, dipakai bersama, dan memicu gambar ulang saat selesai.
class _SkyImages {
  static const names = [
    'S1D', 'S1N', 'S2D', 'S2N', 'S3DL', 'S3DC', 'S3DR', 'S3NL', 'S3NC', 'S3NR', 'S4D', 'S4N',
    'skyD', 'skyN', 'moon', 'sun', 'plane', 'rocket', 'f1', 'f2', 'f3', 's1', 's2', 's3',
    'ff', 'leaves', 'w0', 'w1', 'w2', 'w3', 'st', 'pl', 'cl', 'bird', 'kid', 'kite', 'met0', 'met1',
    'rib0', 'rib1', 'lan', 'balloon',
  ];

  static final rev = ValueNotifier<int>(0);
  static final _imgs = <String, ui.Image>{};
  static bool _warmed = false;

  static ui.Image? get(String n) => _imgs[n];

  static void warm() {
    if (_warmed) return;
    _warmed = true;
    for (final n in names) {
      final stream = AssetImage('assets/sky/$n.webp').resolve(ImageConfiguration.empty);
      late ImageStreamListener l;
      l = ImageStreamListener((info, _) {
        _imgs[n] = info.image.clone();
        rev.value++;
        stream.removeListener(l);
      }, onError: (_, _) {
        _warmed = false; // coba lagi pada pemanggilan berikutnya
        stream.removeListener(l);
      });
      stream.addListener(l);
    }
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({required this.dark, required this.time, required this.fades, required this.fx, required this.reduce})
      : super(repaint: Listenable.merge([time, _SkyImages.rev]));

  final bool dark;
  final ValueNotifier<double> time;
  final _Fades fades;
  final _FxState fx;
  final bool reduce;

  String get _th => dark ? 'N' : 'D';

  static final List<List<double>> _stars = () {
    // Bintang kecil dasar: posisi tetap (pembangkit acak sederhana agar sama di setiap perangkat).
    final out = <List<double>>[];
    var sd = 11;
    double rnd() {
      sd = (sd * 16807) % 2147483647;
      return sd / 2147483647;
    }

    while (out.length < 78) {
      final x = rnd() * 780, y = rnd() * 330;
      if (math.sqrt((x - 640) * (x - 640) + (y - 172) * (y - 172)) < 60) continue;
      out.add([x, y, 0.8 + rnd() * 1.3, rnd() * 6.3, rnd() < 0.1 ? 1 : 0]);
    }
    return out;
  }();

  // ---------- alat gambar ----------
  void _put(Canvas c, String n, Rect dst, {Rect? src, double a = 1, bool add = false}) {
    final im = _SkyImages.get(n);
    if (im == null || a <= 0) return;
    final p = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, a.clamp(0.0, 1.0));
    if (add) p.blendMode = BlendMode.plus;
    c.drawImageRect(im, src ?? Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), dst, p);
  }

  static double _w(String n) => _SkyImages.get(n)?.width.toDouble() ?? 1;
  static double _h(String n) => _SkyImages.get(n)?.height.toDouble() ?? 1;
  bool _ok(String n) => _SkyImages.get(n) != null;

  void _radial(Canvas c, Offset o, double r0, double r1, Color col, double a, {bool add = true}) {
    final p = Paint()
      ..shader = ui.Gradient.radial(o, r1, [col.withValues(alpha: a), col.withValues(alpha: 0)], [r0 / r1, 1])
      ..blendMode = add ? BlendMode.plus : BlendMode.srcOver;
    c.drawCircle(o, r1, p);
  }

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

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
    final dt = (t - fx.last).clamp(0.0, 0.1).toDouble();
    fx.last = t;
    final f = fades.v;

    _sky(canvas, t);
    // Efek di belakang bukit.
    if (!dark && f[1] > 0.02) _wind(canvas, t, f[1], lite: false);
    if (f[2] > 0.02) dark ? _cosmos(canvas, t, f[2], lite: false) : _clouds(canvas, t, f[2], lite: false);
    if (dark && f[3] > 0.02) _night4(canvas, t, f[3]);
    if (f[4] > 0.02) dark ? _finale(canvas, t, dt, f[4]) : _finaleDay(canvas, t, f[4]);
    if (f[0] > 0.02) {
      if (dark) {
        _rocket(canvas, t, dt, f[0], 14);
      } else {
        _plane(canvas, t, f[0]);
      }
    }

    // Bukit jauh dan tengah bergeser pelan (parallax).
    _hill(canvas, 'S1$_th', t, 28, 6);
    _hill(canvas, 'S2$_th', t, 22, 12);

    // Efek di depan bukit.
    final kf = math.max(f[3], f[4]);
    if (!dark && kf > 0.02) _kites(canvas, t, kf);
    final fgA = math.max(f[1], f[4]);
    if (fgA > 0.02) {
      final lite = f[4] > f[1];
      dark ? _fireflies(canvas, t, fgA, lite) : _leaves(canvas, t, fgA, lite);
    }

    // Tokoh bernapas pelan, lalu rumput yang bergoyang di paling depan.
    _character(canvas, t);
    _grass(canvas, t);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => old.dark != dark || old.reduce != reduce;

  // ---------- dasar: langit, bulan/matahari, bukit, tokoh, rumput ----------
  void _sky(Canvas c, double t) {
    _put(c, 'sky$_th', const Rect.fromLTWH(0, 0, 780, 600));
    if (dark) {
      for (final s in _stars) {
        final a = reduce ? 0.8 : 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 1.5 + s[3]));
        final p = Paint()..color = Color.fromRGBO(255, 241, 201, a);
        final x = s[0], y = s[1], r = s[2];
        if (s[4] == 1) {
          final l = 5 + r * 2.4;
          final path = Path()
            ..moveTo(x, y - l)
            ..quadraticBezierTo(x, y, x + l, y)
            ..quadraticBezierTo(x, y, x, y + l)
            ..quadraticBezierTo(x, y, x - l, y)
            ..quadraticBezierTo(x, y, x, y - l)
            ..close();
          c.drawPath(path, p);
        } else {
          c.drawCircle(Offset(x, y), r, p);
        }
      }
      _put(c, 'moon', Rect.fromCenter(center: const Offset(640, 172), width: 150, height: 150));
    } else {
      final pu = reduce ? 0.0 : 0.5 + 0.5 * math.sin(t * 0.9);
      _radial(c, const Offset(640, 175), 20, 120, const Color(0xFFFFE2A0), 0.34 + 0.1 * pu, add: false);
      _put(c, 'sun', Rect.fromCenter(center: const Offset(640, 175), width: 76, height: 76));
    }
  }

  void _hill(Canvas c, String n, double t, double period, double amp) {
    final dx = reduce ? 0.0 : (-amp + 2 * amp * _alt(t, period));
    c.save();
    c.translate(390, 300);
    c.scale(1.03);
    c.translate(-390 + dx, -300);
    _put(c, n, const Rect.fromLTWH(0, 0, 780, 600));
    c.restore();
  }

  void _character(Canvas c, double t) {
    // Tokoh 152 x 202 di (562, 294); bernapas dengan skala vertikal 1 -> 1,012 dari kakinya.
    final k = reduce ? 0.0 : 0.012 * (0.5 - 0.5 * math.cos(t * 2 * math.pi / 4.2));
    c.save();
    c.translate(562 + 76, 294 + 202);
    c.scale(1, 1 + k);
    _put(c, 'S4$_th', const Rect.fromLTWH(-76, -202, 152, 202));
    c.restore();
  }

  void _grass(Canvas c, double t) {
    void piece(String n, double x, double w, double from, double to, double period, double delay) {
      final deg = reduce ? 0.0 : from + (to - from) * _alt(t, period, delay);
      c.save();
      c.translate(x + w / 2, 600);
      c.transform((Matrix4.identity()..setEntry(0, 1, math.tan(deg * math.pi / 180))).storage);
      _put(c, n, Rect.fromLTWH(-w / 2, -600, w, 600));
      c.restore();
    }

    piece('S3${_th}L', 0, 215, -1.6, 1.9, 3.4, 0);
    piece('S3${_th}C', 215, 355, -0.6, 0.7, 5.2, 0);
    piece('S3${_th}R', 570, 210, -1.6, 1.9, 4.1, 1.3);
  }

  // ---------- halaman 1: pesawat dan roket ----------
  void _plane(Canvas c, double t, double ga) {
    const w = 130.0, h = 29.0, ang = 0.09;
    void draw(double px, double py) {
      c.save();
      c.translate(px, py);
      c.rotate(ang);
      c.scale(-1, 1);
      _put(c, 'plane', const Rect.fromLTWH(-w / 2, -h / 2, w, h), a: ga);
      c.restore();
    }

    if (reduce) {
      draw(520, 140);
      return;
    }
    const period = 18.0;
    final k = (t % period) / period;
    final act = k < 0.72;
    final u = k / 0.72;
    final px = 980 - 1180 * u, py = 205 - 150 * u + 5 * math.sin(u * 10);
    if (act) {
      const lx = w * 0.46, ly = h * 0.08;
      fx.pts.add(_Pt(px + lx * math.cos(ang) - ly * math.sin(ang), py + lx * math.sin(ang) + ly * math.cos(ang), t));
    }
    while (fx.pts.isNotEmpty && t - fx.pts.first.t > 5.2) {
      fx.pts.removeAt(0);
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < fx.pts.length; i++) {
      final a = fx.pts[i - 1], b = fx.pts[i];
      if (b.t - a.t > 0.3) continue;
      final age = t - b.t;
      final al = 0.72 * math.pow(math.max(0.0, 1 - age / 5.2), 1.4) * ga;
      final off = 1.2 + age * 0.9;
      line
        ..color = Color.fromRGBO(255, 255, 255, al.clamp(0.0, 1.0).toDouble())
        ..strokeWidth = 2 + age * 1.5;
      c.drawLine(Offset(a.x, a.y - off), Offset(b.x, b.y - off), line);
      c.drawLine(Offset(a.x, a.y + off), Offset(b.x, b.y + off), line);
    }
    if (act) draw(px, py);
  }

  void _rocket(Canvas c, double t, double dt, double ga, double period) {
    if (reduce) return;
    final kt = t % period;
    const t0 = 1.5, t1 = 8.0;
    final fly = kt >= t0 && kt <= t1;
    final u = _clamp01((kt - t0) / (t1 - t0));
    final e = math.pow(u, 2.1).toDouble();
    final rx = 380 + 90 * e, ry = 480 - 640 * e;
    final th = math.atan2(90, 640) * 0.9;
    const rw = 48.0, rh = 88.0;
    final nozX = rx - math.sin(th) * rh * 0.35, nozY = ry + math.cos(th) * rh * 0.35;
    if (fly) {
      fx.acc += dt;
      while (fx.acc > 0.1) {
        fx.acc -= 0.1;
        fx.smoke.add(_Puff(nozX + (fx.rnd.nextDouble() - 0.5) * 6, nozY + 8, t, 1 + fx.rnd.nextInt(3), (fx.rnd.nextDouble() - 0.5) * 10 - 5));
      }
    }
    for (var i = fx.smoke.length - 1; i >= 0; i--) {
      final s = fx.smoke[i];
      final age = t - s.t0;
      if (age > 1.6) {
        fx.smoke.removeAt(i);
        continue;
      }
      final n = 's${s.k}';
      if (!_ok(n)) continue;
      final sc = 0.4 + age * 0.5, w = _w(n) * 0.4 * sc, h = _h(n) * 0.4 * sc;
      _put(c, n, Rect.fromLTWH(s.x + s.vx * age - w / 2, s.y + age * 14 - h / 2, w, h), a: _clamp01(0.62 * (1 - age / 1.6)) * ga);
    }
    if (!fly) return;
    c.save();
    c.translate(rx, ry);
    c.rotate(th);
    final fn = ['f1', 'f2', 'f3', 'f2'][(t * 14).floor() % 4];
    if (_ok(fn)) {
      final fw = _w(fn) * 0.4, fh = _h(fn) * 0.4 * (0.85 + 0.35 * math.min(1.0, u * 3));
      _put(c, fn, Rect.fromLTWH(-fw / 2, rh * 0.35 - 4, fw, fh), a: ga);
    }
    _put(c, 'rocket', const Rect.fromLTWH(-rw / 2, -rh / 2, rw, rh), a: ga);
    c.restore();
  }

  // ---------- halaman 2: angin, daun, kunang-kunang ----------
  void _wind(Canvas c, double t, double ga, {required bool lite}) {
    const defs = [
      [0.0, 96.0, 0.62, 7.0, 0.0, 20.0],
      [3.0, 156.0, 0.5, 8.5, 0.28, 300.0],
      [2.0, 232.0, 0.74, 9.5, 0.55, 470.0],
      [1.0, 62.0, 0.42, 6.0, 0.8, 120.0],
    ];
    final list = lite ? defs.sublist(0, 2) : defs;
    for (var n = 0; n < list.length; n++) {
      final d = list[n];
      final name = 'w${d[0].toInt()}';
      if (!_ok(name)) continue;
      final iw = _w(name), ih = _h(name);
      final sc = d[2], y = d[1], period = d[3], ph = d[4], bx = d[5];
      final w = iw * sc, h = ih * sc;
      if (reduce) {
        if (n < 2) _put(c, name, Rect.fromLTWH(bx, y, w, h), a: 0.55 * ga);
        continue;
      }
      final k = (t / period + ph) % 1;
      final e = _clamp01(k / 0.5), s0 = _clamp01((k - 0.5) / 0.5);
      final ee = 1 - math.pow(1 - e, 2).toDouble(), ss = s0 * s0 * (3 - 2 * s0);
      if (ee - ss < 0.01) continue;
      final ox = bx + 140 * k, sw = (ee - ss) * iw;
      final a = 0.82 * math.pow(math.sin(math.pi * _clamp01(k)), 0.5).toDouble() * ga;
      _put(c, name, Rect.fromLTWH(ox + ss * w, y, sw * sc, h), src: Rect.fromLTWH(ss * iw, 0, sw, ih), a: a);
    }
  }

  void _leaves(Canvas c, double t, double ga, bool lite) {
    if (!_ok('leaves')) return;
    final tt = reduce ? 0.0 : t;
    final count = lite ? 6 : 11;
    for (var n = 0; n < count; n++) {
      final idx = n % 8;
      final period = 11 + (n * 1.7) % 5, ph = (n * 0.37) % 1;
      final k = reduce ? ph : (tt / period + ph) % 1;
      final px = -50 + 880 * k;
      final py = 40 + (n * 53) % 230 + 38 * math.sin(k * 9.4 + n) + 70 * k;
      final rot = k * 6.28 * (1 + (n % 3) * 0.4) * (n % 2 == 1 ? 1 : -1) + math.sin(tt * 2 + n) * 0.5;
      final sx = 0.28 + 0.72 * math.cos(tt * (1.6 + (n % 3) * 0.5) + n).abs();
      final size = 40.0 + (n * 11) % 26;
      final a = math.min(1.0, math.min(k * 8, (1 - k) * 8)) * ga;
      c.save();
      c.translate(px, py);
      c.rotate(rot);
      c.scale(sx, 1);
      _put(c, 'leaves', Rect.fromLTWH(-size / 2, -size / 2, size, size),
          src: Rect.fromLTWH((idx % 4) * 128.0, (idx ~/ 4) * 128.0, 128, 128), a: a);
      c.restore();
    }
  }

  void _fireflies(Canvas c, double t, double ga, bool lite) {
    if (!_ok('ff')) return;
    final tt = reduce ? 0.0 : t;
    final count = lite ? 9 : 15;
    for (var n = 0; n < count; n++) {
      final body = n < 6;
      final b0 = 0.35 + 0.05 * (n % 3), ang = tt * b0 + n * 1.7;
      final bx = 40 + (n * 137.5) % 700, by = 150 + (n * 83) % 320;
      final px = bx + 30 * math.sin(ang) + 14 * math.sin(tt * 1.1 + n * 2.3);
      final py = by + 22 * math.sin(tt * (0.3 + 0.04 * (n % 4)) + n * 2.9) + 8 * math.sin(tt * 0.9 + n);
      final g = reduce ? 0.7 : 0.25 + 0.75 * math.pow(math.max(0.0, math.sin(tt * (0.9 + 0.15 * (n % 4)) + n * 1.3)), 1.5).toDouble();
      if (body) {
        final dirR = math.cos(ang) >= 0;
        final fr = reduce ? 0 : [0, 1, 2, 1][(tt * (12 + (n % 3) * 2)).floor() % 4];
        final kk = (30 + (n % 3) * 5) / 100;
        c.save();
        c.translate(px, py);
        c.scale(dirR ? -1 : 1, 1);
        _put(c, 'ff', Rect.fromLTWH(-92 * kk, -78 * kk, 160 * kk, 128 * kk), src: Rect.fromLTWH(fr * 160.0, 0, 160, 128), a: ga);
        c.restore();
      }
      final sz = body ? 34 + g * 32 : 9 + (n % 4) * 3 + g * 6;
      final oi = 1 + (n % 3);
      _put(c, 'ff', Rect.fromLTWH(px - sz / 2, py - sz / 2, sz, sz),
          src: Rect.fromLTWH(oi * 160.0 + 32, 128, 96, 96), a: (body ? 0.35 + 0.65 * g : 0.2 + 0.55 * g) * ga, add: true);
    }
  }

  // ---------- halaman 3: awan, planet, bintang ----------
  void _clouds(Canvas c, double t, double ga, {required bool lite}) {
    if (!_ok('cl')) return;
    const defs = [
      [2.0, 62.0, 0.55, 95.0, 0.1, 0.72], [6.0, 106.0, 0.6, 110.0, 0.55, 0.72], [4.0, 28.0, 0.7, 100.0, 0.8, 0.72],
      [3.0, 80.0, 0.85, 70.0, 0.3, 0.9], [8.0, 120.0, 0.8, 75.0, 0.7, 0.9], [9.0, 42.0, 0.9, 65.0, 0.05, 0.9],
      [0.0, 96.0, 0.95, 48.0, 0.45, 1.0], [5.0, 128.0, 1.0, 55.0, 0.9, 1.0], [7.0, 66.0, 1.05, 44.0, 0.2, 1.0],
      [1.0, 22.0, 0.9, 60.0, 0.65, 0.9],
    ];
    for (var i = 0; i < defs.length; i++) {
      if (lite && i % 2 != 0) continue;
      final d = defs[i];
      final idx = d[0].toInt();
      final w = 256 * d[2], h = 176 * d[2];
      final k = reduce ? d[4] : (t / d[3] + d[4]) % 1;
      final px = -w + (780 + w * 2) * k;
      _put(c, 'cl', Rect.fromLTWH(px, d[1] - h / 2, w, h),
          src: Rect.fromLTWH((idx % 5) * 256.0, (idx ~/ 5) * 176.0, 256, 176), a: d[5] * ga);
    }
  }

  void _cosmos(Canvas c, double t, double ga, {required bool lite}) {
    final tt = reduce ? 0.0 : t;
    if (_ok('st')) {
      for (var n = 0; n < (lite ? 14 : 28); n++) {
        final row = n % 3, col = (n ~/ 3) % 4;
        final sx = (n * 97.3) % 760 + 10, sy = (n * 61.7) % 230 + 6;
        final a = reduce ? 0.8 : 0.35 + 0.65 * (0.5 + 0.5 * math.sin(tt * (0.8 + 0.2 * (n % 5)) + n * 1.9));
        final sc = reduce ? 1.0 : 0.88 + 0.22 * math.sin(tt * (0.7 + 0.15 * (n % 4)) + n);
        final sz = [34.0, 26.0, 20.0, 14.0][col] * (row == 2 ? 0.8 : 1) * sc;
        c.save();
        c.translate(sx, sy);
        if (row == 0 && !reduce) c.rotate(0.12 * math.sin(tt * 0.5 + n));
        _put(c, 'st', Rect.fromLTWH(-sz / 2, -sz / 2, sz, sz), src: Rect.fromLTWH(col * 96.0, row * 96.0, 96, 96), a: a * ga, add: true);
        c.restore();
      }
    }
    if (!_ok('pl')) return;
    const planets = [
      [0, 335.0, 70.0, 0xFFB08CFF], [1, 485.0, 52.0, 0xFFFFAA50], [2, 580.0, 108.0, 0xFFA0B4E6],
      [3, 420.0, 112.0, 0xFFF06E46], [4, 700.0, 58.0, 0xFF46DCFF], [5, 255.0, 36.0, 0xFFFFE196],
    ];
    final list = lite ? [planets[0], planets[4], planets[5]] : planets;
    for (var n = 0; n < list.length; n++) {
      final p = list[n];
      final idx = p[0] as int;
      final px = (p[1] as double) + (reduce ? 0 : 9 * math.sin(tt * 0.2 + n * 1.3));
      final py = (p[2] as double) + (reduce ? 0 : 7 * math.sin(tt * 0.27 + n * 2.1));
      final rot = reduce ? 0.0 : 0.07 * math.sin(tt * 0.22 + n);
      _radial(c, Offset(px, py), 8, 56, Color(p[3] as int), 0.22 * ga);
      c.save();
      c.translate(px, py);
      c.rotate(rot);
      _put(c, 'pl', Rect.fromLTWH(-45, -45, 90, 90), src: Rect.fromLTWH((idx % 3) * 160.0, (idx ~/ 3) * 160.0, 160, 160), a: ga);
      c.restore();
    }
  }

  // ---------- halaman 4: burung, meteor, layang-layang ----------
  void _night4(Canvas c, double t, double ga) {
    final tt = reduce ? 0.0 : t;
    if (_ok('bird')) {
      void bird(double px, double py, double ks, int fi) =>
          _put(c, 'bird', Rect.fromLTWH(px - 128 * ks, py - 88 * ks, 256 * ks, 176 * ks), src: Rect.fromLTWH(fi * 256.0, 0, 256, 176), a: ga);
      const lead = [[0.0, 0.0], [-42.0, 15.0], [-74.0, -13.0], [-100.0, 24.0], [-136.0, 5.0], [-158.0, -21.0]];
      const period = 30.0;
      final k = reduce ? 0.42 : (tt / period) % 1;
      final lx = -40 + 960 * k, ly = 92 + 16 * math.sin(k * 14);
      for (var n = 0; n < lead.length; n++) {
        final fi = reduce ? 1 : [0, 1, 2, 1][(tt * 3.6 + n * 0.37).floor() % 4];
        final px = lx + lead[n][0], py = ly + lead[n][1] + 3 * math.sin(tt * 1.7 + n);
        if (px > -80 && px < 860) bird(px, py, 0.27 - n * 0.01, fi);
      }
      const lone = [[56.0, 40.0, 0.19, 0.3], [150.0, 36.0, 0.22, 0.72]];
      for (var n = 0; n < lone.length; n++) {
        final d = lone[n];
        final k2 = reduce ? d[3] : (tt / d[1] + d[3]) % 1;
        bird(-40 + 900 * k2, d[0] + 10 * math.sin(k2 * 11 + n), d[2], reduce ? 1 : [0, 1, 2, 1][(tt * 4 + n).floor() % 4]);
      }
    }
    if (reduce) return;
    const cy = 7.0;
    final n = (tt / cy).floor();
    final u = (tt % cy) / 1.0;
    if (u > 1) return;
    final name = 'met${n % 2}';
    if (!_ok(name)) return;
    final right = n % 2 == 0;
    final a = right ? 0.38 : math.pi - 0.38;
    final sx = 120 + (n * 211) % 440, sy = 14 + (n * 37) % 80, d = 430 * u;
    const w = 230.0;
    final h = w * _h(name) / _w(name);
    c.save();
    c.translate(sx + math.cos(a) * d, sy + math.sin(a) * d);
    c.rotate(a);
    _put(c, name, Rect.fromLTWH(-w + 8, -h / 2, w, h), a: math.pow(math.sin(math.pi * u), 0.6).toDouble() * ga, add: true);
    c.restore();
  }

  void _kites(Canvas c, double t, double ga) {
    if (!_ok('kite') || !_ok('kid')) return;
    final tt = reduce ? 0.0 : t;
    const km = [[52.0, 5.0, 75.0, 200.0], [52.0, 5.0, 75.0, 197.0], [55.0, 5.0, 69.0, 193.0], [26.0, 5.0, 127.0, 194.0], [62.0, 5.0, 55.0, 198.0]];
    const cm = [[129.6, 13.7], [128.9, 14.0], [122.5, 37.4], [146.6, 11.4]];
    const cx = [135.0, 290.0, 450.0, 615.0];
    const fy = 468.0, kd = 0.52;
    final hands = <Offset>[];
    for (var i = 0; i < cm.length; i++) {
      _put(c, 'kid', Rect.fromLTWH(cx[i] - 80 * kd, fy - 156 * kd, 160 * kd, 160 * kd), src: Rect.fromLTWH(i * 160.0, 0, 160, 160), a: ga);
      hands.add(Offset(cx[i] - 80 * kd + cm[i][0] * kd, fy - 156 * kd + cm[i][1] * kd));
    }
    const ks = [
      [0, 0, 130.0, 46.0, 0.52], [1, 1, 290.0, 42.0, 0.5], [2, 2, 470.0, 58.0, 0.52], [4, 3, 610.0, 48.0, 0.5], [3, -1, 385.0, 30.0, 0.34],
    ];
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = Color.fromRGBO(255, 255, 255, 0.8 * ga);
    for (var i = 0; i < ks.length; i++) {
      final d = ks[i];
      final ki = d[0] as int, ci = d[1] as int;
      final bx = d[2] as double, by = d[3] as double, s = d[4] as double;
      final kx = bx + 18 * math.sin(tt * 0.42 + i * 1.7), ky = by + 7 * math.sin(tt * 0.55 + i * 2.3);
      final rot = 0.1 * math.sin(tt * 0.5 + i), sk = 0.08 * math.sin(tt * 0.9 + i);
      final m = km[ki];
      final ax = m[0] + m[2] / 2, ay = m[1] + m[3] * 0.24;
      if (ci >= 0) {
        final h = hands[ci];
        final mx = (h.dx + kx) / 2 + 12 * math.sin(tt * 0.8 + i), my = (h.dy + ky) / 2 + 14 + 6 * math.sin(tt * 0.6 + i);
        final p = Path()
          ..moveTo(h.dx, h.dy)
          ..quadraticBezierTo(mx, my, kx, ky);
        c.drawPath(p, line);
      }
      c.save();
      c.translate(kx, ky);
      c.rotate(rot);
      c.transform((Matrix4.identity()..setEntry(0, 1, sk)).storage);
      _put(c, 'kite', Rect.fromLTWH(-ax * s, -ay * s, 180 * s, 210 * s), src: Rect.fromLTWH(ki * 180.0, 0, 180, 210), a: ga);
      c.restore();
    }
  }

  // ---------- halaman 5: gabungan ----------
  void _finale(Canvas c, double t, double dt, double ga) {
    final tt = reduce ? 0.0 : t;
    if (_ok('rib0') && _ok('rib1')) {
      const w = 700.0;
      final h = w * _h('rib0') / _w('rib0');
      final cx = 420 + (reduce ? 0 : 10 * math.sin(tt * 0.12)), cy = 175 + (reduce ? 0 : 6 * math.sin(tt * 0.17));
      final m = reduce ? 0.5 : 0.5 + 0.5 * math.sin(tt * 0.35);
      final r = Rect.fromLTWH(cx - w / 2, cy - h / 2, w, h);
      _put(c, 'rib0', r, a: 0.5 * (0.4 + 0.6 * (1 - m)) * ga, add: true);
      _put(c, 'rib1', r, a: ga * 0.5 * (0.4 + 0.6 * m), add: true);
    }
    _cosmos(c, t, ga, lite: true);
    _night4(c, t, ga);
    if (_ok('lan')) {
      for (var n = 0; n < 7; n++) {
        final period = 50 + (n * 9) % 30;
        final k = reduce ? (n * 0.15) % 1 : (tt / period + n * 0.143) % 1;
        final ci = n % 3, sc = 0.3 + 0.08 * ((n * 7) % 3);
        final px = 90 + (n * 109) % 600 + 16 * math.sin(tt * 0.4 + n * 1.7), py = 520 - 600 * k;
        final fl = reduce ? 1.0 : 0.88 + 0.12 * math.sin(tt * 3 + n * 2);
        final a = math.min(1.0, math.min(k * 8, (1 - k) * 5)) * fl * ga;
        _put(c, 'lan', Rect.fromLTWH(px - 80 * sc, py - 80 * sc, 160 * sc, 160 * sc), src: Rect.fromLTWH(ci * 160.0, 0, 160, 160), a: a);
      }
    }
    if (!reduce) _rocket(c, t, dt, ga, 26);
  }

  void _finaleDay(Canvas c, double t, double ga) {
    final tt = reduce ? 0.0 : t;
    _clouds(c, t, ga, lite: true);
    if (_ok('balloon')) {
      const period = 80.0;
      final k = reduce ? 0.35 : (tt / period + 0.2) % 1;
      final px = -60 + 900 * k, py = 178.0 + (reduce ? 0.0 : 8 * math.sin(tt * 0.5));
      const h = 86.0;
      final w = h * _w('balloon') / _h('balloon');
      c.save();
      c.translate(px, py);
      c.rotate(reduce ? 0.0 : 0.04 * math.sin(tt * 0.4));
      _put(c, 'balloon', Rect.fromLTWH(-w / 2, -h / 2, w, h), a: ga);
      c.restore();
    }
    _plane(c, t, ga);
    _wind(c, t, ga, lite: true);
  }
}
