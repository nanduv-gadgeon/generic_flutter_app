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

    test('${file.path} only names valid BLE UUIDs', () {
      final config = AppConfig.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      for (final ble in config.deviceProfiles.map((p) => p.ble).nonNulls) {
        final uuids = [ble.serviceUuid, ble.notifyUuid, ble.scanUuid, ?ble.writeUuid];
        for (final uuid in uuids) {
          expect(fullUuid(uuid), hasLength(36), reason: uuid);
        }
      }
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

  test('VitaCare: the IEF patch and the PPG + Motion sensor connect over BLE; others wait', () {
    final config = AppConfig.fromJson(
      jsonDecode(File('assets/config/vitacare/app_config.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final connectable = [
      for (final p in DeviceProfileRegistry(config).offered)
        if (isConnectable(p, Transport.ble)) p.id,
    ];

    expect(connectable, ['ief_device_v1', 'ppg_motion_v1']);
  });

  test('VitaCare: no type connects over Wi‑Fi until the env sensor protocol arrives', () {
    final config = AppConfig.fromJson(
      jsonDecode(File('assets/config/vitacare/app_config.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    expect(
      DeviceProfileRegistry(config).offered.where((p) => isConnectable(p, Transport.wifi)),
      isEmpty,
    );
  });
}
