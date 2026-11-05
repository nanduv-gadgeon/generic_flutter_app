import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/validation/link_rules.dart';

void main() {
  test('isSecureWebLink', () {
    final cases = {
      'https://example.com/privacy': true,
      'HTTPS://example.com': true, // Uri lowercases the scheme
      'http://example.com': false,
      'https://': false, // no host
      'file:///etc/hosts': false,
      'javascript:alert(1)': false,
      'intent://example.com#Intent;end': false,
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      expect(isSecureWebLink(Uri.parse(key)), value, reason: key);
    }
  });
}
