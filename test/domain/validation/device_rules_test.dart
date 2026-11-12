import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/validation/device_rules.dart';

void main() {
  final names = <String, bool>{
    'Bedroom': true,
    '  Bedroom  ': true,
    '': false,
    '   ': false,
    'x' * 40: true,
    'x' * 41: false,
    // At least one letter or digit; punctuation only alongside them.
    '"': false,
    "'": false,
    '---': false,
    r'#$%': false,
    "Dad's band": true,
    'Band-2': true,
    'Kitchen #1': true,
    '7': true,
    'Wärme 3': true,
    'Капля': true,
  };
  for (final MapEntry(key: name, value: valid) in names.entries) {
    test('device name "${name.length > 12 ? '${name.length} chars' : name}" -> $valid', () {
      expect(isValidDeviceName(name), valid);
    });
  }

  final ssids = <String, bool>{
    'TestNet': true,
    'Test Net 2.4': true,
    '': false,
    '   ': false,
    'x' * 32: true,
    'x' * 33: false,
    'é' * 16: true, // 32 bytes
    'é' * 17: false, // 34 bytes
  };
  for (final MapEntry(key: ssid, value: valid) in ssids.entries) {
    test('network name of ${ssid.length} chars ("${ssid.isEmpty ? '' : ssid[0]}…") -> $valid', () {
      expect(isValidSsid(ssid), valid);
    });
  }

  final passwords = <String, bool>{
    '': true, // open network
    'x' * 7: false,
    'x' * 8: true,
    'x' * 63: true,
    'x' * 64: false,
  };
  for (final MapEntry(key: password, value: valid) in passwords.entries) {
    test('Wi‑Fi password of ${password.length} chars -> $valid', () {
      expect(isValidWifiPassword(password), valid);
    });
  }
}
