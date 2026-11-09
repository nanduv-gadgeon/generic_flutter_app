import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/devices/device_naming.dart';

void main() {
  final cases = <String, (String, List<String>, String)>{
    'a MAC address': ('C4:7F:51:3D:7B:21', [], 'Test band 7B21'),
    'an mDNS id': ('tst-5c1a', [], 'Test band 5C1A'),
    'an iOS remote id': ('3F2504E0-4F89-11D3-9A0C-0305E82C3301', [], 'Test band 3301'),
    'a short address': ('ab', [], 'Test band AB'),
    'no letters or digits': ('::', [], 'Test band'),
    'a name already used': ('AA:BB:CC:00:7B:21', ['Test band 7B21'], 'Test band 7B21 (2)'),
    'two names already used': (
      'AA:BB:CC:00:7B:21',
      ['Test band 7B21', 'Test band 7B21 (2)'],
      'Test band 7B21 (3)',
    ),
  };
  for (final MapEntry(key: name, value: (address, taken, expected)) in cases.entries) {
    test('names a device from $name', () {
      expect(suggestDeviceName('Test band', address, taken), expected);
    });
  }
}
