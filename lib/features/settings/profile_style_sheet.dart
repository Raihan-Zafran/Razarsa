import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/photo_service.dart';
import '../../data/store.dart';
import '../../widgets/profile_widgets.dart';

/// Lembar "Ubah tampilan profil": foto profil dan sampul dari galeri. Perubahan langsung berlaku.
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Center(child: ProfileAvatar(size: 128)),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(tr('Ubah tampilan profil'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          _PhotoActions(
            key: const ValueKey('avatar-photo'),
            title: tr('Foto profil'),
            hasPhoto: store.photoPath.isNotEmpty,
            busy: _busy,
            icon: Icons.add_a_photo_outlined,
            onUpload: () => _upload(store, cover: false),
            onRemove: () => store.setPhotoPath(''),
          ),
          _PhotoActions(
            key: const ValueKey('cover-photo'),
            title: tr('Cover'),
            hasPhoto: store.coverPhotoPath.isNotEmpty,
            busy: _busy,
            icon: Icons.add_photo_alternate_outlined,
            onUpload: () => _upload(store, cover: true),
            onRemove: () => store.setCoverPhotoPath(''),
          ),
          if (_photoMsg != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_photoMsg!, key: const ValueKey('photo-msg'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: z.warn)),
            ),
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

/// Judul bagian dengan tombol unggah foto dan hapus foto.
class _PhotoActions extends StatelessWidget {
  const _PhotoActions({
    super.key,
    required this.title,
    required this.hasPhoto,
    required this.busy,
    required this.icon,
    required this.onUpload,
    required this.onRemove,
  });

  final String title;
  final bool hasPhoto;
  final bool busy;
  final IconData icon;
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
          icon: Icon(icon, size: 18),
          label: Text(tr('Unggah foto')),
        ),
      ]),
    );
  }
}
