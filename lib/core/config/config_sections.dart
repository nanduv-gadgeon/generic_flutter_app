import 'package:freezed_annotation/freezed_annotation.dart';

part 'config_sections.freezed.dart';
part 'config_sections.g.dart';

/// `brand` block: names and logo shown on splash, login and profile.
@freezed
abstract class BrandConfig with _$BrandConfig {
  const factory BrandConfig({
    required String appName,

    /// Coloured logo tile shown on login and profile.
    required String logoMark,

    /// Logo for the splash screen (drawn on the primary colour).
    required String logoSplash,
    required String initials,
    String? tagline,
  }) = _BrandConfig;

  factory BrandConfig.fromJson(Map<String, dynamic> json) => _$BrandConfigFromJson(json);
}

enum ThemeModeSetting { light, dark, system }

/// `theme` block. Colours stay as `#RRGGBB` strings here; `core/theme` turns them into colours.
@freezed
abstract class ThemeConfig with _$ThemeConfig {
  const factory ThemeConfig({
    required String primary,
    required String accent,
    required String font,
    required double cornerRadius,
    required double cornerRadiusSmall,
    required ThemeModeSetting mode,
  }) = _ThemeConfig;

  factory ThemeConfig.fromJson(Map<String, dynamic> json) => _$ThemeConfigFromJson(json);
}

/// `features` block: switches parts of the app on or off for a customer.
@freezed
abstract class FeaturesConfig with _$FeaturesConfig {
  const factory FeaturesConfig({
    required bool registration,
    required bool faceIdLogin,
    required bool history,
    required bool export,
    required bool alerts,
  }) = _FeaturesConfig;

  factory FeaturesConfig.fromJson(Map<String, dynamic> json) => _$FeaturesConfigFromJson(json);
}

/// `history` block.
@freezed
abstract class HistoryConfig with _$HistoryConfig {
  const factory HistoryConfig({required int daysOnPhone}) = _HistoryConfig;

  factory HistoryConfig.fromJson(Map<String, dynamic> json) => _$HistoryConfigFromJson(json);
}

enum CloudEnvironment { dev, staging, prod }

enum UploaderKind { cppLibrary, flutterModule }

/// `cloud` block. Read only when `isCloud` is true (Phase 2).
@freezed
abstract class CloudConfig with _$CloudConfig {
  const factory CloudConfig({
    required String baseUrl,
    required CloudEnvironment environment,
    required UploaderKind uploader,
    required String autoSyncDefault,
  }) = _CloudConfig;

  factory CloudConfig.fromJson(Map<String, dynamic> json) => _$CloudConfigFromJson(json);
}
