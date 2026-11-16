import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../shell/desktop_page.dart';
import '../../shell/layout.dart';
import '../../widgets/common.dart';
import '../../widgets/count_up.dart';
import '../../widgets/water_jar.dart';
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
    if (isWide(context)) return _desktop(context, store, z);

    return PageScroll(children: [
      PageTitle(tr('Target Keuangan'), actions: [
        RoundIconButton(icon: Icons.add_rounded, tooltip: tr('Tambah target'), onTap: () => _addGoal(context, store)),
      ]),
      const SizedBox(height: 12),
      _GoalSummary(goals: store.goals),
      const SizedBox(height: 14),
      if (store.goals.isEmpty)
        ZCard(
          child: EmptyState(
            icon: Icons.flag_rounded,
            title: tr('Belum ada target'),
            message: tr('Contoh: dana darurat, liburan, laptop baru, atau DP rumah.'),
            action: FilledButton.icon(
              onPressed: () => _addGoal(context, store),
              icon: const Icon(Icons.add_rounded),
              label: Text(tr('Buat target'), style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      if (isWide(context) && store.goals.length > 1)
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 14) / 2;
          return Wrap(spacing: 14, runSpacing: 14, children: [
            for (final g in store.goals) SizedBox(width: w, child: _GoalCard(goal: g, icon: iconFor(g.name))),
          ]);
        })
      else
        for (final g in store.goals) ...[
          _GoalCard(goal: g, icon: iconFor(g.name)),
          const SizedBox(height: 10),
        ],
      if (isWide(context) && store.goals.length > 1) const SizedBox(height: 16),
      if (store.goals.isNotEmpty)
        Text(tr('Tap target untuk menambah atau mengurangi tabungan, tekan lama untuk mengubah atau menghapus.'),
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: z.muted2)),
    ]);
  }

  // ---------- Tampilan desktop ----------
  Widget _desktop(BuildContext context, AppStore store, ZColors z) {
    final goals = store.goals;
    final saved = goals.fold<int>(0, (t, g) => t + g.saved);
    final target = goals.fold<int>(0, (t, g) => t + g.target);
    final counted = goals.fold<int>(0, (t, g) => t + math.min(g.saved, g.target));
    final progress = target <= 0 ? 0.0 : (counted / target).clamp(0.0, 1.0);
    final done = goals.where((g) => g.saved >= g.target).length;
    final newBtn = FilledButton.icon(
      onPressed: () => _addGoal(context, store),
      icon: const Icon(Icons.add_rounded, size: 20),
      label: Text(tr('Target baru'), style: const TextStyle(fontWeight: FontWeight.w800)),
      style: FilledButton.styleFrom(backgroundColor: z.hi, foregroundColor: const Color(0xFF241A05), minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
    );
    final hero = GlassPane(
      hero: true,
      color: z.hero,
      color2: z.hero2,
      radius: 22,
      border: Border.all(color: z.heroBorder),
      padding: const EdgeInsets.fromLTRB(32, 26, 32, 26),
      child: LayoutBuilder(builder: (context, box) {
        final narrow = box.maxWidth < 700;
        final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Terkumpul dari semua target'), style: TextStyle(fontSize: 14, color: z.heroMuted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CountUp(value: saved, format: rp, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.2)),
          ),
          const SizedBox(height: 2),
          Text('${trf('dari {0}', [rp(target)])} · ${trf('{0} dari {1} tercapai', [done, goals.length])}', style: TextStyle(fontSize: 13, color: z.heroMuted)),
        ]);
        final pct = Column(crossAxisAlignment: narrow ? CrossAxisAlignment.start : CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.5, height: 1)),
          Text(tr('tercapai'), style: TextStyle(fontSize: 13, color: z.heroMuted)),
          const SizedBox(height: 14),
          newBtn,
        ]);
        final jar = WaterJar(progress: progress, width: 104, back: const Color(0x1FFFFFFF), water: z.hi, outline: const Color(0xBFFFFFFF));
        if (narrow) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [jar, const SizedBox(width: 20), Expanded(child: text)]), const SizedBox(height: 16), pct]);
        }
        return Row(children: [jar, const SizedBox(width: 36), Expanded(child: text), const SizedBox(width: 24), pct]);
      }),
    );
    return DesktopPage(
      title: tr('Target tabungan'),
      subtitle: tr('Tabung sedikit demi sedikit'),
      children: [
        hero,
        const SizedBox(height: 20),
        if (goals.isEmpty)
          DCard(
            child: EmptyState(
              icon: Icons.flag_rounded,
              title: tr('Belum ada target'),
              message: tr('Contoh: dana darurat, liburan, laptop baru, atau DP rumah.'),
              action: FilledButton.icon(onPressed: () => _addGoal(context, store), icon: const Icon(Icons.add_rounded), label: Text(tr('Buat target'))),
            ),
          )
        else
          DCols(minChild: 300, children: [for (final g in goals) _DeskGoalCard(goal: g, icon: iconFor(g.name))]),
      ],
    );
  }

  Future<void> _addGoal(BuildContext context, AppStore store) async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final ok = await showZDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Target baru')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: InputDecoration(labelText: tr('Nama target'))),
          const SizedBox(height: 8),
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsFormatter()],
            decoration: InputDecoration(labelText: tr('Jumlah yang dibutuhkan'), prefixText: '$currencySymbol '),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Simpan'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final target = parseAmount(amount.text) ?? 0;
    if (name.text.trim().isEmpty || target <= 0) {
      showZToast(context, tr('Nama dan jumlah target harus diisi'));
      return;
    }
    store.addGoal(name.text, target);
    showZToast(context, trf('Target "{0}" dibuat', [name.text.trim()]));
  }
}

