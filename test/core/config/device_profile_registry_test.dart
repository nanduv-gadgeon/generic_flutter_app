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

List<dynamic> _frames(Map<String, dynamic> json) =>
    (_profile(json)['packet'] as Map)['frames'] as List;

List<dynamic> _fields(Map<String, dynamic> json) => _frames(json)[0]['fields'] as List;

/// Gives the first profile the `wifi` transport and block, then applies [change] to the block.
void Function(Map<String, dynamic>) _wifi(void Function(Map<String, dynamic> wifi) change) => (j) {
  _profile(j)
    ..['transports'] = ['ble', 'wifi']
    ..['wifi'] = wifiBlockJson();
  change(_profile(j)['wifi'] as Map<String, dynamic>);
};

void main() {
  group('checkDeviceProfiles', () {
    test('accepts a valid config', () {
      expect(checkDeviceProfiles(_config()), isEmpty);
    });

    test('accepts a profile with a wifi block', () {
      expect(checkDeviceProfiles(_config(_wifi((_) {}))), isEmpty);
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
        (j) => _readings(j)[1]['key'] = 'current',
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
      'a ble block without a packet': (
        (j) => _profile(j).remove('packet'),
        '/deviceProfiles/0/packet: needed to read data from a BLE device',
      ),
      'a reading no packet field gives': (
        (j) => _readings(j).add({'key': 'pressure', 'label': 'P', 'unit': 'hPa', 'icon': 'gauge'}),
        '/deviceProfiles/0/readings/2/key: no packet field or signal gives "pressure"',
      ),
      'a duplicate frame code': (
        (j) => _frames(j).add({'code': 'a5', 'kind': 'noData'}),
        '/deviceProfiles/0/packet/frames/1/code: duplicate frame code',
      ),
      'a field past minLength': (
        (j) => _fields(j)[0]['offset'] = 4,
        '/deviceProfiles/0/packet/frames/0/fields/0: does not fit in minLength 5',
      ),
      'a field past the record size': (
        (j) => _frames(j)[0]['records'] = {'start': 1, 'end': -1, 'size': 3},
        '/deviceProfiles/0/packet/frames/0/fields/1: does not fit in a 3-byte record',
      ),
      'a condition past the record': (
        (j) => _fields(j)[1]['when'] = {'offset': 9, 'equals': '01'},
        '/deviceProfiles/0/packet/frames/0/fields/1/when: does not fit in minLength 5',
      ),
      'a time field past the record': (
        (j) => _frames(j)[0]['time'] = {'offset': 2, 'type': 'uint32', 'unit': 's'},
        '/deviceProfiles/0/packet/frames/0/time: does not fit in minLength 5',
      ),
      'an event offset past the record': (
        (j) => _frames(j)[0]['events'] = {
          'typeOffset': 0,
          'codeOffset': 7,
          'types': {'01': 'start'},
        },
        '/deviceProfiles/0/packet/frames/0/events/codeOffset: does not fit in minLength 5',
      ),
      'a duplicate command id': (
        (j) => (_profile(j)['commands'] as List).add({'id': 'ping', 'bytes': '00'}),
        '/deviceProfiles/0/commands/1/id: duplicate command id',
      ),
      'a wifi block without the wifi transport': (
        (j) {
          _wifi((_) {})(j);
          _profile(j)['transports'] = ['ble'];
        },
        '/deviceProfiles/0/wifi: set, but "wifi" is not in transports',
      ),
      'a wifi block without a packet': (
        (j) {
          _wifi((_) {})(j);
          _profile(j)
            ..remove('packet')
            ..remove('ble');
        },
        '/deviceProfiles/0/packet: needed to read data from a Wi‑Fi device',
      ),
      'BLE setup without bleSetup': (
        _wifi((w) => w.remove('bleSetup')),
        '/deviceProfiles/0/wifi/bleSetup: needed for setup over BLE',
      ),
      'SoftAP setup without softApSetup': (
        _wifi((w) => w.remove('softApSetup')),
        '/deviceProfiles/0/wifi/softApSetup: needed for setup over the device hotspot',
      ),
      'a SoftAP address off the local network': (
        _wifi((w) => w['softApSetup']['address'] = '8.8.8.8'),
        '/deviceProfiles/0/wifi/softApSetup/address: must be a local network address',
      ),
      'an HTTP stream without pollSeconds': (
        _wifi((w) => w['stream'] = {'type': 'http', 'path': '/data'}),
        '/deviceProfiles/0/wifi/stream/pollSeconds: needed for an HTTP stream',
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
    final wifiProfile = DeviceProfile.fromJson(validWifiProfileJson());
    final cases = <String, (DeviceProfile, Transport, bool)>{
      'BLE with a ble block': (profile, Transport.ble, true),
      'BLE without a ble block': (profile.copyWith(ble: null), Transport.ble, false),
      'BLE without a packet': (profile.copyWith(packet: null), Transport.ble, false),
      'a transport the profile does not list': (
        profile.copyWith(transports: [Transport.wifi]),
        Transport.ble,
        false,
      ),
      'Wi-Fi with a wifi block': (wifiProfile, Transport.wifi, true),
      'Wi-Fi without a wifi block': (wifiProfile.copyWith(wifi: null), Transport.wifi, false),
      'Wi-Fi without a packet': (wifiProfile.copyWith(packet: null), Transport.wifi, false),
    };
    for (final MapEntry(key: name, value: (p, transport, expected)) in cases.entries) {
      test('$name -> $expected', () {
        expect(isConnectable(p, transport), expected);
      });
    }
  });
}
