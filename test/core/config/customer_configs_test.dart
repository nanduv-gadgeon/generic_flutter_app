import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/config_loader.dart';

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
  }
}
