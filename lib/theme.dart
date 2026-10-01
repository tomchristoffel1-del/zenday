import 'package:flutter/material.dart';

/// Zurückhaltende, monochrome Palette. Kein Markenblau, keine Signalfarben –
/// nur ein einziger dezenter Akzent für "erledigt"-Zustände.
class ZenColors {
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color accent;
  final Color success;
  final Color successSoft;

  const ZenColors({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.accent,
    required this.success,
    required this.successSoft,
  });

  ZenColors copyWith({Color? accent}) => ZenColors(
        background: background,
        surface: surface,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textTertiary: textTertiary,
        divider: divider,
        accent: accent ?? this.accent,
        success: success,
        successSoft: successSoft,
      );

  static const light = ZenColors(
    background: Color(0xFFFAFAF9),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF8E8E93),
    textTertiary: Color(0xFFC7C7CC),
    divider: Color(0xFFE5E5E7),
    accent: Color(0xFF3A3A3C),
    success: Color(0xFF34C759),
    successSoft: Color(0xFFE6F8EA),
  );

  static const dark = ZenColors(
    background: Color(0xFF0B0B0C),
    surface: Color(0xFF141416),
    textPrimary: Color(0xFFF2F2F3),
    textSecondary: Color(0xFF8E8E93),
    textTertiary: Color(0xFF48484A),
    divider: Color(0xFF232325),
    accent: Color(0xFFE5E5E7),
    success: Color(0xFF30D158),
    successSoft: Color(0xFF16261A),
  );
}

class ZenTheme extends ThemeExtension<ZenTheme> {
  final ZenColors colors;
  const ZenTheme(this.colors);

  @override
  ZenTheme copyWith({ZenColors? colors}) => ZenTheme(colors ?? this.colors);

  @override
  ZenTheme lerp(ThemeExtension<ZenTheme>? other, double t) {
    if (other is! ZenTheme) return this;
    return t < 0.5 ? this : other;
  }
}

/// Nutzt die native Systemschrift statt einer gebündelten Web-Font:
/// SF Pro auf iOS/macOS, Segoe UI Variable auf Windows – jeweils bereits
/// auf dem Gerät vorhanden, kein Ladeverzug, kein Font-Flackern.
const _systemFontFallback = [
  '.SF Pro Text',
  'SF Pro Text',
  'Segoe UI Variable Text',
  'Segoe UI',
  'Roboto',
];

ThemeData buildZenTheme(ZenColors c, Brightness brightness) {
  final base = ThemeData(brightness: brightness).textTheme;
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: c.background,
    fontFamilyFallback: _systemFontFallback,
    textTheme: base.apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    dividerColor: c.divider,
    extensions: [ZenTheme(c)],
    colorScheme: brightness == Brightness.light
        ? ColorScheme.light(
            surface: c.surface,
            primary: c.accent,
            onSurface: c.textPrimary,
          )
        : ColorScheme.dark(
            surface: c.surface,
            primary: c.accent,
            onSurface: c.textPrimary,
          ),
  );
}
