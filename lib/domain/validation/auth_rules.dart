import '../models/dial_code.dart';

/// Account form rules: pure functions, no text. Screens pair them with messages through
/// `AuthValidators` (see CLAUDE.md).

const minPasswordLength = 8;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _nationalPattern = RegExp(r'^[0-9][0-9 \-]*$');
final _separators = RegExp(r'[ \-]');

/// Not blank once spaces are trimmed.
bool isValidName(String name) => name.trim().isNotEmpty;

/// A simple shape check (`a@b.c`); whether the account exists is checked elsewhere.
bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

/// A new password: at least [minPasswordLength] characters.
bool isValidNewPassword(String password) => password.length >= minPasswordLength;

bool passwordsMatch(String password, String confirmation) => password == confirmation;

/// 4–14 digits (spaces and dashes allowed), and at most 15 digits with the dial code (E.164).
bool isValidNationalNumber(String number, DialCode dialCode) {
  final v = number.trim();
  if (!_nationalPattern.hasMatch(v)) return false;
  final digits = v.replaceAll(_separators, '').length;
  return digits >= 4 && digits <= 14 && digits + dialCode.digitCount <= 15;
}

/// What is stored, e.g. `+91 9876543210`: the dial code, a space and the digits only.
String fullMobileNumber(DialCode dialCode, String number) =>
    '${dialCode.dial} ${number.trim().replaceAll(_separators, '')}';
