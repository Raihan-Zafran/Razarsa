import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Status dan fisika empat karakter di halaman masuk.
/// Bagian bawah badan diam; hanya badan atas yang melengkung (seperti boneka).
class CharacterRig {
  bool welcome = true;
  bool greeting = false;
  bool showPw = false;
  String focus = 'none'; // none | name | email | pw
  String mood = 'none'; // none | sad | yay
  int blink = -1;

  /// Titik yang dilihat karakter, dalam kanvas 390 x 844.
  Offset target = const Offset(195, 420);

  // Tata letak panggung (beranimasi halus saat pindah halaman).
  double s = 1.35, sl = 40, st = 170;
  double bubble = 0;
  double time = 0;

  final b = List<double>.filled(4, 0), bv = List<double>.filled(4, 0);
  final q = List<double>.filled(4, 0), qv = List<double>.filled(4, 0);

  bool get peek => focus == 'pw' && !showPw;
  bool get away => focus == 'pw' && showPw;
  bool get typing => focus == 'email' || focus == 'name';

  // [cx, intip, ketik, diam, buang muka, goyang]
  static const _cfg = [
    [100.0, 46.0, 22.0, 7.0, -18.0, 12.0],
    [141.0, 18.0, 11.0, 4.0, -9.0, 8.0],
    [88.0, 9.0, 6.0, 3.0, -6.0, 6.0],
    [187.0, 14.0, 9.0, 3.0, -8.0, 8.0],
  ];

  void step(double t, double dt) {
    time = t;
    final k = (dt * 8).clamp(0.0, 1.0);
    final ts = welcome ? 1.35 : 0.82, tl = welcome ? 40.0 : 100.0, tt = welcome ? 170.0 : 150.0;
    s += (ts - s) * k;
    sl += (tl - sl) * k;
    st += (tt - st) * k;
    final showBubble = welcome && greeting;
    bubble += ((showBubble ? 1 : 0) - bubble) * (dt * 10).clamp(0.0, 1.0);

    final frames = (dt * 60).clamp(0.5, 3.0);
    for (var i = 0; i < 4; i++) {
      final c = _cfg[i];
      final dir = ((target.dx - (sl + s * c[0])) / 120).clamp(-1.0, 1.0);
      var bi = dir * (peek ? c[1] : typing ? c[2] : c[3]);
      var qi = 1.5 * math.sin(t * 2 + i * 1.3);
      if (peek && i == 0) qi = 20;
      if (peek && i == 1) qi = 6;
      if (away) bi = c[4];
      if (mood == 'sad') {
        bi = c[5] * 0.8 * math.sin(t * 14 + i);
        qi = 7;
      }
      if (mood == 'yay') {
        bi = c[5] * math.sin(t * 9 + i);
        qi = -8;
      }
      if (welcome && greeting && (i == 1 || i == 2)) {
        bi = c[5] * math.sin(t * 7 + i);
        qi = -3 + 3 * math.sin(t * 14 + i);
      }
      for (var f = 0; f < frames.round(); f++) {
        bv[i] = (bv[i] + (bi - b[i]) * 0.09) * 0.82;
        b[i] += bv[i];
        qv[i] = (qv[i] + (qi - q[i]) * 0.09) * 0.82;
        q[i] += qv[i];
      }
    }
  }
}

class _Spec {
  const _Spec(this.w, this.h, this.r, this.left, this.top, this.color, this.lx, this.ly, this.fx);

  final double w, h, r, left, top;
  final Color color;
  final double lx, ly, fx;
}

const _ink = Color(0xFF2A2140);

class CharacterPainter extends CustomPainter {
  CharacterPainter(this.rig);

  final CharacterRig rig;

