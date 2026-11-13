import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import 'graph_engine.dart';

/// Warna titik di atas latar cokelat tua (tidak mengikuti tema terang/gelap).
const kSaldoBg = Color(0xFF1A130F);
const kSaldoBgHi = Color(0xFF2B1F18);

Color walletTypeColor(String type) => switch (type) {
      'ewallet' => const Color(0xFF96DEE6),
      'cash' => const Color(0xFFF4C4A8),
      _ => const Color(0xFFFAF4EB),
    };

const _line = Color(0xFFD6C8BA);
const _catDot = Color(0xFFF6EFE6);
const _expDot = Color(0xFFE6DCD0);
const _incDot = Color(0xFF6EDEA0);
const _labelText = Color(0xFFD6CBBF);

/// Menangkap sentuhan hanya kalau jari tepat di sebuah titik, dan langsung "menang" supaya daftar di belakangnya
/// tidak ikut menggulir. Jari di ruang kosong dilepas: halaman tetap bisa digulir.
class NodeGrabRecognizer extends OneSequenceGestureRecognizer {
  NodeGrabRecognizer({required this.hit, required this.onDown, required this.onMove, required this.onUp, required this.onCancel});

  final bool Function(Offset local) hit;
  final void Function(Offset local) onDown;
  final void Function(Offset local) onMove;
  final void Function(Offset local) onUp;
  final VoidCallback onCancel;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!hit(event.localPosition)) return;
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
    onDown(event.localPosition);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onMove(event.localPosition);
    } else if (event is PointerUpEvent) {
      onUp(event.localPosition);
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      onCancel();
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'node grab';
}

/// Graph bulat bergaya Obsidian: sumber (besar), kategori (sedang), transaksi (kecil).
class SaldoGraph extends StatefulWidget {
  const SaldoGraph({
    super.key,
    required this.data,
    required this.onManageWallet,
    required this.onAddWallet,
    this.onSelected,
    this.reduceMotion = false,
    this.emptyText = '',
    this.fontFamily,
  });

  final GraphData data;
  final void Function(Wallet w) onManageWallet;
  final VoidCallback onAddWallet;

  /// Dipanggil saat pilihan titik berubah (null = tidak ada yang dipilih).
  final void Function(GNode? node)? onSelected;
  final bool reduceMotion;
  final String emptyText;
  final String? fontFamily;

  @override
  State<SaldoGraph> createState() => SaldoGraphState();
}

