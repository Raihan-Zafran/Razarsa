import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../features/finance/goals_page.dart';
import '../features/finance/home_page.dart';
import '../features/finance/report_page.dart';
import '../features/finance/transactions_page.dart';
import '../features/settings/settings_page.dart';
import 'dock.dart';
import 'sky_background.dart';

/// Kerangka utama setelah masuk: latar animasi, halaman, dan dock.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  int _dir = 1;

  static const _items = [
    DockItem(Icons.home_rounded, 'Beranda'),
    DockItem(Icons.receipt_long_rounded, 'Transaksi'),
    DockItem(Icons.bar_chart_rounded, 'Laporan'),
    DockItem(Icons.flag_rounded, 'Target'),
    DockItem(Icons.settings_rounded, 'Pengaturan'),
  ];

  void goTo(int i) {
    if (i == _tab) return;
    setState(() {
      _dir = i > _tab ? 1 : -1;
      _tab = i;
    });
  }

  Widget _page() {
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
    return Scaffold(
      backgroundColor: z.bg,
      body: Stack(
        children: [
          Positioned(top: 0, left: 0, right: 0, child: SkyBackground(dark: dark)),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: const Cubic(0.22, 0.8, 0.3, 1),
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) {
                final incoming = child.key == ValueKey(_tab);
                final dx = 0.07 * _dir * (incoming ? 1 : -1);
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(key: ValueKey(_tab), child: _page()),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14 + bottomInset,
            child: ZDock(items: _items, index: _tab, onTap: goTo),
          ),
        ],
      ),
    );
  }
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
      children: children,
    );
  }
}

/// Rute halaman pendukung: naik dari bawah sambil memudar.
Route<T> slideUpRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 380),
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
