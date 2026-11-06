import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/store.dart';
import 'common.dart';

/// Tombol terang/gelap berbentuk pil bergambar pemandangan siang/malam.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key, this.width = 76, this.height = 28});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final knob = height - 6;
    const dur = Duration(milliseconds: 420);
    return Semantics(
      button: true,
      toggled: dark,
      label: dark ? tr('Ganti ke mode terang') : tr('Ganti ke mode gelap'),
      child: GestureDetector(
        onTap: () => store.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: z.border, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(Assets.toggleDay, fit: BoxFit.cover),
              AnimatedOpacity(duration: dur, opacity: dark ? 1 : 0, child: Image.asset(Assets.toggleNight, fit: BoxFit.cover)),
              AnimatedPositioned(
                duration: dur,
                curve: const Cubic(0.3, 1.4, 0.6, 1),
                top: 1,
                left: dark ? width - knob - 5 : 1,
                child: Container(
                  width: knob,
                  height: knob,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: ClipOval(
                    child: Stack(fit: StackFit.expand, children: [
                      Image.asset(Assets.knobSun, fit: BoxFit.cover),
                      AnimatedOpacity(duration: dur, opacity: dark ? 1 : 0, child: Image.asset(Assets.knobMoon, fit: BoxFit.cover)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Informasi satu mode Razarsa.
class AppMode {
  const AppMode(this.id, this.name, this.desc, this.icon, this.tone, {this.ready = true});

  final String id;
  final String name;
  final String desc;
  final IconData icon;
  final String tone;
  final bool ready;
}

List<AppMode> get kModes => [
      AppMode('finance', tr('Keuangan'), tr('Catat uang, laporan, target tabungan'), Icons.account_balance_wallet_outlined, 'green'),
      AppMode('productive', tr('Produktif'), tr('To-do, kalender, pengingat, catatan'), Icons.task_alt_rounded, 'blue'),
      AppMode('gym', 'Gym', tr('Home workout dan riwayat latihan'), Icons.fitness_center_rounded, 'orange', ready: false),
      AppMode('health', 'Health', tr('Air minum, tidur, berat badan'), Icons.favorite_border_rounded, 'pink', ready: false),
    ];

/// Tombol di kiri atas: logo + nama mode. Diketuk untuk ganti mode.
class ModeButton extends StatelessWidget {
  const ModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final m = kModes.firstWhere((m) => m.id == store.mode, orElse: () => kModes.first);
    return Semantics(
      button: true,
      label: trf('Mode {0}. Ketuk untuk ganti mode', [m.name]),
      child: Material(
        color: z.card,
        shape: StadiumBorder(side: BorderSide(color: z.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => showModeSheet(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const AppLogo(size: 26),
              const SizedBox(width: 6),
              Text(m.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: z.text),
            ]),
          ),
        ),
      ),
    );
  }
}

Future<void> showModeSheet(BuildContext context) {
  final store = StoreScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      final z = ZColors.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Pilih mode'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(tr('Pengaturan dan profil sama untuk semua mode.'), style: TextStyle(fontSize: 12.5, color: z.muted2)),
            const SizedBox(height: 14),
            for (final m in kModes) ...[
              _ModeTile(
                mode: m,
                active: m.id == store.mode,
                onTap: () {
                  if (!m.ready) {
                    showZToast(ctx, tr('Mode ini segera hadir'));
                    return;
                  }
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  store.setMode(m.id);
                },
              ),
              const SizedBox(height: 10),
            ],
          ]),
        ),
      );
    },
  );
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.mode, required this.active, required this.onTap});

  final AppMode mode;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Opacity(
      opacity: mode.ready ? 1 : 0.6,
      child: Material(
        color: active ? z['tipBg'] : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: active ? z.primary : z.border, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              IconTile(icon: mode.icon, tone: mode.tone, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(mode.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(mode.desc, style: TextStyle(fontSize: 12, color: z.muted2)),
                ]),
              ),
              Text(
                active ? tr('Aktif') : (mode.ready ? '' : tr('Segera hadir')),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: active ? z.accentText : z.muted2),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
