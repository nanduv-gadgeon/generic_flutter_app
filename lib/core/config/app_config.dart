import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_config.freezed.dart';
part 'app_config.g.dart';

/// Customer folder under assets/config/, chosen at build time with --dart-define=CUSTOMER=...
const customer = String.fromEnvironment('CUSTOMER', defaultValue: 'vitacare');

/// The customer config file, read once on the splash screen.
///
/// Minimal for now; the full schema (theme, features, device profiles...) comes in task 1.1.4.
@freezed
abstract class AppConfig with _$AppConfig {
  const factory AppConfig({
    required bool isCloud,
    @JsonKey(readValue: _readAppName) required String appName,
  }) = _AppConfig;

  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);

  static Future<AppConfig> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString('assets/config/$customer/app_config.json');
    return AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

Object? _readAppName(Map<dynamic, dynamic> json, String key) =>
    (json['brand'] as Map<String, dynamic>?)?['appName'];