/// Ringkasan semua target di bagian atas: total tabungan, cincin progres, dan dua info singkat.
class _GoalSummary extends StatelessWidget {
  const _GoalSummary({required this.goals});

  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final saved = goals.fold<int>(0, (t, g) => t + g.saved);
    final target = goals.fold<int>(0, (t, g) => t + g.target);
    final counted = goals.fold<int>(0, (t, g) => t + math.min(g.saved, g.target));
    final progress = target <= 0 ? 0.0 : (counted / target).clamp(0.0, 1.0);
    final done = goals.where((g) => g.saved >= g.target).length;
    final left = target - counted;
    final pct = '${(progress * 100).round()}%';
    Widget pill(IconData icon, String text) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: z.heroInner, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(icon, size: 15, color: z.hi),
              const SizedBox(width: 5),
              Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: z.heroMuted))),
            ]),
          ),
        );
    return Semantics(
      container: true,
      label: '${tr('Total tabungan')} ${rp(saved)}, ${tr('Progres semua target')} $pct',
      child: GlassPane(
        hero: true,
        color: z.hero,
        radius: 14,
        border: Border.all(color: z.heroBorder),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Total tabungan'), style: TextStyle(fontSize: 14, color: z.heroMuted)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: CountUp(
                      value: saved,
                      format: rp,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5, fontFeatures: [FontFeature.tabularFigures()])),
                ),
                const SizedBox(height: 2),
                Text(trf('dari {0}', [rp(target)]),
                    style: TextStyle(fontSize: 12.5, color: z.heroMuted, fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
            const SizedBox(width: 12),
            WaterJar(
              progress: progress,
              width: 62,
              back: const Color(0x1FFFFFFF),
              water: z.hi,
              outline: const Color(0xBFFFFFFF),
              label: pct,
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            pill(Icons.check_circle_rounded, trf('{0} dari {1} tercapai', [done, goals.length])),
            const SizedBox(width: 8),
            pill(Icons.flag_rounded,
                goals.isEmpty ? tr('Belum ada target') : (left > 0 ? trf('Kurang {0}', [rpShort(left)]) : tr('Semua tercapai'))),
          ]),
        ]),
      ),
    );
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
      onLongPress: () => _more(context, store),
      child: ZCard(
        radius: 11,
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            WaterJar(progress: goal.progress, width: 44, back: z.track, water: z.primary, outline: z['chipBorder']),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(goal.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(trf('{0} dari {1}', [rp(goal.saved), rp(goal.target)]),
                    style: TextStyle(fontSize: 12.5, color: z.muted2, fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
            Text(_pct(goal.progress), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: z.accentText)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Icon(done ? Icons.check_circle_outline_rounded : Icons.schedule_rounded, size: 16, color: z.accentText),
            const SizedBox(width: 6),
            Expanded(child: Text(_etaText(), style: TextStyle(fontSize: 12.5, color: z.text2, height: 1.3))),
          ]),
        ]),
      ),
    );
  }

  bool get done => goal.saved >= goal.target;

  /// "Target tercapai", atau perkiraan dari kebiasaan menabung 90 hari terakhir, atau sisa yang kurang.
  String _etaText() {
    if (done) return tr('Target tercapai');
    final eta = goal.eta(), rate = goal.monthlyRate();
    if (eta == null || rate == null) return trf('Kurang {0}', [rp(goal.target - goal.saved)]);
    return trf('Sekitar {0} jika menabung {1}/bulan', [monthYear(eta), rpShort(rate)]);
  }

  /// Ketuk / "Setor": tambah atau kurangi tabungan. Kurangi tidak boleh melebihi yang sudah ditabung.
  /// Nominal diketik dengan titik ribuan, Enter = Tambah, ada pilihan cepat; kalau kosong ada pesannya
  /// (dulu tombol Tambah diam saja tanpa nominal, dan petunjuk "100000" terlihat seperti isian).
  Future<void> _addSaving(BuildContext context, AppStore store) async {
    final ctrl = TextEditingController();
    final left = goal.target - goal.saved;
    // Positif = tambah, negatif = kurangi, null = batal.
    final v = await showZDialog<int>(
      context: context,
      builder: (c) {
        String? error;
        return StatefulBuilder(builder: (c, set) {
          final z = ZColors.of(c);
          void submit(bool add) {
            final n = parseAmount(ctrl.text);
            if (n == null || n <= 0) {
              set(() => error = tr('Isi nominal dulu'));
              return;
            }
            Navigator.pop(c, add ? n : -n);
          }

          void quick(int n) {
            final now = parseAmount(ctrl.text) ?? 0;
            final text = dots(now + n);
            ctrl.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
            set(() => error = null);
          }

          return AlertDialog(
            title: Text(trf('Setor ke {0}', [goal.name])),
            content: SizedBox(
              width: 380,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trf('Tabungan saat ini {0} · kurang {1}', [rp(goal.saved), rp(left < 0 ? 0 : left)]), style: TextStyle(fontSize: 13, color: z.muted)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsFormatter()],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  onChanged: (_) {
                    if (error != null) set(() => error = null);
                  },
                  onSubmitted: (_) => submit(true),
                  decoration: InputDecoration(prefixText: '$currencySymbol ', hintText: '0', errorText: error),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final n in const [50000, 100000, 500000, 1000000])
                    ZChip(label: '+${rpShort(n)}', selected: false, onTap: () => quick(n)),
                ]),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Batal'))),
              if (goal.saved > 0) TextButton(onPressed: () => submit(false), child: Text(tr('Kurangi'))),
              FilledButton(onPressed: () => submit(true), child: Text(tr('Tambah'))),
            ],
          );
        });
      },
    );
    if (v == null || v == 0 || !context.mounted) return;
    if (v > 0) {
      store.addToGoal(goal.id, v);
      showZToast(context, trf('{0} ditabung untuk {1}', [rp(v), goal.name]));
    } else if (store.withdrawFromGoal(goal.id, -v)) {
      showZToast(context, trf('{0} dikurangi dari {1}', [rp(-v), goal.name]));
    } else {
      showZToast(context, trf('Tidak bisa mengurangi lebih dari tabungan ({0})', [rp(goal.saved)]));
    }
  }

  /// Tekan lama: ubah target atau hapus.
  Future<void> _more(BuildContext context, AppStore store) async {
    final act = await showModalBottomSheet<String>(
      sheetAnimationStyle: kSheetAnimation,
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(tr('Ubah target'), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(c, 'edit'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: Text(tr('Hapus'), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(c, 'delete'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (act == 'edit') {
      await _edit(context, store);
    } else if (act == 'delete') {
      await _delete(context, store);
    }
  }

  Future<void> _edit(BuildContext context, AppStore store) async {
    final name = TextEditingController(text: goal.name);
    final amount = TextEditingController(text: dots(goal.target));
    final ok = await showZDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Ubah target')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: InputDecoration(labelText: tr('Nama target'))),
          const SizedBox(height: 8),
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsFormatter()],
            decoration: InputDecoration(labelText: tr('Jumlah yang dibutuhkan'), prefixText: '$currencySymbol '),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Simpan'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final target = parseAmount(amount.text);
    // Isian kosong bukan "tidak berubah": keduanya wajib diisi.
    final done = target != null && store.editGoal(goal.id, name: name.text, target: target);
    showZToast(context, done ? tr('Target diperbarui') : tr('Nama dan jumlah target harus diisi'));
  }

  Future<void> _delete(BuildContext context, AppStore store) => confirmDelete(
        context,
        goal.name,
        () => store.removeGoal(goal.id),
        title: tr('Hapus target?'),
        message: trf('Target "{0}" akan dihapus.', [goal.name]),
      );
}

/// Kartu target desktop: wadah air di kiri; nama, jumlah, persen, dan tombol Setor / hapus di kanan.
class _DeskGoalCard extends StatelessWidget {
  const _DeskGoalCard({required this.goal, required this.icon});

  final Goal goal;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final z = ZColors.of(context);
    final c = _GoalCard(goal: goal, icon: icon);
    final done = goal.saved >= goal.target;
    return DCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        WaterJar(progress: goal.progress, width: 84, back: z.track, water: z.primary, outline: z['chipBorder']),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => c._more(context, store),
              child: Row(children: [
                Icon(icon, size: 19, color: z.text2),
                const SizedBox(width: 8),
                Expanded(child: Text(goal.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800))),
              ]),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(rp(goal.saved), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
            ),
            Text(trf('dari {0}', [rp(goal.target)]), style: TextStyle(fontSize: 12, color: z.muted2)),
            const SizedBox(height: 6),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [
              Text(_pct(goal.progress), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: z.accentText)),
              Text(done ? tr('Tercapai') : trf('Kurang {0}', [rp(goal.target - goal.saved)]), style: TextStyle(fontSize: 12.5, color: z.muted)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => c._addSaving(context, store),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), side: BorderSide(color: z.primary, width: 1.6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(tr('Setor'), style: TextStyle(fontWeight: FontWeight.w800, color: z.accentText)),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: tr('Hapus'),
                child: Material(
                  color: z.track,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => c._delete(context, store),
                    child: SizedBox(width: 46, height: 40, child: Icon(Icons.delete_outline_rounded, size: 20, color: z.text2)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
