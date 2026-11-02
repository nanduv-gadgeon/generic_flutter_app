import 'package:flutter/material.dart';

import '../config/config_sections.dart';
import 'app_tokens.dart';

/// Parses a `#RRGGBB` config colour. The schema guarantees the format.
Color parseHex(String hex) => Color(int.parse('FF${hex.substring(1)}', radix: 16));

ThemeMode themeModeFor(ThemeConfig config) => switch (config.mode) {
  ThemeModeSetting.light => ThemeMode.light,
  ThemeModeSetting.dark => ThemeMode.dark,
  ThemeModeSetting.system => ThemeMode.system,
};

/// Builds the app theme for one brightness from the config `theme` block.
///
/// Light mode uses `primary`; dark mode uses the lighter `accent`, as in the mockup.
ThemeData buildTheme(ThemeConfig config, Brightness brightness) {
  final primary = parseHex(config.primary);
  final accent = parseHex(config.accent);
  final isDark = brightness == Brightness.dark;
  final tokens = isDark
      ? AppTokens.dark(
          accent: accent,
          radius: config.cornerRadius,
          radiusSmall: config.cornerRadiusSmall,
        )
      : AppTokens.light(
          primary: primary,
          radius: config.cornerRadius,
          radiusSmall: config.cornerRadiusSmall,
        );

  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
  ).copyWith(primary: isDark ? accent : primary, error: tokens.danger, surface: tokens.surface);

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(config.cornerRadius));
  final smallRadius = BorderRadius.circular(config.cornerRadiusSmall);

  return ThemeData(
    colorScheme: scheme,
    fontFamily: config.font,
    scaffoldBackgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFF4F6F9),
    cardTheme: CardThemeData(shape: shape, color: tokens.surface),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: smallRadius)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: smallRadius)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: smallRadius),
    ),
    extensions: [tokens],
  );
}
