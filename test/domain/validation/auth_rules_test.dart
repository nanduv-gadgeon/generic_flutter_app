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

  // Per-country mobile rules (Google libphonenumber). The valid numbers are libphonenumber's own
  // published example numbers, not real people's.
  // (ISO code, number) -> valid
  final mobileCases = <(String, String), bool>{
    ('IN', '81234 56789'): true,
    ('IN', '81234-56789'): true, // dashes allowed
    ('IN', '8123456789'): true,
    ('IN', '8123 45678'): false, // 9 digits
    ('IN', '81234 567890'): false, // 11 digits
    ('IN', '00000 00000'): false, // not a mobile range
    ('IN', '+91 81234 56789'): false, // the code is picked separately
    ('IN', '81234 abcde'): false,
    ('IN', ''): false,
    ('GB', '7400 123456'): true,
    ('GB', '07400 123456'): true, // trunk 0, as dialled in the UK
    ('GB', '20 7946 0958'): false, // a London landline
    ('GB', '7400 12345'): false, // too short
    ('US', '201 555 0123'): true, // mobile and landline look the same
    ('US', '201 555 012'): false,
    ('DE', '1512 3456789'): true,
    ('DE', '01512 3456789'): true,
    ('DE', '30 123456'): false, // a Berlin landline
    ('AE', '50 123 4567'): true,
    ('AE', '50 123 456'): false,
    ('JM', '210 1234'): true, // after +1 876
    ('JM', '210 123'): false,
  };
  for (final MapEntry(key: (iso, number), :value) in mobileCases.entries) {
    test('isValidNationalNumber: $iso "$number" -> $value', () {
      expect(isValidNationalNumber(number, dialCodeFor(iso)!), value);
    });
  }

  // (ISO code, typed) -> stored
  final stored = <(String, String), String>{
    ('IN', ' 81234-567 89 '): '+91 8123456789',
    ('GB', '07400 123456'): '+44 7400123456', // trunk 0 dropped
    ('JM', '210 1234'): '+1 876 2101234', // 876 stays in the dial code
    ('IN', '000'): '+91 000', // invalid input is kept as typed (digits only)
  };
  for (final MapEntry(key: (iso, typed), value: expected) in stored.entries) {
    test('fullMobileNumber: $iso "$typed" -> "$expected"', () {
      expect(fullMobileNumber(dialCodeFor(iso)!, typed), expected);
    });
  }

  test('a stored number splits back into what was typed', () {
    for (final iso in ['IN', 'GB', 'JM']) {
      final code = dialCodeFor(iso)!;
      final typed = mobileCases.keys.firstWhere((k) => k.$1 == iso && mobileCases[k]!).$2;
      final (back, national) = splitMobileNumber(fullMobileNumber(code, typed), preferred: code);
      expect(back.iso, iso);
      expect(isValidNationalNumber(national, back), isTrue, reason: national);
    }
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
