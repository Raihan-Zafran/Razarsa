import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../shell/layout.dart';
import '../../widgets/common.dart';
import '../../widgets/count_up.dart';
import '../settings/profile_page.dart';
import '../saldo/saldo_page.dart';
import 'add_transaction_page.dart';
import '../../widgets/mode_widgets.dart';
import '../../core/i18n.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final recent = store.txns.take(4).toList();

    final wide = isWide(context);

    final greet = <Widget>[
      // Header: tombol mode, tema, profil (di desktop sudah ada di bilah atas)
      if (!wide) ...[
        Row(children: [
          const Expanded(child: Align(alignment: Alignment.centerLeft, child: ModeSwitch())),
          const ThemeToggle(size: 34),
          const SizedBox(width: 2),
          RoundIconButton(
            icon: Icons.person_outline_rounded,
            tooltip: tr('Buka profil'),
            filled: true,
            size: 34,
            onTap: () => pushPage(context, const ProfilePage()),
          ),
        ]),
        const SizedBox(height: 10),
      ],
      Text(greeting(), style: TextStyle(fontSize: 13.5, color: z.muted)),
      const SizedBox(height: 2),
      Text(
        store.userName.isEmpty ? tr('Yuk, atur uangmu!') : trf('Halo, {0}', [store.userName]),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6),
      ),
      const SizedBox(height: 14),
    ];

    final main = <Widget>[
      _BalanceCard(store: store),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _AddButton(
            label: tr('Pengeluaran'),
            filled: true,
            icon: Icons.remove_rounded,
            onTap: () => pushPage(context, const AddTransactionPage(income: false)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AddButton(
            label: tr('Pemasukan'),
            filled: false,
            icon: Icons.add_rounded,
            onTap: () => pushPage(context, const AddTransactionPage(income: true)),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      _BalanceChartCard(series: store.balanceSeries(12), hidden: store.hideBalance),
      const SizedBox(height: 22),
      SectionTitle(tr('Catat Cepat'),
          trailing: Text(tr('Sekali tap langsung tercatat'), style: TextStyle(fontSize: 12, color: z.muted2))),
      const SizedBox(height: 10),
      SizedBox(
        height: scaledHeight(context, 52),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: wide ? Clip.hardEdge : Clip.none,
          itemCount: store.quickItems.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) => _QuickChip(item: store.quickItems[i]),
        ),
      ),
    ];

    final latest = <Widget>[
      SectionTitle(tr('Transaksi Terbaru'),
          trailing: TextButton(
            onPressed: onSeeAll,
            child: Text(tr('Lihat semua'), style: TextStyle(color: z.accentText, fontWeight: FontWeight.w700)),
          )),
      const SizedBox(height: 6),
      if (recent.isEmpty)
        ZCard(
          child: EmptyState(
            icon: Icons.receipt_long_rounded,
            title: tr('Belum ada transaksi'),
            message: tr('Catat pengeluaran atau pemasukan pertamamu lewat tombol di atas.'),
          ),
        )
      else
        ZCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < recent.length; i++)
              TxnRow(
                category: store.category(recent[i].cat),
                title: recent[i].name,
                subtitle: '${dayLabel(recent[i].at)}, ${timeLabel(recent[i].at)}${store.walletName(recent[i].wallet).isEmpty ? '' : ' · ${store.walletName(recent[i].wallet)}'}',
                amountText: rpSigned(recent[i].amount),
                isIncome: !recent[i].isExpense,
                showDivider: i < recent.length - 1,
              ),
          ]),
        ),
    ];

    // Jendela lebar: saldo dan Catat Cepat di kiri, transaksi terbaru di kanan.
    if (wide) {
      return PageScroll(maxWidth: 1120, children: [
        ...greet,
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 11, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: main)),
          const SizedBox(width: 28),
          Expanded(flex: 9, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: latest)),
        ]),
      ]);
    }
    return PageScroll(children: [
      ...greet,
      ...main,
      const SizedBox(height: 22),
      ...latest,
    ]);
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final divider = Colors.white.withValues(alpha: 0.18);
    return Semantics(
      button: true,
      label: tr('Total saldo'),
      hint: tr('Buka saldo per sumber'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => pushPage(context, const SaldoPage()),
        child: GlassPane(
          hero: true,
          color: z.hero,
          color2: z.hero2,
          radius: 18,
          border: Border.all(color: z.heroBorder),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(trf('Total saldo · {0} sumber', [store.wallets.length]),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: z.heroMuted)),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 18, color: z.heroMuted),
            ]),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: store.hideBalance
                  ? Text(rpHidden, style: _balanceStyle)
                  : CountUp(
                      value: store.balance.abs(),
                      format: (n) => (store.balance < 0 ? '-' : '') + rp(n),
                      style: _balanceStyle,
                    ),
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: divider),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(children: [
                Expanded(child: _MiniStat(icon: Icons.south_west_rounded, label: tr('Masuk bulan ini'), value: store.monthIncome(), tint: z.hi)),
                Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 14), color: divider),
                Expanded(child: _MiniStat(icon: Icons.north_east_rounded, label: tr('Keluar bulan ini'), value: store.monthExpense(), tint: const Color(0xFFFDBA74))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

const _balanceStyle = TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.2, height: 1.1);

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label, required this.value, required this.tint});

  final IconData icon;
  final String label;
  final num value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: tint),
        const SizedBox(width: 5),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: z.heroMuted))),
      ]),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: CountUp(value: value, format: rp, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    ]);
  }
}

