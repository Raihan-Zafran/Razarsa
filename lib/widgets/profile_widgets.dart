import 'dart:io';

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/profile_items.dart';
import '../data/store.dart';

/// Avatar bulat dengan bingkai opsional. Bingkai digambar utuh di atas; avatar ditempatkan
/// tepat di lubang bingkai (ukuran lubang berbeda tiap bingkai).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.avatarId, this.frameId = kNoFrame, this.size = 92, this.photoPath});

  final String avatarId;
  final String frameId;
  final double size;

  /// Foto sendiri. null = ikut pengaturan profil di store; '' = paksa avatar bawaan.
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final frame = frameById(frameId);
    final avatar = kAvatars.firstWhere((a) => a.id == avatarId, orElse: () => kAvatars.first);
    final d = frame == null ? size : size * frame.hole;
    final photo = photoPath ?? context.dependOnInheritedWidgetOfExactType<StoreScope>()?.notifier?.photoPath ?? '';
    final fallback = Padding(
      padding: EdgeInsets.all(d * 0.04),
      child: Image.asset(avatar.asset, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
    );
    return Semantics(
      image: true,
      label: trf('Avatar: {0}', [avatar.label]),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: z.toneBg('green'),
              border: frame == null ? Border.all(color: z.card, width: size * 0.04) : null,
            ),
            child: ClipOval(
              child: photo.isEmpty
                  ? fallback
                  : Image.file(
                      File(photo),
                      key: ValueKey(photo),
                      width: d,
                      height: d,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => fallback, // berkas hilang (misalnya setelah pindah HP)
                    ),
            ),
          ),
          if (frame != null)
            IgnorePointer(child: Image.asset(frame.asset, width: size, height: size, fit: BoxFit.contain, filterQuality: FilterQuality.medium)),
        ]),
      ),
    );
  }
}

const _grayscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Gambar lencana. Yang masih terkunci tampil abu-abu pudar.
class BadgeImage extends StatelessWidget {
  const BadgeImage({super.key, required this.asset, this.size = 56, this.unlocked = true});

  final String asset;
  final double size;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(asset, width: size, height: size, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
    if (unlocked) return img;
    return Opacity(opacity: 0.4, child: ColorFiltered(colorFilter: _grayscale, child: img));
  }
}

/// Gambar sampul profil: foto sendiri kalau ada, kalau tidak sampul bawaan (siang, memudar ke malam).
class ProfileCover extends StatelessWidget {
  const ProfileCover({super.key, required this.coverId, required this.dark, this.photoPath});

  final String coverId;
  final bool dark;

  /// null = ikut store; '' = paksa sampul bawaan.
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final cover = kCovers.firstWhere((c) => c.id == coverId, orElse: () => kCovers.first);
    final photo = photoPath ?? context.dependOnInheritedWidgetOfExactType<StoreScope>()?.notifier?.coverPhotoPath ?? '';
    final preset = Stack(fit: StackFit.expand, children: [
      Image.asset(cover.dayAsset, fit: BoxFit.cover),
      AnimatedOpacity(
        duration: const Duration(milliseconds: 450),
        opacity: dark ? 1 : 0,
        child: Image.asset(cover.nightAsset, fit: BoxFit.cover),
      ),
    ]);
    if (photo.isEmpty) return preset;
    return Image.file(File(photo), key: ValueKey(photo), fit: BoxFit.cover, errorBuilder: (_, _, _) => preset);
  }
}
