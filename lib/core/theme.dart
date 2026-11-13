import 'package:flutter/material.dart';

import 'palettes.dart';

/// Semua warna Razarsa untuk mode terang dan gelap.
/// Disimpan sebagai ThemeExtension supaya pergantian mode bisa beranimasi halus.
class ZColors extends ThemeExtension<ZColors> {
  const ZColors(this.c);

  final Map<String, Color> c;

  static const light = ZColors({
    'bg': Color(0xFFF4F7F5),
    'card': Color(0xFFFFFFFF),
    'cardBorder': Color(0x00FFFFFF),
    'text': Color(0xFF111827),
    'text2': Color(0xFF374151),
    'muted': Color(0xFF4B5563),
    'muted2': Color(0xFF6B7280),
    'divider': Color(0xFFEEF2EF),
    'border': Color(0xFFE5ECE8),
    'chipBorder': Color(0xFFD1DDD5),
    'track': Color(0xFFE3EEE7),
    'accentText': Color(0xFF15803D),
    'primary': Color(0xFF15803D),
    'onPrimary': Color(0xFFFFFFFF),
    'disabledBg': Color(0xFFD7E2DB),
    'disabledFg': Color(0xFF4B5563),
    'hero': Color(0xFF0B5D33),
    'heroBorder': Color(0x000B5D33),
    'hero2': Color(0xFF0B5D33),
    'heroInner': Color(0xFF13703F),
    'heroMuted': Color(0xFFCDE9D6),
    'barMuted': Color(0xFFBBE5C8),
    'tipBg': Color(0xFFE7F6EC),
    'tipBorder': Color(0xFFBBE5C8),
    'tipTitle': Color(0xFF0B5D33),
    'tipText': Color(0xFF1F4D33),
    'warn': Color(0xFFC2410C),
    'warnBg': Color(0xFFFFF4E8),
    'warnBorder': Color(0xFFFED7AA),
    'warnTitle': Color(0xFF9A3412),
    'warnText': Color(0xFF7C2D12),
    'dashed': Color(0xFFC9D8CF),
    'dock': Color(0xFF16201B),
    'dockShadow': Color(0x4D0A2819),
    'dockMuted': Color(0xFFA3B1A9),
    'ball': Color(0xFF4ADE80),
    'ballFg': Color(0xFF052E16),
    'ballGlow': Color(0x4D4ADE80),
    'hi': Color(0xFF86EFAC),
    'pos': Color(0xFF15803D),
    'toastBg': Color(0xFF17211C),
    'toastFg': Color(0xFFFFFFFF),
    'toastAccent': Color(0xFF4ADE80),
    'greenBg': Color(0xFFDCFCE7),
    'greenFg': Color(0xFF15803D),
    'orangeBg': Color(0xFFFFEDD5),
    'orangeFg': Color(0xFFC2410C),
    'blueBg': Color(0xFFDBEAFE),
    'blueFg': Color(0xFF1D4ED8),
    'purpleBg': Color(0xFFEDE9FE),
    'purpleFg': Color(0xFF6D28D9),
    'pinkBg': Color(0xFFFCE7F3),
    'pinkFg': Color(0xFFBE185D),
    'amberBg': Color(0xFFFEF3C7),
    'amberFg': Color(0xFFB45309),
    'tealBg': Color(0xFFCCFBF1),
    'tealFg': Color(0xFF0F766E),
    'grayBg': Color(0xFFEEF2F6),
    'grayFg': Color(0xFF475569),
    // Warna donut per nada warna kategori.
    'chartgreen': Color(0xFF16A34A),
    'chartorange': Color(0xFFEA580C),
    'chartblue': Color(0xFF2563EB),
    'chartpurple': Color(0xFF7C3AED),
    'chartpink': Color(0xFFDB2777),
    'chartamber': Color(0xFFEAB308),
    'chartteal': Color(0xFF0D9488),
    'chartgray': Color(0xFF94A3B8),
  });

