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
