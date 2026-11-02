import 'package:flutter/material.dart';

import '../config/config_sections.dart';
import 'app_tokens.dart';

/// Neutral theme used until the customer config has loaded (the mockup's default preset).
///
/// Every theme the app shows is built by [buildTheme], so Flutter can animate between them.
const fallbackThemeConfig = ThemeConfig(
  primary: '#2563EB',
  accent: '#60A5FA',
  font: 'Inter',
  cornerRadius: 16,
  cornerRadiusSmall: 12,
  mode: ThemeModeSetting.system,
);

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

  final text = isDark ? const Color(0xFFE8EDF4) : const Color(0xFF0F172A);
  final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
    primary: isDark ? accent : primary,
    error: tokens.danger,
    surface: tokens.surface,
    onSurface: text,
  );

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(config.cornerRadius));
  final smallShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(config.cornerRadiusSmall),
  );

  final base = ThemeData(colorScheme: scheme, fontFamily: config.font);
  final label = base.textTheme.labelLarge!;

  return base.copyWith(
    scaffoldBackgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFF4F6F9),
    cardTheme: CardThemeData(shape: shape, color: tokens.surface),
    // Main actions: solid primary, 52 px tall (mockup "Log in").
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: smallShape,
        minimumSize: const Size(64, 52),
        textStyle: label.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    // Second actions: white card with a light border and normal text (mockup "Log in with Face ID").
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: smallShape,
        minimumSize: const Size(64, 52),
        backgroundColor: tokens.surface,
        foregroundColor: text,
        side: BorderSide(color: tokens.border),
        textStyle: label.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.accent,
        minimumSize: const Size(44, 44),
        textStyle: label.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: _inputTheme(tokens, scheme.primary, config.cornerRadiusSmall),
    extensions: [tokens],
  );
}

/// White, lightly bordered fields about 50 px tall; the label sits above (see `LabeledField`).
InputDecorationTheme _inputTheme(AppTokens tokens, Color focus, double radius) {
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecorationTheme(
    filled: true,
    fillColor: tokens.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    hintStyle: TextStyle(color: tokens.muted, fontSize: 16),
    border: border(tokens.border),
    enabledBorder: border(tokens.border),
    disabledBorder: border(tokens.border),
    focusedBorder: border(focus, 1.5),
    errorBorder: border(tokens.danger),
    focusedErrorBorder: border(tokens.danger, 1.5),
  );
}
