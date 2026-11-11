import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/profile_items.dart';
import '../../data/store.dart';
import '../../widgets/profile_widgets.dart';

/// Lembar "Ubah tampilan profil": avatar, bingkai, dan cover. Perubahan langsung berlaku.
Future<void> showProfileStyleSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const ProfileStyleSheet(),
  );
}

class ProfileStyleSheet extends StatefulWidget {
  const ProfileStyleSheet({super.key});

  @override
  State<ProfileStyleSheet> createState() => _ProfileStyleSheetState();
}

class _ProfileStyleSheetState extends State<ProfileStyleSheet> {
  /// Petunjuk bingkai terkunci. Ditampilkan di dalam lembar (toast akan tertutup lembar ini).
  String? _hint;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final frame = store.effectiveFrame;

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 10),
          child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: z.muted)),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: ProfileAvatar(avatarId: store.avatar, frameId: frame, size: 128)),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(tr('Ubah tampilan profil'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          label(tr('Avatar')),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final a in kAvatars)
              _Choice(
                key: ValueKey('avatar-${a.id}'),
                selected: store.avatar == a.id,
                semantics: a.label,
                onTap: () => store.setAvatar(a.id),
                child: Padding(padding: const EdgeInsets.all(4), child: Image.asset(a.asset, fit: BoxFit.contain)),
              ),
          ]),
          label(tr('Bingkai')),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _Choice(
              key: const ValueKey('frame-none'),
              selected: store.frame == kNoFrame,
              semantics: tr('Tanpa bingkai'),
              onTap: () => store.setFrame(kNoFrame),
              child: Icon(Icons.block_rounded, color: z.muted2),
            ),
            for (final f in kFrames)
              _Choice(
                key: ValueKey('frame-${f.id}'),
                selected: store.frame == f.id && store.frameUnlocked(f.id),
                semantics: f.label,
                locked: !store.frameUnlocked(f.id),
                caption: store.frameUnlocked(f.id) ? f.label : trf('Level {0}', [f.unlockLevel]),
                onTap: () {
                  setState(() => _hint = store.setFrame(f.id) ? null : trf('Bingkai {0} terbuka di Level {1}', [f.label, f.unlockLevel]));
                },
                plain: true,
                child: ProfileAvatar(avatarId: store.avatar, frameId: f.id, size: 64),
              ),
          ]),
          if (_hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: z.muted2),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_hint!, key: const ValueKey('frame-hint'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: z.muted2)),
                ),
              ]),
            ),
          label(tr('Cover')),
          Row(children: [
            for (final c in kCovers) ...[
              Expanded(
                child: GestureDetector(
                  key: ValueKey('cover-${c.id}'),
                  onTap: () => store.setCover(c.id),
                  child: Semantics(
                    button: true,
                    selected: store.cover == c.id,
                    label: trf('Cover {0}', [c.label]),
                    child: Column(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 64,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: store.cover == c.id ? z.primary : z.cardBorder, width: store.cover == c.id ? 3 : 1),
                        ),
                        child: Image.asset(dark ? c.nightAsset : c.dayAsset, fit: BoxFit.cover, width: double.infinity),
                      ),
                      const SizedBox(height: 6),
                      Text(c.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: store.cover == c.id ? z.accentText : z.muted)),
                    ]),
                  ),
                ),
              ),
              if (c != kCovers.last) const SizedBox(width: 12),
            ],
          ]),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('Selesai'))),
          ),
        ]),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.selected,
    required this.semantics,
    required this.onTap,
    required this.child,
    this.locked = false,
    this.caption,
    this.plain = false,
  });

  final bool selected;
  final String semantics;
  final VoidCallback onTap;
  final Widget child;
  final bool locked;
  final String? caption;

  /// true: [child] sudah punya bentuk sendiri (tanpa lingkaran latar).
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: locked ? '$semantics, ${tr('terkunci')}' : semantics,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(children: [
            Stack(alignment: Alignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: plain ? Colors.transparent : z.toneBg('green'),
                  border: Border.all(color: selected ? z.primary : (plain ? Colors.transparent : z.cardBorder), width: selected ? 3 : 1),
                ),
                child: ClipOval(child: Opacity(opacity: locked ? 0.4 : 1, child: Center(child: child))),
              ),
              if (locked) Icon(Icons.lock_rounded, size: 20, color: z.muted),
            ]),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: locked ? z.muted2 : z.text2)),
            ],
          ]),
        ),
      ),
    );
  }
}
