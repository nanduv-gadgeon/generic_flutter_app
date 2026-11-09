import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/transport/lan_address.dart';

void main() {
  final cases = <String, bool>{
    // Private IPv4 ranges and their edges.
    '10.0.0.1': true,
    '10.255.255.255': true,
    '172.16.0.1': true,
    '172.31.255.254': true,
    '172.15.255.255': false,
    '172.32.0.1': false,
    '192.168.4.1': true,
    '192.169.0.1': false,
    // Link-local and loopback.
    '169.254.10.20': true,
    '127.0.0.1': true,
    // Public IPv4.
    '8.8.8.8': false,
    '1.1.1.1': false,
    '100.64.0.1': false,
    // IPv6.
    '::1': true,
    '[::1]': true,
    'fe80::1': true,
    'fd12:3456::1': true,
    'fc00::1': true,
    '2001:4860:4860::8888': false,
    // Names.
    'sensor.local': true,
    'SENSOR.LOCAL': true,
    '.local': false,
    'example.local.com': false,
    'example.com': false,
    'localhost': false,
    '': false,
  };
  for (final MapEntry(key: host, value: expected) in cases.entries) {
    test('"$host" -> $expected', () {
      expect(isLanHost(host), expected);
    });
  }
}