  static const _specs = [
    _Spec(76, 175, 34, 62, 15, Color(0xFFB98AF6), 100, 36, 6), // monster ungu
    _Spec(50, 120, 25, 116, 70, Color(0xFFFFA7BF), 141, 90, 4), // si Pink
    _Spec(156, 78, 78, 10, 112, Color(0xFFA8E6AE), 88, 128, 4), // katak
    _Spec(58, 90, 29, 158, 100, Color(0xFFFFDA70), 187, 122, 4), // anak ayam
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(rig.sl, rig.st);
    canvas.scale(rig.s);
    for (var i = 0; i < 4; i++) {
      _character(canvas, i);
    }
    if (rig.bubble > 0.01) {
      _bubble(canvas, 'Hai!', const Offset(0, 70));
      _bubble(canvas, 'Halo!', const Offset(150, 22));
    }
    canvas.restore();
  }

  // ---------- Bantuan ----------
  ({Offset off, Offset u}) _look(_Spec sp) {
    final ex = rig.sl + rig.s * sp.lx, ey = rig.st + rig.s * sp.ly;
    var t = rig.target;
    if (rig.away) t = Offset(-300, ey - 260);
    if (rig.mood == 'sad') t = Offset(ex, ey + 400);
    if (rig.mood == 'yay') t = Offset(ex, ey - 400);
    final d = t - Offset(ex, ey);
    final len = d.distance == 0 ? 1.0 : d.distance;
    final m = math.min(1.0, len / 120);
    final u = d / len;
    return (off: u * m * sp.fx, u: u);
  }

  Path _body(_Spec sp, double dx, double dy) {
    final w = sp.w, h = sp.h;
    final rr = math.max(0.0, math.min(sp.r, h - dy - 2));
    const k = 0.5523;
    final side = math.max(0.0, h - (dy + rr));
    final c1 = h - side * 0.5, c2 = dy + rr + side * 0.35;
    return Path()
      ..moveTo(0, h)
      ..cubicTo(0, c1, dx, c2, dx, dy + rr)
      ..cubicTo(dx, dy + rr - k * rr, dx + rr - k * rr, dy, dx + rr, dy)
      ..lineTo(dx + w - rr, dy)
      ..cubicTo(dx + w - rr + k * rr, dy, dx + w, dy + rr - k * rr, dx + w, dy + rr)
      ..cubicTo(dx + w, c2, w, c1, w, h)
      ..close();
  }

  Offset _shift(_Spec sp, double y, double dx, double dy) {
    final u = ((sp.h - y) / math.max(1, sp.h - sp.r)).clamp(0.0, 1.0);
    final sx = dx * (3 * u * u - 2 * u * u * u);
    final sy = dy * ((sp.h - y) / sp.h).clamp(0.0, 1.0);
    return Offset(sx, sy);
  }

  void _eye(Canvas c, Offset center, double r, double pr, Offset u, double move, bool closed, bool happy) {
    if (closed || happy) {
      final p = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final rect = Rect.fromCenter(center: center, width: r * 2, height: r);
      c.drawArc(rect, happy ? math.pi : 0, math.pi, false, p);
      return;
    }
    c.drawCircle(center, r, Paint()..color = Colors.white);
    final pc = center + u * move;
    c.drawCircle(pc, pr, Paint()..color = _ink);
    c.drawCircle(pc + Offset(-pr * 0.35, -pr * 0.4), pr * 0.35, Paint()..color = Colors.white);
  }

  void _dotEye(Canvas c, Offset center, double r, bool closed, bool happy) {
    if (closed || happy) {
      _eye(c, center, r + 1, 0, Offset.zero, 0, closed, happy);
      return;
    }
    c.drawCircle(center, r, Paint()..color = _ink);
  }

