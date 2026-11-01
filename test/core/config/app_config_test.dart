import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';

Map<String, dynamic> _json({Object? isCloud = false, Object? brand = const {'appName': 'Test'}}) =>
    {'isCloud': isCloud, 'brand': brand};

void main() {
  group('AppConfig.fromJson', () {
    test('parses isCloud and brand.appName', () {
      final config = AppConfig.fromJson(_json());

      expect(config, const AppConfig(isCloud: false, appName: 'Test'));
    });

    test('reads isCloud true', () {
      expect(AppConfig.fromJson(_json(isCloud: true)).isCloud, isTrue);
    });

    test('ignores keys it does not know yet', () {
      final json = _json()
        ..['cloud'] = {'baseUrl': 'https://api.example'}
        ..['theme'] = {'primary': '#0F766E'}
        ..['deviceProfiles'] = <Object>[];

      expect(AppConfig.fromJson(json).appName, 'Test');
    });

    final invalid = <String, Map<String, dynamic>>{
      'missing isCloud': _json()..remove('isCloud'),
      'isCloud not a bool': _json(isCloud: 'false'),
      'missing brand': _json()..remove('brand'),
      'missing brand.appName': _json(brand: <String, dynamic>{}),
      'appName not a string': _json(brand: {'appName': 42}),
    };
    for (final entry in invalid.entries) {
      test('throws when ${entry.key}', () {
        expect(() => AppConfig.fromJson(entry.value), throwsA(anything));
      });
    }
  });

  test('bundled vitacare config parses with isCloud false', () {
    final raw = File('assets/config/vitacare/app_config.json').readAsStringSync();
    final config = AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(config, const AppConfig(isCloud: false, appName: 'VitaCare'));
  });
}