/// Kartu "Saldo 12 hari terakhir": grafik garis dengan sumbu, bidang berwarna, dan titik akhir.
/// Isinya data nyata (saldo akhir tiap hari). Sentuh atau geser untuk melihat saldo per hari.
class _BalanceChartCard extends StatefulWidget {
  const _BalanceChartCard({required this.series, required this.hidden});

  final List<int> series;
  final bool hidden;

  @override
  State<_BalanceChartCard> createState() => _BalanceChartCardState();
}

class _BalanceChartCardState extends State<_BalanceChartCard> with SingleTickerProviderStateMixin {
  static const _h = 160.0;
  static const _padL = 38.0, _padR = 6.0, _padT = 8.0, _padB = 22.0;
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  bool _started = false;
  int? _hover;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _draw.value = 1;
    } else {
      _draw.forward();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  void _touch(Offset local, double w) {
    final n = widget.series.length;
    final k = ((local.dx - _padL) / (w - _padL - _padR)).clamp(0.0, 1.0);
    final i = (k * (n - 1)).round();
    if (i != _hover) setState(() => _hover = i);
  }

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final v = widget.series;
    final n = v.length;
    final today = dayOnly(DateTime.now());
    DateTime dayAt(int i) => DateTime(today.year, today.month, today.day - (n - 1 - i));
    String dl(int i) => i == n - 1 ? tr('Hari ini') : '${dayAt(i).day} ${monthShort(dayAt(i))}';
    final hv = _hover;
    return ZCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(tr('Saldo 12 hari terakhir'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
            Text(tr('Sentuh grafik'), style: TextStyle(fontSize: 12, color: z.muted2)),
          ]),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            return Semantics(
              container: true,
              label: tr('Saldo 12 hari terakhir'),
              child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _touch(d.localPosition, w),
              onTapUp: (_) => setState(() => _hover = null),
              onTapCancel: () => setState(() => _hover = null),
              onPanStart: (d) => _touch(d.localPosition, w),
              onPanUpdate: (d) => _touch(d.localPosition, w),
              onPanEnd: (_) => setState(() => _hover = null),
              onPanCancel: () => setState(() => _hover = null),
              child: SizedBox(
                width: w,
                height: _h,
                child: Stack(clipBehavior: Clip.none, children: [
                  AnimatedBuilder(
                    animation: _draw,
                    builder: (_, _) => CustomPaint(
                      size: Size(w, _h),
                      painter: _ChartPainter(
                        values: v,
                        draw: const Cubic(0.4, 0.1, 0.2, 1).transform(_draw.value),
                        hover: hv,
                        hidden: widget.hidden,
                        line: z.primary,
                        grid: z.border,
                        label: z.muted2,
                        bg: z.card,
                        firstLabel: dl(0),
                        midLabel: dl(n ~/ 2 - (n.isEven ? 1 : 0)),
                        lastLabel: dl(n - 1),
                      ),
                    ),
                  ),
                  if (hv != null)
                    Builder(builder: (context) {
                      final plotW = w - _padL - _padR;
                      final x = _padL + hv / (n - 1) * plotW;
                      final text = '${dayAt(hv).day} ${monthShort(dayAt(hv))} · ${widget.hidden ? rpHidden : rp(v[hv])}';
                      return Positioned(
                        left: (x - 70).clamp(0.0, w - 140),
                        top: -6,
                        child: Container(
                          width: 140,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: z.hero,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
                          ),
                          child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      );
                    }),
                ]),
              ),
              ),
            );
          }),
        ]),
    );
  }
}

