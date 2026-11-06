import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../../core/i18n.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  /// Ikon ditebak dari nama target.
  static IconData iconFor(String name) {
    final n = name.toLowerCase();
    bool has(List<String> words) => words.any(n.contains);
    if (has(['darurat', 'cadangan'])) return Icons.shield_outlined;
    if (has(['libur', 'wisata', 'travel', 'jalan', 'mudik', 'umroh', 'haji'])) return Icons.flight_takeoff_rounded;
    if (has(['laptop', 'komputer', 'pc', 'hp', 'handphone', 'gadget', 'iphone', 'kamera'])) return Icons.laptop_mac_rounded;
    if (has(['rumah', 'dp', 'kos', 'apartemen'])) return Icons.home_outlined;
    if (has(['motor', 'mobil', 'kendaraan', 'sepeda'])) return Icons.two_wheeler_rounded;
    if (has(['nikah', 'menikah', 'pernikahan', 'lamaran'])) return Icons.favorite_border_rounded;
    if (has(['kuliah', 'sekolah', 'kursus', 'pendidikan'])) return Icons.school_outlined;
    return Icons.savings_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return PageScroll(children: [
      PageTitle(tr('Target Keuangan'), actions: [
        RoundIconButton(icon: Icons.add_rounded, tooltip: tr('Tambah target'), onTap: () => _addGoal(context, store)),
      ]),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 150,
          child: Stack(fit: StackFit.expand, children: [
            Container(color: z.hero),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              child: Image.asset(
                dark ? Assets.mountainNight : Assets.mountainDay,
                key: ValueKey(dark),
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                width: double.infinity,
                height: 150,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Bangun Masa Depanmu'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
                const SizedBox(height: 6),
                SizedBox(
                  width: 190,
                  child: Text(tr('Buat target, pantau progres, dan wujudkan.'),
                      style: TextStyle(fontSize: 13, color: z.heroMuted, height: 1.45)),
                ),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      if (store.goals.isEmpty)
        ZCard(
          child: EmptyState(
            title: tr('Belum ada target'),
            message: tr('Contoh: dana darurat, liburan, laptop baru, atau DP rumah.'),
            action: FilledButton.icon(
              onPressed: () => _addGoal(context, store),
              icon: const Icon(Icons.add_rounded),
              label: Text(tr('Buat target'), style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      for (final g in store.goals) ...[
        _GoalCard(goal: g, icon: iconFor(g.name)),
        const SizedBox(height: 10),
      ],
      if (store.goals.isNotEmpty)
        Text(tr('Tap target untuk menambah tabungan, tekan lama untuk menghapus.'),
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: z.muted2)),
    ]);
  }

  Future<void> _addGoal(BuildContext context, AppStore store) async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Target baru')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: InputDecoration(labelText: tr('Nama target'))),
          const SizedBox(height: 8),
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: tr('Jumlah yang dibutuhkan'), prefixText: '$currencySymbol '),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Simpan'))),
        ],
      ),
    );
    final target = int.tryParse(amount.text) ?? 0;
    if (ok == true && name.text.trim().isNotEmpty && target > 0) store.addGoal(name.text, target);
  }
}

/// 0.3333 -> "33,3%", 0.4 -> "40%"
String _pct(double p) {
  final v = (p * 1000).floor() / 10;
  return v == v.roundToDouble() ? '${v.toInt()}%' : '${v.toStringAsFixed(1).replaceAll('.', ',')}%';
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.icon});

  final Goal goal;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final z = ZColors.of(context);
    return GestureDetector(
      onTap: () => _addSaving(context, store),
      onLongPress: () => _delete(context, store),
      child: ZCard(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(children: [
          Row(children: [
            IconTile(icon: icon, tone: goal.tone, size: 40, radius: 13),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(goal.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${rp(goal.saved)} / ${rp(goal.target)}', style: TextStyle(fontSize: 12, color: z.muted2)),
                Text(goal.saved >= goal.target ? tr('Target tercapai!') : trf('Kurang {0}', [rp(goal.target - goal.saved)]),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: z.accentText)),
              ]),
            ),
            Text(_pct(goal.progress),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: z.accentText)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: goal.progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: z.track, color: z.primary),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _addSaving(BuildContext context, AppStore store) async {
    final ctrl = TextEditingController();
    final v = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(trf('Tabung untuk {0}', [goal.name])),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(prefixText: '$currencySymbol ', hintText: '100000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(c, int.tryParse(ctrl.text)), child: Text(tr('Tambah'))),
        ],
      ),
    );
    if (v != null && v > 0) {
      store.addToGoal(goal.id, v);
      if (context.mounted) showZToast(context, trf('{0} ditabung untuk {1}', [rp(v), goal.name]));
    }
  }

  Future<void> _delete(BuildContext context, AppStore store) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Hapus target?')),
        content: Text(trf('Target "{0}" akan dihapus.', [goal.name])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Hapus'))),
        ],
      ),
    );
    if (ok == true) store.removeGoal(goal.id);
  }
}
