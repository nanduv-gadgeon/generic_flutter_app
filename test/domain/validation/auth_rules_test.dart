import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/dial_code.dart';
import 'package:generic_flutter_app/domain/validation/auth_rules.dart';

void main() {
  test('isValidName', () {
    final cases = {'Test User': true, ' T ': true, '': false, '   ': false};
    for (final MapEntry(:key, :value) in cases.entries) {
      expect(isValidName(key), value, reason: '"$key"');
    }
  });

  test('isValidEmail', () {
    final cases = {
      'test@example.com': true,
      ' test@example.com ': true, // trimmed
      'test@example': false,
      'test.example.com': false,
      'te st@example.com': false,
      '': false,
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      expect(isValidEmail(key), value, reason: '"$key"');
    }
  });

  test('isValidNewPassword needs at least $minPasswordLength characters', () {
    expect(isValidNewPassword('made-up'), isFalse); // 7
    expect(isValidNewPassword('made-up!'), isTrue); // 8
  });

  test('passwordsMatch', () {
    expect(passwordsMatch('made-up-pw', 'made-up-pw'), isTrue);
    expect(passwordsMatch('made-up-pw', 'Made-up-pw'), isFalse);
  });

  test('isValidNationalNumber', () {
    final india = dialCodeFor('IN')!; // 2 digits
    final jamaica = dialCodeFor('JM')!; // 4 digits
    // (number, dial code) -> valid
    final cases = {
      ('00000 00000', india): true,
      ('000-000-0000', india): true,
      ('0000', india): true, // 4 digits, the minimum
      ('000', india): false,
      ('0000000000000', india): true, // 13 + 2 = 15, the E.164 maximum
      ('00000000000000', india): false, // 14 + 2 = 16
      ('00000000000', jamaica): true, // 11 + 4 = 15
      ('000000000000', jamaica): false, // 12 + 4 = 16
      ('+91 0000000000', india): false,
      ('00000 abcde', india): false,
      ('', india): false,
    };
    for (final MapEntry(key: (number, code), :value) in cases.entries) {
      expect(isValidNationalNumber(number, code), value, reason: '$number $code');
    }
  });

  test('fullMobileNumber keeps the dial code and only the digits', () {
    expect(fullMobileNumber(dialCodeFor('IN')!, ' 00000-000 00 '), '+91 0000000000');
    expect(fullMobileNumber(dialCodeFor('JM')!, '000 0000'), '+1 876 0000000');
  });
}
