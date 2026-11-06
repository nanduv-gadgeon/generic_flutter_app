import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/dial_code.dart';
import 'package:generic_flutter_app/domain/validation/auth_rules.dart';

void main() {
  test('nameProblem: $minNameLength–$maxNameLength characters once trimmed', () {
    final cases = <String, NameProblem?>{
      'Test User': null,
      'Ab': null, // 2: the minimum
      ' Ab ': null, // trimmed to 2
      'T' * 70: null, // the maximum
      ' ${'T' * 70} ': null, // trimmed to 70
      '': NameProblem.blank,
      '   ': NameProblem.blank,
      'T': NameProblem.tooShort,
      ' T ': NameProblem.tooShort,
      'T' * 71: NameProblem.tooLong,
      'T' * 300: NameProblem.tooLong, // TC-REG-011
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      expect(nameProblem(key), value, reason: '"$key" (${key.length})');
      expect(isValidName(key), value == null, reason: '"$key" (${key.length})');
    }
  });

  test('isValidEmail: shape and $minEmailLength–$maxEmailLength characters', () {
    // local part + '@example.com' (12 characters)
    String emailOfLength(int n) => '${'a' * (n - 12)}@example.com';
    final cases = {
      'test@example.com': true,
      ' test@example.com ': true, // trimmed
      'a@b.co': true, // 6: the minimum
      'a@b.c': false, // 5
      emailOfLength(254): true, // the maximum
      ' ${emailOfLength(254)} ': true, // trimmed to 254
      emailOfLength(255): false,
      emailOfLength(320): false, // TC-REG-011
      'test@example': false,
      'test.example.com': false,
      'te st@example.com': false,
      '': false,
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      expect(isValidEmail(key), value, reason: '"$key" (${key.length})');
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

  test('splitMobileNumber reverses fullMobileNumber', () {
    // stored -> (ISO code, national number)
    final cases = {
      '+91 0000000000': ('IN', '0000000000'),
      '+1 876 0000000': ('JM', '0000000'), // longest code wins over +1
      ' +91 0000000000 ': ('IN', '0000000000'),
      '+999 0000': (fallbackDialCode.iso, '+999 0000'), // unknown code
      '0000000000': (fallbackDialCode.iso, '0000000000'), // no code
      '': (fallbackDialCode.iso, ''),
    };
    for (final MapEntry(key: stored, value: (iso, number)) in cases.entries) {
      final (code, national) = splitMobileNumber(stored);
      expect((code.iso, national), (iso, number), reason: '"$stored"');
    }
  });

  test('splitMobileNumber on a shared code prefers the phone region', () {
    final gb = dialCodeFor('GB')!;
    // (stored, preferred) -> ISO code
    final cases = {
      ('+44 0000000000', gb): 'GB',
      ('+44 0000000000', dialCodeFor('JE')!): 'JE',
      ('+44 0000000000', dialCodeFor('IN')!): 'GG', // region has another code: first listed
      ('+1 0000000000', dialCodeFor('US')!): 'US',
      ('+999 0000', gb): 'GB', // unknown code: the region
    };
    for (final MapEntry(key: (stored, preferred), value: iso) in cases.entries) {
      expect(splitMobileNumber(stored, preferred: preferred).$1.iso, iso, reason: stored);
    }
  });
}
