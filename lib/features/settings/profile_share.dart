import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/i18n.dart';
import '../../data/profile_items.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';
import '../../widgets/profile_widgets.dart';

/// Kartu profil yang dibagikan sebagai gambar. SENGAJA tanpa nominal uang atau data keuangan apa pun:
/// hanya nama, level, kemajuan, statistik pemakaian, dan lencana yang sudah terbuka.
class ProfileShareCard extends StatelessWidget {
  const ProfileShareCard({super.key, required this.store, required this.dark});

  final AppStore store;
  final bool dark;

  static const width = 360.0;
  static const height = 450.0;

  @override
  Widget build(BuildContext context) {
    final cover = kCovers.firstWhere((c) => c.id == store.cover, orElse: () => kCovers.first);
    final bg = dark ? const Color(0xFF111A15) : Colors.white;
    final ink = dark ? Colors.white : const Color(0xFF14211A);
    final muted = dark ? const Color(0xFFA8B8AE) : const Color(0xFF5B6B62);
    final name = store.userName.isEmpty ? tr('Pengguna Razarsa') : store.userName;
    final unlocked = kBadges.where((b) => b.check(store)).take(5).toList();
    const ticks = 20;
    final filled = (store.xpInLevel / AppStore.xpPerLevel * ticks).round();

    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: muted)),
          ]),
        );

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(children: [
              Positioned(top: 0, left: 0, right: 0, height: 130, child: Image.asset(dark ? cover.nightAsset : cover.dayAsset, fit: BoxFit.cover)),
              Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: Center(child: ProfileAvatar(avatarId: store.avatar, frameId: store.effectiveFrame, size: 120)),
              ),
              Positioned(
                top: 196,
                left: 20,
                right: 20,
                child: Column(children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
                  const SizedBox(height: 4),
                  Text(trf('Level {0} · {1} XP', [store.level, store.xp]), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: muted)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 10,
                    child: Row(children: [
                      for (var i = 0; i < ticks; i++)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: i < filled ? const Color(0xFF4ADE80) : (dark ? const Color(0xFF26352C) : const Color(0xFFE4EBE6)),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    stat('${store.activeDays.length}', tr('Hari aktif')),
                    stat('${store.streak}', tr('Hari beruntun')),
                    stat('${store.totalActivity}', tr('Total aktivitas')),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 48,
                    child: unlocked.isEmpty
                        ? Center(child: Text(tr('Baru mulai petualangan'), style: TextStyle(fontSize: 12, color: muted)))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            for (final b in unlocked)
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: BadgeImage(asset: b.asset, size: 44)),
                          ]),
                  ),
                ]),
              ),
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Image.asset(Assets.logo, width: 18, height: 18),
                  const SizedBox(width: 6),
                  Text('razarsa', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: ink)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Aset gambar yang dipakai kartu (dimuat dulu supaya tidak kosong saat difoto).
List<String> shareCardAssets(AppStore store) {
  final cover = kCovers.firstWhere((c) => c.id == store.cover, orElse: () => kCovers.first);
  return [
    cover.dayAsset,
    cover.nightAsset,
    kAvatars.firstWhere((a) => a.id == store.avatar, orElse: () => kAvatars.first).asset,
    if (frameById(store.effectiveFrame) != null) frameById(store.effectiveFrame)!.asset,
    for (final b in kBadges.where((b) => b.check(store)).take(5)) b.asset,
    Assets.logo,
  ];
}

/// Memotret kartu menjadi PNG (3x) lewat overlay di luar layar.
Future<Uint8List?> renderProfileCard(BuildContext context, AppStore store, {required bool dark}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -4000,
      top: 0,
      child: RepaintBoundary(
        key: key,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: ProfileShareCard(store: store, dark: dark),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    for (final a in shareCardAssets(store)) {
      if (!context.mounted) return null;
      await precacheImage(AssetImage(a), context);
    }
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}

/// Membuat kartu lalu membuka menu Bagikan sistem.
Future<void> shareProfile(BuildContext context, AppStore store) async {
  final dark = Theme.of(context).brightness == Brightness.dark;
  try {
    final bytes = await renderProfileCard(context, store, dark: dark);
    if (bytes == null) {
      if (context.mounted) showZToast(context, tr('Gagal membuat kartu profil'));
      return;
    }
    await SharePlus.instance.share(ShareParams(
      text: tr('Profil Razarsa-ku'),
      files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'razarsa-profil.png')],
      fileNameOverrides: const ['razarsa-profil.png'],
    ));
  } catch (e) {
    debugPrint('Razarsa: gagal membagikan profil: $e');
    if (context.mounted) showZToast(context, tr('Gagal membuat kartu profil'));
  }
}
