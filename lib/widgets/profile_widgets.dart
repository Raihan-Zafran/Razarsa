import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/profile_items.dart';

/// Avatar bulat dengan bingkai opsional. Bingkai digambar utuh di atas; avatar ditempatkan
/// tepat di lubang bingkai (ukuran lubang berbeda tiap bingkai).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.avatarId, this.frameId = kNoFrame, this.size = 92});

  final String avatarId;
  final String frameId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final frame = frameById(frameId);
    final avatar = kAvatars.firstWhere((a) => a.id == avatarId, orElse: () => kAvatars.first);
    final d = frame == null ? size : size * frame.hole;
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
              child: Padding(
                padding: EdgeInsets.all(d * 0.04),
                child: Image.asset(avatar.asset, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
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
