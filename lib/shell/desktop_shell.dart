import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/store.dart';
import '../features/finance/add_transaction_page.dart';
import '../features/finance/goals_page.dart';
import '../features/finance/home_page.dart';
import '../features/finance/report_page.dart';
import '../features/finance/transactions_page.dart';
import '../features/productive/calendar_page.dart';
import '../features/productive/notes_page.dart';
import '../features/productive/prod_common.dart';
import '../features/productive/prod_home_page.dart';
import '../features/productive/todo_page.dart';
import '../features/saldo/saldo_page.dart';
import '../features/settings/profile_page.dart';
import '../features/settings/settings_page.dart';
import '../widgets/common.dart';
import '../widgets/mode_widgets.dart' show ThemeToggle;
import '../widgets/profile_widgets.dart';
import 'app_shell.dart' show PageStagger, pushPage;

/// Satu tujuan di sidebar. [fin] true = grup Keuangan, false = Produktif.
class _Dest {
  const _Dest(this.icon, this.label, this.kbd, this.fin);

  final IconData icon;
  final String label;
  final String kbd;
  final bool fin;
}

List<_Dest> get _dests => [
      _Dest(Icons.home_rounded, tr('Beranda'), 'Ctrl+1', true),
      _Dest(Icons.receipt_long_rounded, tr('Transaksi'), 'Ctrl+2', true),
      _Dest(Icons.hub_rounded, tr('Saldo'), 'Ctrl+3', true),
      _Dest(Icons.bar_chart_rounded, tr('Laporan'), 'Ctrl+4', true),
      _Dest(Icons.flag_rounded, tr('Target'), 'Ctrl+5', true),
      _Dest(Icons.today_rounded, tr('Hari ini'), 'Ctrl+6', false),
      _Dest(Icons.task_alt_rounded, tr('Tugas'), 'Ctrl+7', false),
      _Dest(Icons.calendar_month_rounded, tr('Kalender'), 'Ctrl+8', false),
      _Dest(Icons.sticky_note_2_outlined, tr('Catatan'), 'Ctrl+9', false),
    ];

const _kSettings = 9;
const _itemH = 40.0, _itemGap = 3.0, _groupH = 30.0;