String _jt(int v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a >= 1000000) {
    final x = a / 1e6;
    final t = x >= 10 ? x.round().toString() : x.toStringAsFixed(1).replaceAll('.', ',').replaceAll(RegExp(r',0$'), '');
    return '$sign$t jt';
  }
  if (a >= 1000) return '$sign${(a / 1000).round()} rb';
  return '$sign$a';
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({
    required this.values,
    required this.draw,
    required this.hover,
    required this.hidden,
    required this.line,
    required this.grid,
    required this.label,
    required this.bg,
    required this.firstLabel,
    required this.midLabel,
    required this.lastLabel,
  });

  final List<int> values;
  final double draw;
  final int? hover;
  final bool hidden;
  final Color line, grid, label, bg;
  final String firstLabel, midLabel, lastLabel;

  void _text(Canvas c, String t, Offset at, {TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: 11, color: label, fontFamily: kFont, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == TextAlign.right ? at.dx - tp.width : (align == TextAlign.center ? at.dx - tp.width / 2 : at.dx);
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const padL = _BalanceChartCardState._padL, padR = _BalanceChartCardState._padR;
    const padT = _BalanceChartCardState._padT, padB = _BalanceChartCardState._padB;
    final plot = Rect.fromLTRB(padL, padT, size.width - padR, size.height - padB);
    final n = values.length;
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final span = (hi - lo) == 0 ? 1 : (hi - lo);
    final yPad = span * 0.08;
    final minV = lo - yPad, maxV = hi + yPad;
    double yOf(num v) => plot.bottom - (v - minV) / (maxV - minV) * plot.height;
    double xOf(int i) => plot.left + i / (n - 1) * plot.width;

    // Garis bantu putus-putus dan label sumbu.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [hi, (hi + lo) ~/ 2, lo]) {
      final y = yOf(v);
      for (var x = plot.left; x < plot.right; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, plot.right), y), gridPaint);
      }
      _text(canvas, hidden ? '••' : _jt(v), Offset(padL - 6, y), align: TextAlign.right);
    }

    final pts = [for (var i = 0; i < n; i++) Offset(xOf(i), yOf(values[i]))];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    // Bidang di bawah garis.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(plot.left - 1, 0, plot.left + (plot.width + 2) * draw, size.height));
    final area = Path.from(path)
      ..lineTo(pts.last.dx, plot.bottom)
      ..lineTo(pts.first.dx, plot.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [line.withValues(alpha: 0.28), line.withValues(alpha: 0)])
            .createShader(plot),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    // Titik akhir (cincin) dan titik yang disentuh.
    final end = pts.last;
    if (draw > 0.98) {
      canvas.drawCircle(end, 5.5, Paint()..color = bg);
      canvas.drawCircle(end, 5.5, Paint()..color = line..style = PaintingStyle.stroke..strokeWidth = 2.2);
      canvas.drawCircle(end, 2.4, Paint()..color = line);
    }
    if (hover != null) {
      final p = pts[hover!];
      canvas.drawLine(Offset(p.dx, plot.top), Offset(p.dx, plot.bottom), Paint()..color = line.withValues(alpha: 0.3)..strokeWidth = 1.2);
      canvas.drawCircle(p, 5, Paint()..color = bg);
      canvas.drawCircle(p, 5, Paint()..color = line..style = PaintingStyle.stroke..strokeWidth = 2.2);
    }

    // Label sumbu x.
    _text(canvas, firstLabel, Offset(plot.left, size.height - 8));
    _text(canvas, midLabel, Offset(xOf(n ~/ 2 - (n.isEven ? 1 : 0)), size.height - 8), align: TextAlign.center);
    _text(canvas, lastLabel, Offset(plot.right, size.height - 8), align: TextAlign.right);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.draw != draw || old.hover != hover || old.values != values || old.line != line || old.hidden != hidden || old.grid != grid;
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.filled, required this.onTap, required this.icon});

  final String label;
  final bool filled;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Material(
      color: filled ? z.primary : z.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: filled ? BorderSide.none : BorderSide(color: z.primary, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: filled ? z.onPrimary : z.accentText),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: filled ? z.onPrimary : z.accentText)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.item});

  final QuickEntry item;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final z = ZColors.of(context);
    final cat = store.category(item.cat);
    return Material(
      color: z.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: z.cardBorder)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          final t = store.addTxn(name: item.name, cat: item.cat, amount: -item.amount);
          final where = store.wallets.length > 1 ? trf(' di {0}', [store.walletName(t.wallet)]) : '';
          showZToast(context, trf('{0} {1} dicatat', [tr(item.name), rp(item.amount)]) + where,
              actionLabel: tr('Batalkan'), onAction: () => store.removeTxn(t.id));
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
          child: Row(children: [
            CategoryTile(category: cat, size: 36),
            const SizedBox(width: 10),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(item.name), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(rpShort(item.amount), style: TextStyle(fontSize: 11, color: z.muted2)),
            ]),
            const SizedBox(width: 14),
            // Penanda "tambah" kecil; seluruh chip tetap satu tombol.
            ExcludeSemantics(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: z.primary, shape: BoxShape.circle),
                child: Icon(Icons.add_rounded, size: 16, color: z.onPrimary),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
