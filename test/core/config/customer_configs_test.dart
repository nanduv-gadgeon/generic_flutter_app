import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/config_loader.dart';
import 'package:generic_flutter_app/core/config/device_profile_registry.dart';

import '../../fixtures/test_config.dart';

/// The CI schema check: every customer config shipped in assets/ must be valid.
void main() {
  final configs = Directory('assets/config')
      .listSync()
      .whereType<Directory>()
      .map((dir) => File('${dir.path}/app_config.json'))
      .toList();

  test('there is at least one customer config', () {
    expect(configs, isNotEmpty);
  });

  for (final file in configs) {
    test('${file.path} matches the schema and parses', () {
      final json = jsonDecode(file.readAsStringSync());

      expect(validateConfig(json, jsonDecode(schemaSource()) as Object), isEmpty);
      expect(() => AppConfig.fromJson(json as Map<String, dynamic>), returnsNormally);
    });

    test('${file.path} has a valid device profile for every device type', () {
      final config = AppConfig.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );

      expect(checkDeviceProfiles(config), isEmpty);
      expect(DeviceProfileRegistry(config).offered, hasLength(config.deviceTypes.length));
    });

    test('${file.path} only names brand files that exist and are bundled', () {
      final brand = AppConfig.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
          .brand;
      final pubspec = File('pubspec.yaml').readAsStringSync();

      for (final path in [brand.logoMark, brand.logoSplash]) {
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
        final folder = path.substring(0, path.lastIndexOf('/') + 1);
        expect(pubspec, contains('- $folder'), reason: '$folder is not listed in pubspec.yaml');
      }
    });
  }
}
