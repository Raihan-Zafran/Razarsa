import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/i18n.dart';
import '../core/theme.dart';

/// Jendela Windows memakai bingkai sendiri (seperti prototipe): judul jendela bawaan disembunyikan,
/// bilah atas aplikasi menjadi tempat menyeret jendela dan tombol minimize / maximize / tutup.
bool get customWindowFrame => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// Dipanggil sekali sebelum runApp. Ukuran awal 1440x900 (ukuran prototipe); kalau layar lebih kecil
/// (misalnya laptop 14" dengan skala 125%), jendela langsung dimaksimalkan supaya tidak keluar layar.
Future<void> initWindow() async {
  if (!customWindowFrame) return;
  try {
    await windowManager.ensureInitialized();
    final displays = ui.PlatformDispatcher.instance.displays;
    final screen = displays.isEmpty ? Size.zero : displays.first.size / displays.first.devicePixelRatio;
    final fits = screen.width >= 1500 && screen.height >= 960;
    final options = WindowOptions(
      size: fits ? const Size(1440, 900) : null,
      minimumSize: const Size(900, 600),
      center: true,
      title: 'Razarsa',
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (!fits) await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e) {
    debugPrint('Razarsa: bingkai jendela tidak bisa diatur: $e');
    // Runner tidak menampilkan jendela sendiri (lihat windows/runner/flutter_window.cpp), jadi tetap tampilkan.
    try {
      await windowManager.show();
    } catch (_) {}
  }
}

/// Area kosong yang bisa diseret untuk memindahkan jendela; klik dua kali = maksimalkan / pulihkan.
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => customWindowFrame ? DragToMoveArea(child: child) : child;
}

/// Tombol minimize / maximize-pulihkan / tutup di ujung kanan bilah atas. Tidak tampil di luar Windows.
class WindowButtons extends StatefulWidget {
  const WindowButtons({super.key, this.height = 48});

  final double height;

  @override
  State<WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<WindowButtons> with WindowListener {
  bool _max = false;

  @override
  void initState() {
    super.initState();
    if (!customWindowFrame) return;
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _max = v);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    if (customWindowFrame) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _max = true);

  @override
  void onWindowUnmaximize() => setState(() => _max = false);

  @override
  Widget build(BuildContext context) {
    if (!customWindowFrame) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _CaptionButton(icon: Icons.remove_rounded, label: tr('Perkecil'), height: widget.height, onTap: () => windowManager.minimize()),
      _CaptionButton(
        icon: _max ? Icons.filter_none_rounded : Icons.crop_square_rounded,
        iconSize: _max ? 15 : 17,
        label: _max ? tr('Pulihkan') : tr('Maksimalkan'),
        height: widget.height,
        onTap: () => _max ? windowManager.unmaximize() : windowManager.maximize(),
      ),
      _CaptionButton(icon: Icons.close_rounded, label: tr('Tutup'), height: widget.height, close: true, onTap: () => windowManager.close()),
    ]);
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({required this.icon, required this.label, required this.height, required this.onTap, this.close = false, this.iconSize = 18});

  final IconData icon;
  final String label;
  final double height;
  final double iconSize;
  final VoidCallback onTap;
  final bool close;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final bg = _hover ? (widget.close ? const Color(0xFFC42B1C) : z.track) : Colors.transparent;
    final fg = _hover && widget.close ? Colors.white : z.text2;
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 46,
            height: widget.height,
            color: bg,
            alignment: Alignment.center,
            child: Icon(widget.icon, size: widget.iconSize, color: fg),
          ),
        ),
      ),
    );
  }
}

/// Untuk layar tanpa bilah atas aplikasi (sambutan, kunci): jalur seret di atas dan tombol jendela di kanan.
class WindowCaptionOverlay extends StatelessWidget {
  const WindowCaptionOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    if (!customWindowFrame) return const SizedBox.shrink();
    return const SizedBox(
      height: 40,
      child: Row(children: [
        Expanded(child: WindowDragArea(child: SizedBox.expand())),
        WindowButtons(height: 40),
      ]),
    );
  }
}
