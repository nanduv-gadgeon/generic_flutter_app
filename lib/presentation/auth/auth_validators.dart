import 'package:flutter/widgets.dart';

import '../../domain/models/dial_code.dart';
import '../../domain/validation/auth_rules.dart';
import '../../l10n/app_localizations.dart';

/// Form field validators for the account screens: each pairs a rule from `auth_rules.dart` with
/// its message in the phone's language. Return null when the value is valid.
/// Use `AuthValidators(context.l10n).email`.
final class AuthValidators {
  const AuthValidators(this._l10n);

  final AppLocalizations _l10n;

  String? name(String? v) => switch (nameProblem(v ?? '')) {
    null => null,
    NameProblem.blank => _l10n.authEnterName,
    NameProblem.tooShort => _l10n.authNameTooShort(minNameLength),
    NameProblem.tooLong => _l10n.authNameTooLong(maxNameLength),
  };

  String? email(String? v) => isValidEmail(v ?? '') ? null : _l10n.commonInvalidEmail;

  /// Login only checks that something was typed; the account check gives the real answer.
  String? loginPassword(String? v) => (v ?? '').isEmpty ? _l10n.authEnterPassword : null;

  String? newPassword(String? v) =>
      isValidNewPassword(v ?? '') ? null : _l10n.authPasswordTooShort(minPasswordLength);

  /// [password] is read when validating, so it sees the latest text.
  FormFieldValidator<String> confirmPassword(String Function() password) =>
      (v) => passwordsMatch(password(), v ?? '') ? null : _l10n.authPasswordsDiffer;

  FormFieldValidator<String> mobile(DialCode dialCode) =>
      (v) => isValidNationalNumber(v ?? '', dialCode) ? null : _l10n.authInvalidMobile;

  String? terms(bool? accepted) => accepted == true ? null : _l10n.authTermsRequired;
}
