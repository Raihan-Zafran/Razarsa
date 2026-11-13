import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../features/finance/goals_page.dart';
import '../features/finance/home_page.dart';
import '../features/finance/report_page.dart';
import '../features/finance/transactions_page.dart';
import '../features/productive/calendar_page.dart';
import '../features/productive/notes_page.dart';
import '../features/productive/prod_home_page.dart';
import '../features/productive/todo_page.dart';
import '../features/settings/settings_page.dart';
import '../data/store.dart';
import 'classroom_background.dart';
import 'dock.dart';
import 'dusk_background.dart';
import 'sky_background.dart';
import '../core/i18n.dart';
import '../widgets/mode_widgets.dart' show ModeReveal;

/// Potongan lingkaran yang membesar dari satu titik (untuk animasi ganti mode).
class _RevealClipper extends CustomClipper<Path> {
  _RevealClipper(this.fraction, this.center, this.maxRadius);

  final double fraction;
  final Offset center;
  final double maxRadius;

  @override
  Path getClip(Size size) => Path()..addOval(Rect.fromCircle(center: center, radius: maxRadius * fraction));

  @override
  bool shouldReclip(_RevealClipper old) => old.fraction != fraction || old.center != center || old.maxRadius != maxRadius;
}

/// Kerangka utama setelah masuk: mengikuti mode aktif (Keuangan / Produktif).
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = StoreScope.of(context).mode;
    final size = MediaQuery.sizeOf(context);
    // Transisi ganti mode: bulatan melebar dari tombol mode sampai memenuhi layar,
    // mode baru muncul di dalam lubangnya sementara mode lama tetap di belakang.
    final center = ModeReveal.origin ?? Offset(88, MediaQuery.paddingOf(context).top + 36);
    final corners = [Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)];
    final far = corners.map((c) => (c - center).distance).reduce(math.max);
    final ms = MediaQuery.disableAnimationsOf(context) ? 0 : 750;
    return AnimatedSwitcher(
      duration: Duration(milliseconds: ms),
      reverseDuration: Duration(milliseconds: ms),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.linear,
      transitionBuilder: (child, anim) {
        final incoming = child.key == ValueKey(mode);
        if (!incoming) return child;
        return AnimatedBuilder(
          animation: anim,
          child: child,
          builder: (context, c) => ClipPath(clipper: _RevealClipper(anim.value, center, far), child: c),
        );
      },
      child: RepaintBoundary(key: ValueKey(mode), child: ModeShell(mode: mode)),
    );
  }
}

/// Kerangka satu mode: latar animasi, halaman, dan dock.
class ModeShell extends StatefulWidget {
  const ModeShell({super.key, required this.mode});

  final String mode;

  @override
  State<ModeShell> createState() => _ModeShellState();
}

class _ModeShellState extends State<ModeShell> {
  int _tab = 0;

  bool get _prod => widget.mode == 'productive';

  List<DockItem> get _items => _prod
      ? [
          DockItem(Icons.home_rounded, tr('Hari ini')),
          DockItem(Icons.task_alt_rounded, tr('Tugas')),
          DockItem(Icons.calendar_month_rounded, tr('Kalender')),
          DockItem(Icons.sticky_note_2_outlined, tr('Catatan')),
          DockItem(Icons.settings_rounded, tr('Pengaturan')),
        ]
      : [
          DockItem(Icons.home_rounded, tr('Beranda')),
          DockItem(Icons.receipt_long_rounded, tr('Transaksi')),
          DockItem(Icons.bar_chart_rounded, tr('Laporan')),
          DockItem(Icons.flag_rounded, tr('Target')),
          DockItem(Icons.settings_rounded, tr('Pengaturan')),
        ];

