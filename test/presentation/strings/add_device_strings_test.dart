import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/add_device/add_device_state.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/presentation/strings/add_device_strings.dart';

void main() {
  final keys = <String, String>{
    'DK-7F3A-9C2E-4B18-0D51': 'DK-7F3A-••••-••••-0D51',
    'ABCDEFGHIJKLMNOP': 'ABCDEFG-••••-••••-MNOP',
    'DK-SHORT-01': 'DK-SHORT-01', // too short to hide anything
    '': '',
  };
  for (final MapEntry(key: key, value: masked) in keys.entries) {
    test('masks the device key "$key"', () {
      expect(AddDeviceStrings.maskedKey(key), masked);
    });
  }

  final values = <String, (AlertRule, String, String)>{
    'a whole number': (const AlertRule(key: 'hr', above: 110), 'bpm', '110 bpm'),
    'a decimal': (const AlertRule(key: 't', above: 37.8), '°C', '37.8 °C'),
    'a lower limit': (const AlertRule(key: 'b', below: 15), '%', '15 %'),
    'no unit': (const AlertRule(key: 'x', below: 2), '', '2'),
  };
  for (final MapEntry(key: name, value: (rule, unit, text)) in values.entries) {
    test('alert value with $name', () {
      expect(AddDeviceStrings.alertValue(rule, unit), text);
    });
  }

  test('alert label says above or below', () {
    expect(
      AddDeviceStrings.alertLabel('Heart rate', const AlertRule(key: 'hr', above: 1)),
      'Heart rate above',
    );
    expect(
      AddDeviceStrings.alertLabel('Battery', const AlertRule(key: 'b', below: 1)),
      'Battery below',
    );
  });

  final details = <String, (String, int?, String)>{
    'a MAC address': ('C4:7F:51:3D:7B:21', -52, '…:7B:21 · -52 dBm'),
    'no signal': ('C4:7F:51:3D:7B:21', null, '…:7B:21'),
    'a short id': ('ab', -60, 'ab · -60 dBm'),
  };
  for (final MapEntry(key: name, value: (id, rssi, text)) in details.entries) {
    test('device detail for $name', () {
      expect(AddDeviceStrings.deviceDetail(id, rssi), text);
    });
  }

  test('counts found devices', () {
    expect(AddDeviceStrings.found(1), 'Found 1 device');
    expect(AddDeviceStrings.found(2), 'Found 2 devices');
  });

  test('type badge lists Wi‑Fi first, as in the mockup', () {
    expect(AddDeviceStrings.transports([Transport.ble, Transport.wifi]), 'Wi‑Fi · BLE');
    expect(AddDeviceStrings.transports([Transport.ble]), 'BLE');
    expect(AddDeviceStrings.transports([Transport.ble], DeviceTier.medium), 'BLE · Medium');
    expect(
      AddDeviceStrings.transports([Transport.wifi, Transport.ble], DeviceTier.huge),
      'Wi‑Fi · BLE · Huge',
    );
    expect(AddDeviceStrings.transports([Transport.ble], DeviceTier.minimum), 'BLE · Minimum');
  });

  test('done subtitle depends on the cloud', () {
    expect(
      AddDeviceStrings.doneBody('Smart band', Transport.ble, cloud: false),
      'Smart band paired over Bluetooth and saved on this phone.',
    );
    expect(
      AddDeviceStrings.doneBody('Smart band', Transport.wifi, cloud: true),
      'Smart band paired over Wi‑Fi and registered with the cloud.',
    );
  });

  test('every error has a message', () {
    for (final error in AddDeviceError.values) {
      expect(AddDeviceStrings.error(error), isNotEmpty);
    }
  });
}
