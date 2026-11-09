import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/dial_code.dart';
import 'package:generic_flutter_app/presentation/auth/auth_validators.dart';

void main() {
  // validator result for (invalid, valid) input; the messages are what users see.
  final cases = <String, (String? Function(String?), String, String, String)>{
    'name': (AuthValidators.name, '  ', 'Test User', 'Enter your name.'),
    'email': (AuthValidators.email, 'test@', 'test@example.com', 'Enter a valid email address.'),
    'loginPassword': (AuthValidators.loginPassword, '', 'x', 'Enter your password.'),
    'newPassword': (
      AuthValidators.newPassword,
      'short',
      'made-up-pw',
      'Use at least 8 characters.',
    ),
    'mobile': (
      AuthValidators.mobile(dialCodeFor('IN')!),
      '123',
      '81234 56789',
      'Enter a valid mobile number.',
    ),
  };
  for (final MapEntry(key: name, value: (validate, bad, good, message)) in cases.entries) {
    test(name, () {
      expect(validate(bad), message);
      expect(validate(null), message);
      expect(validate(good), isNull);
    });
  }

  // (validator, input) -> message; null = allowed
  final lengthCases = <(String? Function(String?), String), String?>{
    (AuthValidators.name, 'T'): 'Use at least 2 characters.',
    (AuthValidators.name, 'Ab'): null,
    (AuthValidators.name, 'T' * 70): null,
    (AuthValidators.name, 'T' * 71): 'Use at most 70 characters.',
    (AuthValidators.email, 'a@b.c'): 'Enter a valid email address.', // 5
    (AuthValidators.email, '${'a' * 242}@example.com'): null, // 254
    (AuthValidators.email, '${'a' * 243}@example.com'): 'Enter a valid email address.', // 255
  };
  for (final MapEntry(key: (validate, input), value: message) in lengthCases.entries) {
    test('length limit: ${input.length} characters -> ${message ?? 'allowed'}', () {
      expect(validate(input), message);
    });
  }

  test('confirmPassword reads the latest password', () {
    var password = 'made-up-pw';
    final validate = AuthValidators.confirmPassword(() => password);
    expect(validate('made-up-pw'), isNull);

    password = 'changed-pw';
    expect(validate('made-up-pw'), 'Passwords do not match.');
  });

  test('terms', () {
    expect(AuthValidators.terms(false), 'Accept the terms to continue.');
    expect(AuthValidators.terms(null), 'Accept the terms to continue.');
    expect(AuthValidators.terms(true), isNull);
  });
}
