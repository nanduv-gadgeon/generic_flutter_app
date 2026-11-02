import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/core/theme/app_tokens.dart';

import '../../fixtures/test_config.dart';

void main() {
  final config = AppConfig.fromJson(validConfigJson()).theme;

  group('parseHex', () {
    final cases = {
      '#0F766E': const Color(0xFF0F766E),
      '#ffffff': const Color(0xFFFFFFFF),
      '#000000': const Color(0xFF000000),
    };
    for (final MapEntry(key: hex, value: colour) in cases.entries) {
      test(hex, () => expect(parseHex(hex), colour));
    }
  });

  group('themeModeFor', () {
    final cases = {
      ThemeModeSetting.light: ThemeMode.light,
      ThemeModeSetting.dark: ThemeMode.dark,
      ThemeModeSetting.system: ThemeMode.system,
    };
    for (final MapEntry(key: setting, value: mode) in cases.entries) {
      test(setting.name, () => expect(themeModeFor(config.copyWith(mode: setting)), mode));
    }
  });

  group('buildTheme', () {
    test('light theme uses primary, font and radii from the config', () {
      final theme = buildTheme(config, Brightness.light);
      final tokens = theme.extension<AppTokens>()!;

      expect(theme.colorScheme.primary, const Color(0xFF123456));
      expect(theme.textTheme.bodyMedium?.fontFamily, 'TestFont');
      expect(tokens.radius, 20);
      expect(tokens.radiusSmall, 12);
      expect(tokens.ok, const Color(0xFF15803D));
    });

    test('dark theme uses the accent colour and dark tokens', () {
      final theme = buildTheme(config, Brightness.dark);
      final tokens = theme.extension<AppTokens>()!;

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, const Color(0xFFABCDEF));
      expect(tokens.ok, const Color(0xFF4ADE80));
      expect(
        tokens.surface,
        isNot(buildTheme(config, Brightness.light).extension<AppTokens>()!.surface),
      );
    });
  });

  test('AppTokens.lerp goes from one set to the other', () {
    final light = AppTokens.light(primary: Colors.teal, radius: 10, radiusSmall: 4);
    final dark = AppTokens.dark(accent: Colors.cyan, radius: 20, radiusSmall: 8);

    expect(light.lerp(dark, 0).ok, light.ok);
    expect(light.lerp(dark, 1).ok, dark.ok);
    expect(light.lerp(dark, 0.5).radius, 15);
  });
}
