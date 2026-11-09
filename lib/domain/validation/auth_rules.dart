import 'package:phone_numbers_parser/phone_numbers_parser.dart';

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
final _nonDigits = RegExp(r'[^0-9]');

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

/// A mobile number for [dialCode]'s country, by that country's rules from Google libphonenumber
/// (length and leading digits; e.g. India: 10 digits starting 6–9). Spaces and dashes are allowed,
/// and so is a leading trunk `0` (UK `07400 123456`). Where mobile and landline numbers look the
/// same (US, Canada) both pass.
bool isValidNationalNumber(String number, DialCode dialCode) =>
    _parseMobile(number, dialCode) != null;

/// What is stored, e.g. `+91 9876543210`: the dial code, a space and the digits only. A valid
/// number is stored without its trunk `0` (`+44 7400123456`).
String fullMobileNumber(DialCode dialCode, String number) {
  var national = number.trim().replaceAll(_separators, '');
  final parsed = _parseMobile(number, dialCode);
  if (parsed != null) {
    // Digits of the dial code after the country code, e.g. 876 for Jamaica (`+1 876`).
    final area = _digits(dialCode.dial).substring(parsed.countryCode.length);
    national = parsed.nsn.startsWith(area) ? parsed.nsn.substring(area.length) : parsed.nsn;
  }
  return '${dialCode.dial} $national';
}

/// The whole international number (dial code + typed digits) checked as a mobile number. The dial
/// code is included because some carry an area code (Jamaica `+1 876`).
PhoneNumber? _parseMobile(String number, DialCode dialCode) {
  final v = number.trim();
  if (!_nationalPattern.hasMatch(v)) return null;
  try {
    final parsed = PhoneNumber.parse('+${_digits(dialCode.dial)}${v.replaceAll(_separators, '')}');
    return parsed.isValid(type: PhoneNumberType.mobile) ? parsed : null;
  } on PhoneNumberException {
    return null;
  }
}

String _digits(String s) => s.replaceAll(_nonDigits, '');

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
