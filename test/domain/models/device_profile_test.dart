import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';

import '../../fixtures/test_config.dart';

void main() {
  test('parses a profile', () {
    final profile = DeviceProfile.fromJson(validProfileJson());

    expect(profile.id, 'test_device_v1');
    expect(profile.icon, DeviceIcon.chip);
    expect(profile.transports, [Transport.ble]);
    expect(profile.readings.first.icon, ReadingIcon.gauge);
    expect(profile.readings.first.decimals, 1);
    expect(profile.readings.first.normal, const NormalRange(low: 10, high: 20));
    expect(profile.readings.last.decimals, 0, reason: 'decimals defaults to 0');
    expect(profile.readings.last.normal, isNull);
    expect(profile.readings.last.goal, 100);
    expect(profile.alerts.first, const AlertRule(key: 'level', above: 25));
    expect(profile.alerts.last.below, 15);
  });

  test('parses the ble block and commands', () {
    final profile = DeviceProfile.fromJson(validProfileJson());

    expect(profile.ble!.writeUuid, '11111111-2222-3333-4444-000000000002');
    expect(profile.ble!.bond, isFalse, reason: 'bond defaults to false');
    expect(profile.ble!.batteryService, isTrue, reason: 'batteryService defaults to true');
    expect(profile.commands.single.data, [0xA5, 0x01]);
  });

  test('ble and commands are optional', () {
    final profile = DeviceProfile.fromJson(
      validProfileJson()
        ..remove('ble')
        ..remove('commands'),
    );

    expect(profile.ble, isNull);
    expect(profile.commands, isEmpty);
  });

  test('scans for scanServiceUuid when set, else the service', () {
    const ble = BleSettings(serviceUuid: 'aaaa', notifyUuid: 'bbbb');

    expect(ble.scanUuid, 'aaaa');
    expect(ble.copyWith(scanServiceUuid: 'cccc').scanUuid, 'cccc');
  });

  final uuids = {
    '180F': '0000180f-0000-1000-8000-00805f9b34fb',
    '1257DD10-6F99-498F-B4A6-04DC1E3591F6': '1257dd10-6f99-498f-b4a6-04dc1e3591f6',
  };
  for (final MapEntry(key: given, value: expected) in uuids.entries) {
    test('fullUuid($given)', () => expect(fullUuid(given), expected));
  }

  test('survives a JSON round trip', () {
    final profile = DeviceProfile.fromJson(validProfileJson());
    final json = jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>;

    expect(DeviceProfile.fromJson(json), profile);
  });

  final unknownEnums = <String, void Function(Map<String, dynamic>)>{
    'device icon': (j) => j['icon'] = 'rocket',
    'transport': (j) => j['transports'] = ['zigbee'],
    'reading icon': (j) => (j['readings'] as List).first['icon'] = 'rocket',
  };
  for (final MapEntry(key: name, value: change) in unknownEnums.entries) {
    test('rejects an unknown $name', () {
      final json = validProfileJson();
      change(json);

      expect(() => DeviceProfile.fromJson(json), throwsA(anything));
    });
  }
}