  void _mouth(Canvas c, Offset at, double w, double h, String kind, {Color fill = _ink}) {
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    switch (kind) {
      case 'smile':
        c.drawArc(Rect.fromLTWH(at.dx, at.dy - h, w, h * 2), 0.15, math.pi - 0.3, false, line);
      case 'frown':
        c.drawArc(Rect.fromLTWH(at.dx, at.dy, w, h * 2), math.pi + 0.2, math.pi - 0.4, false, line);
      case 'o':
        c.drawOval(Rect.fromLTWH(at.dx, at.dy, w, h), Paint()..color = _ink);
      case 'open':
        final p = Path()
          ..moveTo(at.dx, at.dy)
          ..lineTo(at.dx + w, at.dy)
          ..quadraticBezierTo(at.dx + w, at.dy + h * 1.4, at.dx + w / 2, at.dy + h * 1.4)
          ..quadraticBezierTo(at.dx, at.dy + h * 1.4, at.dx, at.dy)
          ..close();
        c.drawPath(p, Paint()..color = fill);
    }
  }

  void _blush(Canvas c, Rect r, Color color) => c.drawOval(r, Paint()..color = color.withValues(alpha: 0.85));

  String _mouthKind() {
    if (rig.mood == 'sad') return 'frown';
    if (rig.mood == 'yay') return 'open';
    return 'smile';
  }