class SaldoGraphState extends State<SaldoGraph> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  GraphSim? sim;
  String? selected;
  double _t = 0;
  Duration _last = Duration.zero;
  bool _dragging = false;
  GNode? _grab;
  Offset _down = Offset.zero;
  bool _moved = false, _long = false;
  Timer? _timer;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _rebuild();
  }

  @override
  void didUpdateWidget(SaldoGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) _rebuild();
  }

  void _rebuild() {
    final prev = sim;
    if (prev != null && prev.data.sig == widget.data.sig) {
      // Data baru, isi sama: pakai simulasi yang ada, cukup perbarui rujukan.
      return;
    }
    sim = GraphSim.build(widget.data, previous: prev, t: _t);
    if (selected != null && !sim!.byId.containsKey(selected)) {
      selected = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSelected?.call(null));
    }
    if (widget.reduceMotion) {
      for (var i = 0; i < 160; i++) {
        sim!.step();
      }
      sim!.alpha = 0.012;
    }
    _kick();
  }

  void _kick() {
    if (!mounted) return;
    _repaint.value++;
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration d) {
    final g = sim;
    if (g == null) return;
    _t += _last == Duration.zero ? 0.016 : (d - _last).inMicroseconds / 1e6;
    _last = d;
    final growing = !widget.reduceMotion && _t - g.maxBorn < 0.7;
    if (!g.settled && !widget.reduceMotion) g.step();
    _repaint.value++;
    // Diam: hentikan ticker supaya tidak memakai baterai.
    if (g.settled && !_dragging && !growing) _ticker.stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  Offset _toCanvas(Offset local) {
    final rx = local.dx * kGraphW / _size.width, ry = local.dy * kGraphH / _size.height;
    return Offset((rx - kGraphW / 2) / kGraphZoom + kGraphW / 2, (ry - kGraphH / 2) / kGraphZoom + kGraphH / 2);
  }

  bool _hit(Offset local) {
    final g = sim;
    if (g == null || _size.isEmpty) return false;
    final p = _toCanvas(local);
    return g.hit(p.dx, p.dy) != null;
  }

  void _down0(Offset local) {
    final g = sim!;
    final p = _toCanvas(local);
    final n = g.hit(p.dx, p.dy);
    _grab = n;
    _down = p;
    _moved = false;
    _long = false;
    _dragging = true;
    n?.pin = true;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 560), () {
      if (_moved || _grab == null) return;
      if (_grab!.kind != GKind.wallet) return;
      _long = true;
      HapticFeedback.selectionClick();
      final w = _grab!.wallet!;
      _grab!.pin = false;
      widget.onManageWallet(w);
    });
    _kick();
  }

  void _move0(Offset local) {
    final n = _grab;
    if (n == null) return;
    final p = _toCanvas(local);
    if ((p - _down).distance > 5) {
      _moved = true;
      _timer?.cancel();
    }
    if (_moved) {
      n.x = p.dx.clamp(58.0, kGraphW - 58).toDouble();
      n.y = p.dy.clamp(52.0, kGraphH - 72).toDouble();
      final g = sim!;
      if (g.alpha < 0.35) g.alpha = 0.35;
      _kick();
    }
  }

  void _up0(Offset local) {
    _timer?.cancel();
    final n = _grab;
    _grab = null;
    _dragging = false;
    n?.pin = false;
    if (n == null || _long || _moved) {
      _kick();
      return;
    }
    setState(() => selected = selected == n.id ? null : n.id);
    widget.onSelected?.call(selected == null ? null : n);
    _kick();
  }

  void _cancel0() {
    _timer?.cancel();
    _grab?.pin = false;
    _grab = null;
    _dragging = false;
    _kick();
  }

  @override
  Widget build(BuildContext context) {
    final g = sim!;
    return AspectRatio(
      aspectRatio: kGraphW / kGraphH,
      child: LayoutBuilder(builder: (context, c) {
        _size = Size(c.maxWidth, c.maxHeight);
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            NodeGrabRecognizer: GestureRecognizerFactoryWithHandlers<NodeGrabRecognizer>(
              () => NodeGrabRecognizer(hit: _hit, onDown: _down0, onMove: _move0, onUp: _up0, onCancel: _cancel0),
              (r) {},
            ),
            TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(),
              (r) => r.onTap = () {
                if (selected != null) {
                  setState(() => selected = null);
                  widget.onSelected?.call(null);
                }
                _kick();
              },
            ),
            LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 560)),
              (r) => r.onLongPress = () {
                HapticFeedback.selectionClick();
                widget.onAddWallet();
              },
            ),
          },
          child: Semantics(
            label: widget.data.count == 0 ? widget.emptyText : null,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _GraphPainter(
                  sim: g,
                  repaint: _repaint,
                  now: () => _t,
                  selected: () => selected,
                  reduceMotion: widget.reduceMotion,
                  emptyText: widget.emptyText,
                  fontFamily: widget.fontFamily,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.sim,
    required Listenable repaint,
    required this.now,
    required this.selected,
    required this.reduceMotion,
    required this.emptyText,
    required this.fontFamily,
  }) : super(repaint: repaint);

  final GraphSim sim;
  final double Function() now;
  final String? Function() selected;
  final bool reduceMotion;
  final String emptyText;
  final String? fontFamily;

  final _tp = <String, TextPainter>{};

  TextPainter _text(String s, double size, FontWeight w, Color c, {bool stroke = false}) {
    final key = '$s|$size|${w.value}|${c.toARGB32()}|$stroke';
    return _tp.putIfAbsent(key, () {
      final style = stroke
          ? TextStyle(
              fontFamily: fontFamily,
              fontSize: size,
              fontWeight: w,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xD91A130F))
          : TextStyle(fontFamily: fontFamily, fontSize: size, fontWeight: w, color: c);
      return TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
    });
  }

  double _grow(GNode n, double t) {
    if (reduceMotion || n.born == 0) return 1;
    final k = ((t - n.born) / 0.5).clamp(0.0, 1.0);
    return 1 - math.pow(1 - k, 3) * (1 + 0.8 * (1 - k));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = sim;
    final t = now();
    final sx = size.width / kGraphW, sy = size.height / kGraphH;
    canvas.save();
    canvas.scale(sx, sy);
    final bg = ui.Gradient.radial(const Offset(kGraphW / 2, kGraphH / 2), 330, [kSaldoBgHi, kSaldoBg]);
    canvas.drawRect(const Rect.fromLTWH(0, 0, kGraphW, kGraphH), Paint()..shader = bg);
    canvas.translate(kGraphW / 2, kGraphH / 2);
    canvas.scale(kGraphZoom);
    canvas.translate(-kGraphW / 2, -kGraphH / 2);

    final selId = selected();
    final sel = selId != null && g.byId.containsKey(selId) ? selId : null;
    final hl = sel == null ? null : g.neighbors(sel);
    final s = g.scale, sw = math.max(s, 0.65);
    double dim(String id) => hl != null && !hl.contains(id) ? 0.14 : 1;

    // garis tipis, dikelompokkan supaya ringan
    final lines = <int, Path>{};
    for (final l in g.links) {
      final bright = hl == null || (hl.contains(l.a.id) && hl.contains(l.b.id));
      final kind = (l.a.kind == GKind.wallet ? 0 : 1) * 2 + (bright ? 0 : 1);
      (lines[kind] ??= Path())
        ..moveTo(l.a.x, l.a.y)
        ..lineTo(l.b.x, l.b.y);
    }
    final lwW = 0.8 * math.max(s, 0.6), lwC = 0.55 * math.max(s, 0.6);
    void strokeKind(int k, double a, double w) {
      final p = lines[k];
      if (p == null) return;
      canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = w..color = _line.withValues(alpha: a));
    }

    strokeKind(1, 0.42 * 0.14, lwW);
    strokeKind(3, 0.3 * 0.14, lwC);
    strokeKind(0, 0.42, lwW);
    strokeKind(2, 0.3, lwC);

    // riwayat: titik redup di tepi, tanpa garis
    if (g.history.isNotEmpty) {
      final p = Paint()..color = _line.withValues(alpha: hl != null ? 0.07 : 0.34);
      for (final o in g.history) {
        canvas.drawCircle(Offset(o.x, o.y), 1.2, p);
      }
    }

    double rT(GNode n) {
      if (n.big < 0) n.big = math.min(1.0, math.log(n.txn!.amount.abs() / 5000 + 1) / math.ln10 / 1.6);
      return math.max(0.8, (1.5 + 0.9 * n.big) * s) * (n.id == sel ? 1.9 : 1);
    }

    double rC(GNode n) => (n.id == sel ? 1.4 : 1) * (3 + 3.2 * math.sqrt((n.cnt == 0 ? 1 : n.cnt) / g.maxCat)) * math.max(s, 0.62);

    final paint = Paint();
    void dot(GNode n, double r, Color c, double a) {
      final rr = r * _grow(n, t);
      if (rr <= 0) return;
      canvas.drawCircle(Offset(n.x, n.y), rr, paint..color = c.withValues(alpha: a));
    }

    // gelap dulu, lalu terang, supaya yang terpilih di atas
    for (final pass in [true, false]) {
      for (final n in g.nodes) {
        final dimmed = hl != null && !hl.contains(n.id);
        if (dimmed != pass) continue;
        final a = dimmed ? 0.14 : 1.0;
        if (n.kind == GKind.txn) {
          dot(n, rT(n), n.txn!.amount > 0 ? _incDot : _expDot, 0.95 * a);
        } else if (n.kind == GKind.category) {
          dot(n, rC(n), _catDot, a);
        }
      }
    }
    for (final n in g.data.wallets) {
      final r = (n.id == sel ? 1.25 : 1) * (5 + 4 * math.sqrt(n.cnt / g.maxWallet)) * sw;
      dot(n, r, walletTypeColor(n.wallet!.type), dim(n.id));
    }

    // teks minimal: nama sumber; kategori hanya saat gugusnya dipilih
    final many = g.data.wallets.length > 6;
    for (final n in g.nodes) {
      if (n.kind == GKind.txn) continue;
      if (n.kind == GKind.category && !(hl != null && hl.contains(n.id))) continue;
      final a = dim(n.id) * 0.92;
      if (n.kind == GKind.wallet) {
        final col = walletTypeColor(n.wallet!.type).withValues(alpha: a);
        final fs = many ? 10.5 : 11.5;
        final lx = n.x.clamp(80.0, kGraphW - 80);
        final shadow = _text(n.label, fs, FontWeight.w700, col, stroke: true);
        final fill = _text(n.label, fs, FontWeight.w700, col);
        shadow.paint(canvas, Offset(lx - shadow.width / 2, n.y + 19 - shadow.height / 2));
        fill.paint(canvas, Offset(lx - fill.width / 2, n.y + 19 - fill.height / 2));
      } else {
        final right = n.x > kGraphW - 80;
        final tp = _text(n.label, 9.5, FontWeight.w600, _labelText.withValues(alpha: a));
        final dx = right ? n.x - 9 - tp.width : n.x + 9;
        tp.paint(canvas, Offset(dx, n.y + 0.5 - tp.height / 2));
      }
    }
    if (g.empty && emptyText.isNotEmpty) {
      final tp = _text(emptyText, 11, FontWeight.w600, _labelText.withValues(alpha: 0.5));
      tp.paint(canvas, Offset(kGraphW / 2 - tp.width / 2, kGraphH - 78 - tp.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GraphPainter old) => old.sim != sim || old.emptyText != emptyText;
}
