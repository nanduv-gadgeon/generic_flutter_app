import 'package:flutter/widgets.dart';

import '../../domain/models/dial_code.dart';
import '../../domain/validation/auth_rules.dart';
import '../strings/auth_strings.dart';
import '../strings/common_strings.dart';

/// Form field validators for the account screens: each pairs a rule from `auth_rules.dart` with
/// its message. Return null when the value is valid.
abstract final class AuthValidators {
  static String? name(String? v) => switch (nameProblem(v ?? '')) {
    null => null,
    NameProblem.blank => AuthStrings.enterName,
    NameProblem.tooShort => AuthStrings.nameTooShort(minNameLength),
    NameProblem.tooLong => AuthStrings.nameTooLong(maxNameLength),
  };

  static String? email(String? v) => isValidEmail(v ?? '') ? null : CommonStrings.invalidEmail;

  /// Login only checks that something was typed; the account check gives the real answer.
  static String? loginPassword(String? v) => (v ?? '').isEmpty ? AuthStrings.enterPassword : null;

  static String? newPassword(String? v) =>
      isValidNewPassword(v ?? '') ? null : AuthStrings.passwordTooShort(minPasswordLength);

  /// [password] is read when validating, so it sees the latest text.
  static FormFieldValidator<String> confirmPassword(String Function() password) =>
      (v) => passwordsMatch(password(), v ?? '') ? null : AuthStrings.passwordsDiffer;

  static FormFieldValidator<String> mobile(DialCode dialCode) =>
      (v) => isValidNationalNumber(v ?? '', dialCode) ? null : AuthStrings.invalidMobile;

  static String? terms(bool? accepted) => accepted == true ? null : AuthStrings.termsRequired;
}
