import '../models/dial_code.dart';

/// Account form rules: pure functions, no text. Screens pair them with messages through
/// `AuthValidators` (see CLAUDE.md).

const minPasswordLength = 8;
const minNameLength = 2;
const maxNameLength = 70;
const minEmailLength = 6;

/// The longest address email allows (RFC 5321).
const maxEmailLength = 254;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _nationalPattern = RegExp(r'^[0-9][0-9 \-]*$');
final _separators = RegExp(r'[ \-]');

/// Why a name is not allowed.
enum NameProblem { blank, tooShort, tooLong }

/// [minNameLength]–[maxNameLength] characters once spaces are trimmed; null when allowed.
NameProblem? nameProblem(String name) {
  final length = name.trim().length;
  if (length == 0) return NameProblem.blank;
  if (length < minNameLength) return NameProblem.tooShort;
  if (length > maxNameLength) return NameProblem.tooLong;
  return null;
}

bool isValidName(String name) => nameProblem(name) == null;

/// A simple shape check (`a@b.c`) and [minEmailLength]–[maxEmailLength] characters once spaces
/// are trimmed; whether the account exists is checked elsewhere.
bool isValidEmail(String email) {
  final v = email.trim();
  return v.length >= minEmailLength && v.length <= maxEmailLength && _emailPattern.hasMatch(v);
}

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

/// The reverse of [fullMobileNumber], for editing a stored number: `+91 9876543210` gives India
/// and `9876543210`. The longest matching code wins (`+1 876 …` is Jamaica, not the US). A code
/// shared by several countries (`+44`, `+1`) gives [preferred] (the phone's region) when it has
/// that code, otherwise the first listed. Unknown or blank: [preferred] and the stored text.
(DialCode, String) splitMobileNumber(String stored, {DialCode preferred = fallbackDialCode}) {
  final v = stored.trim();
  DialCode? best;
  for (final code in dialCodes) {
    if (v.startsWith('${code.dial} ') && code.dial.length > (best?.dial.length ?? 0)) best = code;
  }
  if (best == null) return (preferred, v);
  final national = v.substring(best.dial.length).trim();
  return (preferred.dial == best.dial ? preferred : best, national);
}
