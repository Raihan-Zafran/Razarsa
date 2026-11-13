import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/profile_items.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../../widgets/mode_widgets.dart';
import '../../widgets/profile_widgets.dart';
import 'profile_share.dart';
import 'profile_style_sheet.dart';

/// Profil berlaku untuk semua mode: statistik umum, level, pencapaian, ringkasan tiap mode.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = store.userName.isEmpty ? tr('Pengguna Razarsa') : store.userName;
    final joined = DateTime.tryParse(store.joinedAt);
    const ticks = 20;
    final filled = (store.xpInLevel / AppStore.xpPerLevel * ticks).round();
    const tickColors = [0xFF4ADE80, 0xFF4ADE80, 0xFF86EFAC, 0xFF86EFAC, 0xFFBEF264, 0xFFBEF264, 0xFFFDE047, 0xFFFDE047, 0xFFFBBF24, 0xFFFBBF24];

    final badges = [for (final b in kBadges) (b, b.check(store))];
    final unlocked = badges.where((b) => b.$2).length;
    final cover = kCovers.firstWhere((c) => c.id == store.cover, orElse: () => kCovers.first);
    final open = store.todayTodos;

    return Scaffold(
      backgroundColor: z.bg,
      body: PageScroll(withDock: false, children: [
        PageTitle(tr('Profil'), onBack: () => Navigator.of(context).pop(), actions: const [ThemeToggle()]),
        const SizedBox(height: 12),
        // Kartu profil
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: z.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: z.cardBorder),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.35 : 0.07), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 128,
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(cover.dayAsset, fit: BoxFit.cover),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 450),
                  opacity: dark ? 1 : 0,
                  child: Image.asset(cover.nightAsset, fit: BoxFit.cover),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Semantics(
                      button: true,
                      label: tr('Ganti avatar'),
                      child: GestureDetector(
                        onTap: () => showProfileStyleSheet(context),
                        child: Stack(clipBehavior: Clip.none, children: [
                          ProfileAvatar(avatarId: store.avatar, frameId: store.effectiveFrame, size: 104),
                          Positioned(
                            right: 0,
                            bottom: 4,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(color: z.primary, shape: BoxShape.circle, border: Border.all(color: z.card, width: 3)),
                              child: Icon(Icons.edit_rounded, size: 14, color: z.onPrimary),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(trf('Level {0} · semua mode', [store.level]),
                                    maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: z.accentText)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${store.xpInLevel} / ${AppStore.xpPerLevel} XP', style: TextStyle(fontSize: 11, color: z.muted2)),
                          ]),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 14,
                            child: Row(children: [
                              for (var i = 0; i < ticks; i++)
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: i < filled ? Color(tickColors[i % tickColors.length]) : z.track,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
                Transform.translate(
                  offset: const Offset(0, -26),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text(
                      joined == null ? tr('Akun lokal') : trf('Akun lokal · bergabung {0}', ['${monthShort(joined)} ${joined.year}']),
                      style: TextStyle(fontSize: 12.5, color: z.muted2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      store.bio.isEmpty ? tr('Belum ada bio. Ceritakan sedikit tentang dirimu dan tujuanmu di Razarsa.') : store.bio,
                      style: TextStyle(fontSize: 13.5, height: 1.5, color: z.muted),
                    ),
                  ]),
                ),
              ]),
            ),
            Container(height: 1, color: z.divider),
            IntrinsicHeight(
              child: Row(children: [
                _Stat(value: '${store.activeDays.length}', label: tr('Hari aktif')),
                VerticalDivider(width: 1, color: z.divider),
                _Stat(value: '${store.streak}', label: tr('Hari beruntun')),
                VerticalDivider(width: 1, color: z.divider),
                _Stat(value: '${store.totalActivity}', label: tr('Total aktivitas')),
              ]),
            ),
            Container(
              color: z.bg,
              child: IntrinsicHeight(
                child: Row(children: [
                  _Action(icon: Icons.edit_outlined, label: tr('Edit bio'), onTap: () => _editBio(context, store)),
                  VerticalDivider(width: 1, color: z.divider),
                  _Action(icon: Icons.face_retouching_natural_rounded, label: tr('Tampilan'), onTap: () => showProfileStyleSheet(context)),
                  VerticalDivider(width: 1, color: z.divider),
                  _Action(icon: Icons.ios_share_rounded, label: tr('Bagikan'), onTap: () => shareProfile(context, store)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        SectionTitle(tr('Pencapaian'), trailing: Text(trf('{0} dari {1}', [unlocked, badges.length]), style: TextStyle(fontSize: 12, color: z.muted2))),
        const SizedBox(height: 10),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Tinggi kartu mengikuti ukuran font sistem supaya nama lencana tidak terpotong.
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: scaledHeight(context, 114),
          ),
          children: [
            for (final (b, on) in badges) _Badge(def: b, on: on),
          ],
        ),
        const SizedBox(height: 22),
        SectionTitle(tr('Ringkasan per Mode')),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            for (final m in kModes)
              _ModeSummary(
                mode: m,
                value: switch (m.id) {
                  'finance' => store.hideBalance ? rpHidden : trf('Saldo {0}', [rp(store.balance)]),
                  'productive' => trf('{0} dari {1} tugas hari ini', [open.where((t) => t.done).length, open.length]),
                  _ => tr('Segera hadir'),
                },
              ),
          ],
        ),
      ]),
    );
  }

  Future<void> _editBio(BuildContext context, AppStore store) async {
    final c = TextEditingController(text: store.bio);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Edit bio')),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: tr('Contoh: Mahasiswa yang lagi belajar hemat')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Batal'))),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(tr('Simpan'))),
        ],
      ),
    );
    if (v != null) store.setBio(v);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: z.muted2)),
        ]),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 17),
            const SizedBox(width: 6),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.def, required this.on});

  final BadgeDef def;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final hint = kBadgeHints[def.id];
    return Semantics(
      button: true,
      label: on ? def.label : '${def.label}, ${tr('terkunci')}',
      child: GestureDetector(
        onTap: () => showZToast(context, on ? trf('{0} sudah kamu dapatkan', [def.label]) : tr(hint ?? def.label)),
        child: ZCard(
          radius: 11,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(children: [
            Stack(alignment: Alignment.center, children: [
              BadgeImage(asset: def.asset, size: 52, unlocked: on),
              if (!on) Icon(Icons.lock_rounded, size: 18, color: z.muted),
            ]),
            const SizedBox(height: 6),
            Text(def.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.2, color: on ? z.text : z.muted2)),
          ]),
        ),
      ),
    );
  }
}

class _ModeSummary extends StatelessWidget {
  const _ModeSummary({required this.mode, required this.value});

  final AppMode mode;
  final String value;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Opacity(
      opacity: mode.ready ? 1 : 0.65,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: z.toneBg(mode.tone), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: z.card, borderRadius: BorderRadius.circular(8)),
            child: Icon(mode.icon, size: 19, color: z.toneFg(mode.tone)),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mode.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: z.text)),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: z.text2)),
          ]),
        ]),
      ),
    );
  }
}