  void goTo(int i) {
    if (i == _tab) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _tab = i);
  }

  Widget _page() {
    if (_prod) {
      switch (_tab) {
        case 1:
          return const TodoPage();
        case 2:
          return const CalendarPage();
        case 3:
          return const NotesPage();
        case 4:
          return const SettingsPage();
        default:
          return ProdHomePage(goTo: goTo);
      }
    }
    switch (_tab) {
      case 1:
        return const TransactionsPage();
      case 2:
        return const ReportPage();
      case 3:
        return const GoalsPage();
      case 4:
        return const SettingsPage();
      default:
        return HomePage(onSeeAll: () => goTo(1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Tombol Kembali sistem: dari tab mana pun kembali ke Beranda dulu; baru dari Beranda keluar aplikasi.
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goTo(0);
      },
      child: Scaffold(
      backgroundColor: z.bg,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _prod
                ? ClassroomBackground(dark: dark, tab: _tab, name: StoreScope.of(context).userName)
                : (StoreScope.of(context).financeBg == 'dusk'
                    ? DuskBackground(dark: dark, tab: _tab)
                    : SkyBackground(dark: dark, tab: _tab)),
          ),
          // Pindah tab: halaman baru muncul seketika, lalu elemen-elemennya naik satu per satu
          // (lihat [PageStagger]). Dock dan latar tidak ikut bergerak.
          Positioned.fill(
            child: PageStagger(child: KeyedSubtree(key: ValueKey(_tab), child: _page())),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14 + bottomInset,
            child: ZDock(items: _items, index: _tab, onTap: goTo),
          ),
        ],
      ),
      ),
    );
  }
}

/// Menandai halaman tab: elemen-elemen pertamanya ikut animasi naik bertahap saat halaman dibuka.
/// Halaman yang dibuka dari dalam (Profil, Tambah Transaksi) berada di luar penanda ini dan tetap meluncur.
class PageStagger extends InheritedWidget {
  const PageStagger({super.key, required super.child});

  static bool active(BuildContext context) => context.getInheritedWidgetOfExactType<PageStagger>() != null;

  @override
  bool updateShouldNotify(PageStagger oldWidget) => false;
}

/// Satu elemen halaman yang muncul naik 14 px sambil memudar, tertunda 60 ms per urutan.
/// Hanya opacity dan transform; mati kalau pengguna memilih "kurangi animasi".
class StaggerItem extends StatefulWidget {
  const StaggerItem({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  /// Jumlah elemen pertama yang dianimasikan; sisanya langsung tampil.
  static const maxItems = 7;
  static const delay = Duration(milliseconds: 60);
  static const duration = Duration(milliseconds: 450);

  @override
  State<StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<StaggerItem> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  Animation<double>? _a;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null || MediaQuery.disableAnimationsOf(context)) return;
    final lead = StaggerItem.delay * widget.index;
    final total = lead + StaggerItem.duration;
    final c = AnimationController(vsync: this, duration: total);
    _a = CurvedAnimation(
      parent: c,
      curve: Interval(lead.inMicroseconds / total.inMicroseconds, 1, curve: const Cubic(0.22, 0.8, 0.3, 1)),
    );
    _c = c..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    if (a == null) return widget.child;
    return AnimatedBuilder(
      animation: a,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: a.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 14 * (1 - a.value)), child: child),
      ),
    );
  }
}

/// Membungkus [children] dengan [StaggerItem] (7 pertama) kalau berada di halaman tab.
List<Widget> staggered(BuildContext context, List<Widget> children, {int start = 0}) {
  if (!PageStagger.active(context)) return children;
  return [
    for (var i = 0; i < children.length; i++)
      i + start < StaggerItem.maxItems ? StaggerItem(index: i + start, child: children[i]) : children[i],
  ];
}

/// Isi halaman yang bisa digulir dengan jarak aman atas dan bawah (untuk dock).
class PageScroll extends StatelessWidget {
  const PageScroll({super.key, required this.children, this.withDock = true});

  final List<Widget> children;
  final bool withDock;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, pad.top + 12, 20, pad.bottom + (withDock ? 120 : 28)),
      children: staggered(context, children),
    );
  }
}

/// Tutup pop-up lalu buka halaman pendukung.
Future<T?> pushPage<T>(BuildContext context, Widget page) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return Navigator.of(context).push<T>(slideUpRoute<T>(page));
}

/// Rute halaman pendukung: naik dari bawah sambil memudar.
Route<T> slideUpRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, anim, _, child) {
        final a = CurvedAnimation(parent: anim, curve: const Cubic(0.22, 0.8, 0.3, 1), reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a),
            child: child,
          ),
        );
      },
    );
