import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/photo_service.dart';
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

  /// Pesan hasil unggah foto (gagal / terlalu besar). Ditampilkan di dalam lembar, bukan toast.
  String? _photoMsg;
  bool _busy = false;

  Future<void> _upload(AppStore store, {required bool cover}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _photoMsg = null;
    });
    final r = await PhotoService.pick(kind: cover ? 'cover' : 'avatar', size: cover ? PhotoService.coverSize : PhotoService.avatarSize);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _photoMsg = switch (r.error) {
        'big' => tr('Foto terlalu besar, maksimal 10 MB'),
        'bad' => tr('Format foto tidak didukung. Pakai JPG atau PNG.'),
        _ => null,
      };
    });
    final path = r.path;
    if (path == null) return;
    cover ? store.setCoverPhotoPath(path) : store.setPhotoPath(path);
  }

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
          _PhotoActions(
            key: const ValueKey('avatar-photo'),
            title: tr('Avatar'),
            hasPhoto: store.photoPath.isNotEmpty,
            busy: _busy,
            onUpload: () => _upload(store, cover: false),
            onRemove: () => store.setPhotoPath(''),
          ),
          if (_photoMsg != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_photoMsg!, key: const ValueKey('photo-msg'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: z.warn)),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final a in kAvatars)
              _Choice(
                key: ValueKey('avatar-${a.id}'),
                selected: store.photoPath.isEmpty && store.avatar == a.id,
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
          _PhotoActions(
            key: const ValueKey('cover-photo'),
            title: tr('Cover'),
            hasPhoto: store.coverPhotoPath.isNotEmpty,
            busy: _busy,
            onUpload: () => _upload(store, cover: true),
            onRemove: () => store.setCoverPhotoPath(''),
          ),
          const SizedBox(height: 10),
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
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: store.coverPhotoPath.isEmpty && store.cover == c.id ? z.primary : z.cardBorder, width: store.coverPhotoPath.isEmpty && store.cover == c.id ? 3 : 1),
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

/// Judul bagian (Avatar / Cover) dengan tombol unggah foto sendiri dan hapus foto.
class _PhotoActions extends StatelessWidget {
  const _PhotoActions({super.key, required this.title, required this.hasPhoto, required this.busy, required this.onUpload, required this.onRemove});

  final String title;
  final bool hasPhoto;
  final bool busy;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(children: [
        Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: z.muted))),
        if (hasPhoto)
          TextButton.icon(
            onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(tr('Hapus foto')),
          ),
        OutlinedButton.icon(
          onPressed: busy ? null : onUpload,
          icon: Icon(title == tr('Cover') ? Icons.add_photo_alternate_outlined : Icons.add_a_photo_outlined, size: 18),
          label: Text(tr('Unggah foto')),
        ),
      ]),
    );
  }
}
