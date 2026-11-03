import 'dial_codes.dart';

export 'dial_codes.dart';

/// A country's international dialling code (ITU-T E.164). The list is in `dial_codes.dart`.
final class DialCode {
  const DialCode(this.iso, this.name, this.dial);

  /// ISO 3166-1 alpha-2 country code, e.g. `IN`.
  final String iso;
  final String name;

  /// `+` and the country code; North American countries outside the US and Canada include their
  /// area code, e.g. `+1 876` for Jamaica.
  final String dial;

  /// Number of digits in [dial], counted towards the E.164 limit of 15.
  int get digitCount => dial.replaceAll(RegExp(r'[^0-9]'), '').length;

  @override
  String toString() => '$name ($dial)';
}

/// Used when the phone's region is missing or not in [dialCodes] (the mockup's example).
const fallbackDialCode = DialCode('IN', 'India', '+91');

/// The code for [iso] (any letter case), or null if it is not listed.
DialCode? dialCodeFor(String? iso) {
  final upper = iso?.toUpperCase();
  for (final code in dialCodes) {
    if (code.iso == upper) return code;
  }
  return null;
}

/// The code for the phone's region, e.g. `GB` -> +44, or [fallbackDialCode].
DialCode defaultDialCode(String? regionCode) => dialCodeFor(regionCode) ?? fallbackDialCode;

/// The codes matching [query]: part of the country name, the exact ISO code, or the start of
/// the dial code (`44` or `+44`). Case and spaces are ignored; an empty query matches all.
List<DialCode> filterDialCodes(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return dialCodes;
  final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
  return [
    for (final c in dialCodes)
      if (c.name.toLowerCase().contains(q) ||
          c.iso.toLowerCase() == q ||
          (digits.isNotEmpty && c.dial.replaceAll(' ', '').startsWith('+$digits')))
        c,
  ];
}
