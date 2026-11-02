import 'package:freezed_annotation/freezed_annotation.dart';

import 'config_sections.dart';

export 'config_sections.dart';

part 'app_config.freezed.dart';
part 'app_config.g.dart';

/// Customer folder under assets/config/, chosen at build time with --dart-define=CUSTOMER=...
const customer = String.fromEnvironment('CUSTOMER', defaultValue: 'vitacare');

/// The customer config file, read once on the splash screen by [ConfigLoader].
///
/// `deviceProfiles` is checked by the schema but modelled in task 1.2.3 (profile registry).
@freezed
abstract class AppConfig with _$AppConfig {
  const factory AppConfig({
    required bool isCloud,
    required BrandConfig brand,
    required ThemeConfig theme,
    required FeaturesConfig features,
    required HistoryConfig history,
    required List<String> deviceTypes,

    /// Only used when [isCloud] is true; dropped otherwise so Phase 1 never sees it.
    @JsonKey(readValue: _readCloud) CloudConfig? cloud,
  }) = _AppConfig;

  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);
}

Object? _readCloud(Map<dynamic, dynamic> json, String key) =>
    json['isCloud'] == true ? json[key] : null;