/// Kerangka desktop (jendela lebar): sidebar yang bisa diciutkan, bilah atas, dan isi halaman.
/// Memakai ulang halaman dan data yang sama dengan versi HP.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  int _index = 0;
  bool _rail = false;

  void _go(int i) {
    if (i == _index) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final store = StoreScope.read(context);
    if (i < _kSettings) store.setMode(_dests[i].fin ? 'finance' : 'productive');
    setState(() => _index = i);
  }

  Widget _page() {
    switch (_index) {
      case 1:
        return const TransactionsPage();
      case 2:
        return const SaldoPage(embedded: true);
      case 3:
        return const ReportPage();
      case 4:
        return const GoalsPage();
      case 5:
        return ProdHomePage(goTo: (i) => _go(5 + i));
      case 6:
        return const TodoPage();
      case 7:
        return const CalendarPage();
      case 8:
        return const NotesPage();
      case _kSettings:
        return const SettingsPage();
      default:
        return HomePage(onSeeAll: () => _go(1));
    }
  }

  void _lock() {
    final store = StoreScope.read(context);
    if (!store.pinEnabled) {
      showZToast(context, tr('Aktifkan PIN dulu'));
      return;
    }
    store.requestLock();
  }

  Future<void> _openPalette() => showCommandPalette(
        context,
        go: _go,
        toggleRail: () => setState(() => _rail = !_rail),
        lock: _lock,
      );

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final bindings = <ShortcutActivator, VoidCallback>{
      for (var i = 0; i < 9; i++)
        SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), control: true): () => _go(i),
      const SingleActivator(LogicalKeyboardKey.comma, control: true): () => _go(_kSettings),
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): _openPalette,
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): _openPalette,
      const SingleActivator(LogicalKeyboardKey.keyL, control: true): _lock,
      const SingleActivator(LogicalKeyboardKey.keyB, control: true): () => setState(() => _rail = !_rail),
    };
    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: z.bg,
          body: Row(children: [
            _Sidebar(index: _index, rail: _rail, onGo: _go, onToggleRail: () => setState(() => _rail = !_rail), onPalette: _openPalette, onLock: _lock),
            Expanded(
              child: Column(children: [
                _TopBar(onPalette: _openPalette),
                Expanded(
                  child: PageStagger(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(a), child: child),
                      ),
                      child: KeyedSubtree(key: ValueKey(_index), child: _page()),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onPalette});

  final VoidCallback onPalette;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Row(children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Semantics(
                  button: true,
                  label: tr('Cari halaman atau jalankan perintah'),
                  child: Material(
                    color: z.card,
                    shape: StadiumBorder(side: BorderSide(color: z.border)),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: onPalette,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 40,
                          child: Row(children: [
                            Icon(Icons.search_rounded, size: 19, color: z.muted2),
                            const SizedBox(width: 10),
                            Expanded(child: Text(tr('Cari halaman, transaksi, atau jalankan perintah'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: z.muted2))),
                            _Kbd('Ctrl+K', z),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          DecoratedBox(
            decoration: BoxDecoration(color: z.track, borderRadius: BorderRadius.circular(99)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.laptop_windows_rounded, size: 15, color: z.muted),
                const SizedBox(width: 6),
                Text(tr('Hanya di perangkat ini'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: z.muted)),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          const ThemeToggle(),
        ]),
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.text, this.z, {this.color});

  final String text;
  final ZColors z;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(border: Border.all(color: color ?? z.chipBorder), borderRadius: BorderRadius.circular(5)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color ?? z.muted2)),
      );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.rail, required this.onGo, required this.onToggleRail, required this.onPalette, required this.onLock});

  final int index;
  final bool rail;
  final ValueChanged<int> onGo;
  final VoidCallback onToggleRail;
  final VoidCallback onPalette;
  final VoidCallback onLock;

  /// Posisi atas tujuan ke-[i] di dalam kolom grup (untuk pil yang meluncur).
  static double _top(int i) => i < 5 ? _groupH + i * (_itemH + _itemGap) : _groupH + 5 * (_itemH + _itemGap) + 8 + _groupH + (i - 5) * (_itemH + _itemGap);

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final store = StoreScope.of(context);
    final dests = _dests;
    final name = store.userName.isEmpty ? tr('Pengguna Razarsa') : store.userName;
    final w = rail ? 76.0 : 252.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: w,
      decoration: BoxDecoration(color: z.card.withValues(alpha: 0.7), border: Border(right: BorderSide(color: z.divider))),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      // Isi memakai lebar tetap (ciut 52 / lebar 228) dan dipotong oleh wadah yang beranimasi,
      // jadi tidak pernah meluap di tengah animasi.
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          maxWidth: rail ? 52 : 228,
          child: SizedBox(width: rail ? 52 : 228, child: _content(context, z, store, dests, name, rail)),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ZColors z, AppStore store, List<_Dest> dests, String name, bool rail) {
    return ClipRect(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Profil
        Tooltip(
          message: rail ? name : '',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => pushPage(context, const ProfilePage()),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(mainAxisAlignment: rail ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                ProfileAvatar(avatarId: store.avatar, frameId: store.effectiveFrame, size: 40),
                if (!rail) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(trf('Level {0} · semua mode', [store.level]), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: z.accentText)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(value: store.xpInLevel / AppStore.xpPerLevel, minHeight: 3, backgroundColor: z.track, color: z.primary),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Buat baru
        Tooltip(
          message: rail ? tr('Buat baru') : '',
          child: Material(
            color: z.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPalette,
              child: SizedBox(
                height: 44,
                child: Row(mainAxisAlignment: rail ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                  if (!rail) const SizedBox(width: 14),
                  Icon(Icons.add_rounded, color: z.onPrimary, size: 22),
                  if (!rail) ...[
                    const SizedBox(width: 8),
                    Expanded(child: Text(tr('Buat baru'), style: TextStyle(color: z.onPrimary, fontWeight: FontWeight.w800, fontSize: 14))),
                    _Kbd('Ctrl+N', z, color: z.onPrimary.withValues(alpha: 0.7)),
                    const SizedBox(width: 10),
                  ],
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Grup navigasi dengan pil yang meluncur ke tujuan aktif.
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              height: _top(8) + _itemH,
              child: Stack(children: [
                if (index < _kSettings)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: const Cubic(0.3, 1.25, 0.5, 1),
                    top: _top(index),
                    left: 0,
                    right: 0,
                    height: _itemH,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: z.primary, borderRadius: BorderRadius.circular(11), boxShadow: [BoxShadow(color: z.primary.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6), spreadRadius: -6)]),
                    ),
                  ),
                Positioned(top: 0, left: 0, right: 0, child: _GroupLabel(tr('Keuangan'), rail)),
                Positioned(top: _groupH + 5 * (_itemH + _itemGap) + 8, left: 0, right: 0, child: _GroupLabel(tr('Produktif'), rail)),
                for (var i = 0; i < dests.length; i++)
                  Positioned(
                    top: _top(i),
                    left: 0,
                    right: 0,
                    height: _itemH,
                    child: _NavItem(dest: dests[i], active: index == i, rail: rail, onTap: () => onGo(i)),
                  ),
              ]),
            ),
          ),
        ),
        _NavItem(
          dest: _Dest(Icons.lock_rounded, tr('Kunci'), 'Ctrl+L', true),
          active: false,
          rail: rail,
          onTap: onLock,
        ),
        const SizedBox(height: 3),
        _NavItem(
          dest: _Dest(Icons.settings_rounded, tr('Pengaturan'), 'Ctrl+,', true),
          active: index == _kSettings,
          rail: rail,
          onTap: () => onGo(_kSettings),
          solid: true,
        ),
        const SizedBox(height: 3),
        _NavItem(
          dest: _Dest(rail ? Icons.menu_rounded : Icons.menu_open_rounded, tr('Ciutkan menu'), '', true),
          active: false,
          rail: rail,
          onTap: onToggleRail,
        ),
      ]),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, this.rail);

  final String text;
  final bool rail;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return SizedBox(
      height: _groupH,
      child: rail
          ? Center(child: Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 10), color: z.divider))
          : Padding(
              padding: const EdgeInsets.only(left: 10, top: 12),
              child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: z.muted2)),
            ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.dest, required this.active, required this.rail, required this.onTap, this.solid = false});

  final _Dest dest;
  final bool active;
  final bool rail;
  final VoidCallback onTap;

  /// true: latar sendiri saat aktif (item di luar kolom berpil).
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final fg = active ? z.onPrimary : z.text2;
    return Tooltip(
      message: rail ? dest.label : '',
      child: Semantics(
        button: true,
        selected: active,
        label: dest.label,
        child: Material(
          color: solid && active ? z.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            hoverColor: z.track,
            onTap: onTap,
            child: SizedBox(
              height: _itemH,
              child: Row(mainAxisAlignment: rail ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                if (!rail) const SizedBox(width: 12),
                Icon(dest.icon, size: 21, color: fg),
                if (!rail) ...[
                  const SizedBox(width: 12),
                  Expanded(child: Text(dest.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: fg))),
                  if (dest.kbd.isNotEmpty) _Kbd(dest.kbd, z, color: active ? z.onPrimary.withValues(alpha: 0.7) : null),
                  const SizedBox(width: 10),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Palet perintah (Ctrl+K / Ctrl+N)
// ---------------------------------------------------------------------------------------------

class _Cmd {
  const _Cmd(this.icon, this.label, this.hint, this.run);

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback run;
}

Future<void> showCommandPalette(BuildContext context, {required ValueChanged<int> go, required VoidCallback toggleRail, required VoidCallback lock}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (c) => _Palette(go: go, toggleRail: toggleRail, lock: lock, shellContext: context),
  );
}

class _Palette extends StatefulWidget {
  const _Palette({required this.go, required this.toggleRail, required this.lock, required this.shellContext});

  final ValueChanged<int> go;
  final VoidCallback toggleRail;
  final VoidCallback lock;
  final BuildContext shellContext;

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final _q = TextEditingController();
  int _sel = 0;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<_Cmd> _all(AppStore store) {
    final sc = widget.shellContext;
    // Tutup palet dulu, baru jalankan aksinya di konteks kerangka.
    VoidCallback run(VoidCallback f) => () {
          Navigator.of(context).pop();
          f();
        };
    final dests = _dests;
    return [
      _Cmd(Icons.south_west_rounded, tr('Catat pemasukan'), tr('Aksi'), run(() => pushPage(sc, const AddTransactionPage(income: true)))),
      _Cmd(Icons.north_east_rounded, tr('Catat pengeluaran'), tr('Aksi'), run(() => pushPage(sc, const AddTransactionPage(income: false)))),
      _Cmd(Icons.task_alt_rounded, tr('Tugas baru'), tr('Aksi'), run(() => showAddTodo(sc))),
      _Cmd(Icons.event_rounded, tr('Agenda baru'), tr('Aksi'), run(() => showAddAgenda(sc, DateTime.now()))),
      for (var i = 0; i < dests.length; i++)
        _Cmd(dests[i].icon, dests[i].label, dests[i].fin ? tr('Keuangan') : tr('Produktif'), run(() => widget.go(i))),
      _Cmd(Icons.settings_rounded, tr('Pengaturan'), tr('Halaman'), run(() => widget.go(_kSettings))),
      _Cmd(Icons.dark_mode_outlined, tr('Ganti tema terang/gelap'), tr('Tampilan'), run(() {
        final dark = Theme.of(sc).brightness == Brightness.dark;
        store.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark);
      })),
      _Cmd(Icons.lock_outline_rounded, tr('Kunci sekarang'), tr('Keamanan'), run(widget.lock)),
      _Cmd(Icons.menu_open_rounded, tr('Ciutkan atau lebarkan menu'), tr('Tampilan'), run(widget.toggleRail)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final store = StoreScope.of(context);
    final q = _q.text.trim().toLowerCase();
    var cmds = _all(store).where((c) => q.isEmpty || c.label.toLowerCase().contains(q) || c.hint.toLowerCase().contains(q)).toList();
    // Hasil transaksi (mulai 2 huruf): membuka halaman Transaksi.
    if (q.length >= 2) {
      final hits = store.txns.where((t) => t.name.toLowerCase().contains(q) || store.category(t.cat).label.toLowerCase().contains(q)).take(4);
      for (final t in hits) {
        cmds.add(_Cmd(Icons.receipt_long_rounded, t.name, '${rpSigned(t.amount)} · ${dayLabel(t.at)}', () {
          Navigator.of(context).pop();
          widget.go(1);
        }));
      }
    }
    if (_sel >= cmds.length) _sel = cmds.isEmpty ? 0 : cmds.length - 1;
    return Align(
      alignment: const Alignment(0, -0.55),
      child: Material(
        color: z.card,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 580,
          child: Focus(
            // Panah dan Esc ditangani di sini (sebelum kolom cari) supaya selalu bekerja.
            onKeyEvent: (node, e) {
              if (e is! KeyDownEvent) return KeyEventResult.ignored;
              if (e.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(context).pop();
                return KeyEventResult.handled;
              }
              if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
                setState(() => _sel = cmds.isEmpty ? 0 : (_sel + 1) % cmds.length);
                return KeyEventResult.handled;
              }
              if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
                setState(() => _sel = cmds.isEmpty ? 0 : (_sel - 1 + cmds.length) % cmds.length);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Row(children: [
                  Icon(Icons.search_rounded, color: z.muted2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _q,
                      autofocus: true,
                      onChanged: (_) => setState(() => _sel = 0),
                      onSubmitted: (_) {
                        if (cmds.isNotEmpty) cmds[_sel].run();
                      },
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(border: InputBorder.none, isCollapsed: true, hintText: tr('Cari halaman, transaksi, atau jalankan perintah'), hintStyle: TextStyle(color: z.muted2, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  _Kbd('Esc', z),
                ]),
              ),
              Divider(height: 1, color: z.divider),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: cmds.isEmpty
                    ? Padding(padding: const EdgeInsets.all(28), child: Text(tr('Tidak ada hasil'), style: TextStyle(color: z.muted2)))
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: cmds.length,
                        itemBuilder: (_, i) {
                          final c = cmds[i];
                          final on = i == _sel;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: c.run,
                            onHover: (h) {
                              if (h && _sel != i) setState(() => _sel = i);
                            },
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: on ? z.track : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                              child: Row(children: [
                                Icon(c.icon, size: 20, color: on ? z.accentText : z.text2),
                                const SizedBox(width: 12),
                                Expanded(child: Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                                Text(c.hint, style: TextStyle(fontSize: 12, color: z.muted2)),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
              Divider(height: 1, color: z.divider),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                child: Row(children: [
                  Text('↑↓ ${tr('pilih')}  ·  Enter ${tr('buka')}  ·  Esc ${tr('tutup')}', style: TextStyle(fontSize: 11.5, color: z.muted2)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
