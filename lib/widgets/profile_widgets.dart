import 'dart:io';

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/profile_items.dart';
import '../data/store.dart';

/// Avatar bulat: foto sendiri kalau ada, kalau tidak ikon orang polos di lingkaran berwarna tema.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 92, this.photoPath});

  final double size;

  /// Foto sendiri. null = ikut pengaturan profil di store; '' = paksa ikon polos.
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final photo = photoPath ?? context.dependOnInheritedWidgetOfExactType<StoreScope>()?.notifier?.photoPath ?? '';
    final fallback = Center(child: Icon(Icons.person_rounded, size: size * 0.62, color: z.primary));
    return Semantics(
      image: true,
      label: tr('Foto profil'),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: z.toneBg('green'),
          border: Border.all(color: z.card, width: size * 0.04),
        ),
        child: ClipOval(
          child: photo.isEmpty
              ? fallback
              : Image.file(
                  File(photo),
                  key: ValueKey(photo),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => fallback, // berkas hilang (misalnya setelah pindah HP)
                ),
        ),
      ),
    );
  }
}

/// Lencana pencapaian: ikon di dalam kotak. Yang masih terkunci tampil abu-abu pudar.
class BadgeIcon extends StatelessWidget {
  const BadgeIcon({super.key, required this.def, this.size = 56, this.unlocked = true});

  final BadgeDef def;
  final double size;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        color: unlocked ? z.toneBg('amber') : z.track,
      ),
      child: Icon(def.icon, size: size * 0.5, color: unlocked ? z.toneFg('amber') : z.muted2.withValues(alpha: 0.7)),
    );
  }
}

/// Sampul profil: foto sendiri kalau ada, kalau tidak gradasi polos warna tema.
class ProfileCover extends StatelessWidget {
  const ProfileCover({super.key, this.photoPath});

  /// null = ikut store; '' = paksa sampul polos.
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final photo = photoPath ?? context.dependOnInheritedWidgetOfExactType<StoreScope>()?.notifier?.coverPhotoPath ?? '';
    final plain = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [z.hero, z.hero2]),
      ),
    );
    if (photo.isEmpty) return plain;
    return Image.file(File(photo), key: ValueKey(photo), fit: BoxFit.cover, errorBuilder: (_, _, _) => plain);
  }
}

/// Tombol profil di kepala halaman HP: foto profil kalau sudah dipasang, ikon orang kalau belum.
/// Area ketuk tetap minimal 44 px.
class ProfileHeaderButton extends StatelessWidget {
  const ProfileHeaderButton({super.key, required this.onTap, this.size = 34});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final photo = context.dependOnInheritedWidgetOfExactType<StoreScope>()?.notifier?.photoPath ?? '';
    final hit = size < 44 ? 44.0 : size;
    return Tooltip(
      message: tr('Buka profil'),
      child: Semantics(
        button: true,
        label: tr('Buka profil'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: hit,
            height: hit,
            child: Center(
              child: photo.isNotEmpty
                  ? ExcludeSemantics(child: ProfileAvatar(size: size))
                  : Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(color: z.track, shape: BoxShape.circle),
                      child: Icon(Icons.person_outline_rounded, size: size * 0.55, color: z.muted),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