  static const dark = ZColors({
    'bg': Color(0xFF0A100D),
    'card': Color(0xFF131C17),
    'cardBorder': Color(0xFF1E2B24),
    'text': Color(0xFFEEF5F0),
    'text2': Color(0xFFD3DED7),
    'muted': Color(0xFFA3B4AA),
    'muted2': Color(0xFF8FA197),
    'divider': Color(0xFF1E2B24),
    'border': Color(0xFF24332B),
    'chipBorder': Color(0xFF2C3E33),
    'track': Color(0xFF1B2721),
    'accentText': Color(0xFF4ADE80),
    'primary': Color(0xFF22C55E),
    'onPrimary': Color(0xFF052E16),
    'disabledBg': Color(0xFF1F2C25),
    'disabledFg': Color(0xFF9AABA1),
    'hero': Color(0xFF0D3F26),
    'heroBorder': Color(0xFF1B6A41),
    'hero2': Color(0xFF0D3F26),
    'heroInner': Color(0xFF145234),
    'heroMuted': Color(0xFFB9DCC6),
    'barMuted': Color(0xFF1F4630),
    'tipBg': Color(0xFF0F2619),
    'tipBorder': Color(0xFF1F4A30),
    'tipTitle': Color(0xFF86EFAC),
    'tipText': Color(0xFFCDE9D6),
    'warn': Color(0xFFFB923C),
    'warnBg': Color(0xFF24160B),
    'warnBorder': Color(0xFF4A2C14),
    'warnTitle': Color(0xFFFDBA74),
    'warnText': Color(0xFFFED7AA),
    'dashed': Color(0xFF2C3E33),
    'dock': Color(0xFF1D2A23),
    'dockShadow': Color(0x8C000000),
    'dockMuted': Color(0xFF9AA8A0),
    'ball': Color(0xFF4ADE80),
    'ballFg': Color(0xFF052E16),
    'ballGlow': Color(0x4D4ADE80),
    'hi': Color(0xFF86EFAC),
    'pos': Color(0xFF4ADE80),
    'toastBg': Color(0xFFE8F2EC),
    'toastFg': Color(0xFF0A100D),
    'toastAccent': Color(0xFF15803D),
    'greenBg': Color(0xFF11301F),
    'greenFg': Color(0xFF4ADE80),
    'orangeBg': Color(0xFF33200F),
    'orangeFg': Color(0xFFFDBA74),
    'blueBg': Color(0xFF132340),
    'blueFg': Color(0xFF93C5FD),
    'purpleBg': Color(0xFF241C3D),
    'purpleFg': Color(0xFFC4B5FD),
    'pinkBg': Color(0xFF33172A),
    'pinkFg': Color(0xFFF9A8D4),
    'amberBg': Color(0xFF30260C),
    'amberFg': Color(0xFFFCD34D),
    'tealBg': Color(0xFF0E2E2B),
    'tealFg': Color(0xFF5EEAD4),
    'grayBg': Color(0xFF1E2630),
    'grayFg': Color(0xFFCBD5E1),
    'chartgreen': Color(0xFF4ADE80),
    'chartorange': Color(0xFFFB923C),
    'chartblue': Color(0xFF60A5FA),
    'chartpurple': Color(0xFFA78BFA),
    'chartpink': Color(0xFFF472B6),
    'chartamber': Color(0xFFFACC15),
    'chartteal': Color(0xFF2DD4BF),
    'chartgray': Color(0xFF64748B),
  });

  static ZColors of(BuildContext context) =>
      Theme.of(context).extension<ZColors>() ?? light;

  Color operator [](String key) => c[key] ?? const Color(0xFFFF00FF);

  Color get bg => this['bg'];
  Color get card => this['card'];
  Color get cardBorder => this['cardBorder'];
  Color get text => this['text'];
  Color get text2 => this['text2'];
  Color get muted => this['muted'];
  Color get muted2 => this['muted2'];
  Color get divider => this['divider'];
  Color get border => this['border'];
  Color get chipBorder => this['chipBorder'];
  Color get track => this['track'];
  Color get accentText => this['accentText'];
  Color get primary => this['primary'];
  Color get onPrimary => this['onPrimary'];
  Color get hero => this['hero'];
  Color get heroBorder => this['heroBorder'];
  Color get heroInner => this['heroInner'];
  Color get heroMuted => this['heroMuted'];
  Color get hero2 => this['hero2'];
  Color get hi => this['hi'];
  Color get pos => this['pos'];
  Color get warn => this['warn'];

  /// Latar dan warna ikon untuk satu nada warna (green, orange, blue, ...).
  Color toneBg(String tone) => this['${tone}Bg'];
  Color toneFg(String tone) => this['${tone}Fg'];
  Color chart(String tone) => this['chart$tone'];

  @override
  ZColors copyWith({Map<String, Color>? c}) => ZColors(c ?? this.c);

  @override
  ZColors lerp(ThemeExtension<ZColors>? other, double t) {
    if (other is! ZColors) return this;
    return ZColors({
      for (final k in c.keys) k: Color.lerp(c[k], other.c[k], t) ?? c[k]!,
    });
  }
}

const kFont = 'PlusJakartaSans';

/// Warna untuk satu mode dan palet: warna dasar, lalu ditimpa oleh palet yang dipilih.
ZColors zColorsFor(Brightness brightness, int palette) {
  final base = brightness == Brightness.dark ? ZColors.dark : ZColors.light;
  final p = kPalettes[clampPalette(palette)];
  final over = brightness == Brightness.dark ? p.dark : p.light;
  if (over.isEmpty) return base;
  return ZColors({...base.c, for (final e in over.entries) if (base.c.containsKey(e.key)) e.key: e.value});
}

ThemeData buildTheme(Brightness brightness, {int palette = kDefaultPalette}) {
  final z = zColorsFor(brightness, palette);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: kFont,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF15803D),
      brightness: brightness,
      primary: z.primary,
      onPrimary: z.onPrimary,
      surface: z.card,
    ),
    scaffoldBackgroundColor: z.bg,
    extensions: [z],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: z.text, displayColor: z.text),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: z['toastBg'],
      contentTextStyle: TextStyle(
        fontFamily: kFont,
        color: z['toastFg'],
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: z['toastAccent'],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: z.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: z.card,
      showDragHandle: true,
    ),
  );
}
