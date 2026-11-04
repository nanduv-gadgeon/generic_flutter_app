import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/device_profile_registry.dart';

import '../../fixtures/test_config.dart';

/// A valid config with one change applied.
AppConfig _config([void Function(Map<String, dynamic> json)? change]) {
  final json = validConfigJson();
  change?.call(json);
  return AppConfig.fromJson(json);
}

Map<String, dynamic> _profile(Map<String, dynamic> json, [int i = 0]) =>
    (json['deviceProfiles'] as List)[i] as Map<String, dynamic>;

List<dynamic> _readings(Map<String, dynamic> json) => _profile(json)['readings'] as List;

void main() {
  group('checkDeviceProfiles', () {
    test('accepts a valid config', () {
      expect(checkDeviceProfiles(_config()), isEmpty);
    });

    test('accepts a profile that is not offered', () {
      final config = _config(
        (j) => (j['deviceProfiles'] as List).add(validProfileJson(id: 'spare_v1')),
      );

      expect(checkDeviceProfiles(config), isEmpty);
    });

    // Each case breaks one rule; the error must name the path that is wrong.
    final invalid = <String, (void Function(Map<String, dynamic>), String)>{
      'a duplicate profile id': (
        (j) => (j['deviceProfiles'] as List).add(validProfileJson()),
        '/deviceProfiles/1/id: duplicate profile id',
      ),
      'a device type with no profile': (
        (j) => (j['deviceTypes'] as List).add('missing_v1'),
        '/deviceTypes/1: no device profile for "missing_v1"',
      ),
      'a duplicate reading key': (
        (j) => _readings(j)[1]['key'] = 'level',
        '/deviceProfiles/0/readings/1/key: duplicate reading key',
      ),
      'an alert on an unknown reading': (
        (j) => (_profile(j)['alerts'] as List)[0]['key'] = 'pressure',
        '/deviceProfiles/0/alerts/0/key: "pressure" is not a reading',
      ),
      'a normal range with low = high': (
        (j) => _readings(j)[0]['normal'] = [20, 20],
        '/deviceProfiles/0/readings/0/normal: low must be below high',
      ),
      'a ble block without the ble transport': (
        (j) => _profile(j)['transports'] = ['wifi'],
        '/deviceProfiles/0/ble: set, but "ble" is not in transports',
      ),
      'a duplicate command id': (
        (j) => (_profile(j)['commands'] as List).add({'id': 'ping', 'bytes': '00'}),
        '/deviceProfiles/0/commands/1/id: duplicate command id',
      ),
      'a normal range with low > high': (
        (j) => _readings(j)[0]['normal'] = [30, 20],
        '/deviceProfiles/0/readings/0/normal: low must be below high',
      ),
    };
    for (final MapEntry(key: name, value: (change, error)) in invalid.entries) {
      test('rejects $name', () {
        expect(checkDeviceProfiles(_config(change)), [startsWith(error)]);
      });
    }
  });

  group('DeviceProfileRegistry', () {
    final registry = DeviceProfileRegistry(
      _config(
        (j) => j
          ..['deviceTypes'] = ['second_v1', 'test_device_v1']
          ..['deviceProfiles'] = [
            validProfileJson(),
            validProfileJson(id: 'spare_v1'),
            validProfileJson(id: 'second_v1'),
          ],
      ),
    );

    test('offers profiles in deviceTypes order and hides the rest', () {
      expect(registry.offered.map((p) => p.id), ['second_v1', 'test_device_v1']);
    });

    test('finds any profile by id', () {
      expect(registry.byId('spare_v1').id, 'spare_v1');
      expect(registry.contains('spare_v1'), isTrue);
      expect(registry.contains('missing_v1'), isFalse);
    });

    test('throws for an unknown id', () {
      expect(
        () => registry.byId('missing_v1'),
        throwsA(isA<UnknownDeviceTypeException>().having((e) => e.id, 'id', 'missing_v1')),
      );
    });
  });

  group('isConnectable', () {
    final profile = DeviceProfile.fromJson(validProfileJson());
    final cases = <String, (DeviceProfile, Transport, bool)>{
      'BLE with a ble block': (profile, Transport.ble, true),
      'BLE without a ble block': (profile.copyWith(ble: null), Transport.ble, false),
      'a transport the profile does not list': (
        profile.copyWith(transports: [Transport.wifi]),
        Transport.ble,
        false,
      ),
      'Wi-Fi (until 1.2.6)': (
        profile.copyWith(transports: [Transport.ble, Transport.wifi]),
        Transport.wifi,
        false,
      ),
    };
    for (final MapEntry(key: name, value: (p, transport, expected)) in cases.entries) {
      test('$name -> $expected', () {
        expect(isConnectable(p, transport), expected);
      });
    }
  });
}