  // ---------- Karakter ----------
  void _character(Canvas canvas, int i) {
    final sp = _specs[i];
    final dx = rig.b[i], dy = rig.q[i];
    final look = _look(sp);
    final closed = rig.blink == i && !rig.away;
    final happy = rig.mood == 'yay';
    canvas.save();
    canvas.translate(sp.left, sp.top);

    // Tanduk / jambul ikut kepala.
    if (i == 0 || i == 3) {
      canvas.save();
      canvas.translate(dx, dy);
      if (i == 0) {
        final horn = Paint()..color = sp.color;
        canvas.save();
        canvas.translate(15, -2);
        canvas.rotate(-0.28);
        canvas.drawRRect(RRect.fromRectAndCorners(const Rect.fromLTWH(-11, -18, 22, 34),
            topLeft: const Radius.elliptical(15, 30), topRight: const Radius.elliptical(7, 24)), horn);
        canvas.restore();
        canvas.save();
        canvas.translate(61, -2);
        canvas.rotate(0.31);
        canvas.drawRRect(RRect.fromRectAndCorners(const Rect.fromLTWH(-11, -16, 22, 32),
            topLeft: const Radius.elliptical(7, 22), topRight: const Radius.elliptical(15, 28)), horn);
        canvas.restore();
      } else {
        final tuft = Paint()
          ..color = const Color(0xFFF2C14E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(26, 2), const Offset(22, -8), tuft);
        canvas.drawLine(const Offset(31, 1), const Offset(32, -10), tuft);
        canvas.drawLine(const Offset(36, 2), const Offset(41, -7), tuft);
      }
      canvas.restore();
    }

    canvas.drawPath(_body(sp, dx, dy), Paint()..color = sp.color);

    switch (i) {
      case 0: // Monster ungu
        final deco = _shift(sp, 120, dx, dy);
        final dp = Paint()..color = const Color(0xFF9C6BE3);
        canvas.drawCircle(const Offset(55, 111) + deco, 7, dp);
        canvas.drawCircle(const Offset(23, 145) + deco, 9, dp);
        final f = const Offset(10, 24) + look.off + _shift(sp, 24, dx, dy);
        _eye(canvas, f + const Offset(13, 11), 11, 5.5, look.u, 4, closed, happy);
        _eye(canvas, f + const Offset(41, 11), 9, 5, look.u, 3, closed, happy);
        if (rig.peek) {
          _mouth(canvas, f + const Offset(23, 28), 8, 10, 'o');
        } else if (rig.mood == 'sad') {
          _mouth(canvas, f + const Offset(20, 30), 16, 7, 'frown');
        } else if (rig.away) {
          _mouth(canvas, f + const Offset(21, 30), 14, 6, 'smile');
        } else {
          _mouth(canvas, f + const Offset(17, 26), 22, 11, 'open', fill: const Color(0xFF4B2A66));
          final tooth = Path()
            ..moveTo(f.dx + 20, f.dy + 26)
            ..lineTo(f.dx + 26, f.dy + 26)
            ..lineTo(f.dx + 23, f.dy + 32)
            ..close();
          canvas.drawPath(tooth, Paint()..color = Colors.white);
        }
      case 1: // Si Pink
        final f = const Offset(8, 28) + look.off + _shift(sp, 28, dx, dy);
        _blush(canvas, Rect.fromLTWH(f.dx - 2, f.dy + 14, 9, 5), const Color(0xFFFF7FA2));
        _blush(canvas, Rect.fromLTWH(f.dx + 27, f.dy + 14, 9, 5), const Color(0xFFFF7FA2));
        _eye(canvas, f + const Offset(7, 6), 6, 3.2, look.u, 2.5, closed, happy);
        _eye(canvas, f + const Offset(27, 6), 6, 3.2, look.u, 2.5, closed, happy);
        rig.peek ? _mouth(canvas, f + const Offset(14, 15), 6, 7, 'o') : _mouth(canvas, f + const Offset(12, 17), 10, 5, _mouthKind());
      case 2: // Katak
        final f = const Offset(52, 16) + look.off + _shift(sp, 16, dx, dy);
        _blush(canvas, Rect.fromLTWH(f.dx - 8, f.dy + 22, 12, 6), const Color(0xFFFF9DB8));
        _blush(canvas, Rect.fromLTWH(f.dx + 48, f.dy + 22, 12, 6), const Color(0xFFFF9DB8));
        _eye(canvas, f + const Offset(9, 9), 9, 4.5, look.u, 3, closed, happy);
        _eye(canvas, f + const Offset(43, 9), 9, 4.5, look.u, 3, closed, happy);
        _mouth(canvas, f + const Offset(14, 24), 24, 7, _mouthKind(), fill: const Color(0xFF1F7A3A));
      case 3: // Anak ayam
        final f = const Offset(12, 26) + look.off + _shift(sp, 26, dx, dy);
        _blush(canvas, Rect.fromLTWH(f.dx - 2, f.dy + 12, 9, 5), const Color(0xFFFFA58A));
        _blush(canvas, Rect.fromLTWH(f.dx + 28, f.dy + 12, 9, 5), const Color(0xFFFFA58A));
        _dotEye(canvas, f + const Offset(5, 4), 3.6, closed, happy);
        _dotEye(canvas, f + const Offset(29, 4), 3.6, closed, happy);
        final right = look.u.dx >= 0;
        final droop = rig.mood == 'sad' ? 0.35 : 0.0;
        canvas.save();
        canvas.translate(f.dx + 17, f.dy + 13);
        canvas.rotate(right ? droop : -droop);
        final beak = Path()
          ..moveTo(-6, -4)
          ..lineTo(6, -4)
          ..lineTo(right ? 10 : -10, 1)
          ..lineTo(0, 4)
          ..close();
        canvas.drawPath(beak, Paint()..color = const Color(0xFFFF9B3F));
        canvas.restore();
    }
    canvas.restore();
  }

  void _bubble(Canvas c, String text, Offset at) {
    final a = rig.bubble.clamp(0.0, 1.0);
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1C1A1F))),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 22, h = tp.height + 8;
    c.save();
    c.translate(at.dx + w * 0.3, at.dy + h);
    c.scale(0.5 + 0.5 * a);
    c.translate(-w * 0.3, -h);
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(14));
    final fill = Paint()..color = Colors.white.withValues(alpha: a);
    final line = Paint()
      ..color = const Color(0xFF1C1A1F).withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final tail = Path()
      ..moveTo(14, h - 1)
      ..lineTo(21, h + 6)
      ..lineTo(26, h - 1);
    c.drawRRect(r, fill);
    c.drawRRect(r, line);
    c.drawPath(tail, fill);
    c.drawPath(tail, line);
    c.drawRect(Rect.fromLTWH(15, h - 3, 10, 3), fill);
    if (a > 0.5) tp.paint(c, const Offset(11, 4));
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
