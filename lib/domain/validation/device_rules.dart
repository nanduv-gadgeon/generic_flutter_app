import 'dart:convert';

/// Add device form rules: pure functions, no text. Screens pair them with messages through
/// `AddDeviceValidators` (see CLAUDE.md).

const maxDeviceNameLength = 40;

/// Wi‑Fi (802.11) limits: network names are 1–32 bytes, WPA passwords 8–63 characters.
const maxSsidBytes = 32;
const minWifiPasswordLength = 8;
const maxWifiPasswordLength = 63;

/// Any letter or digit, in any script.
final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// 1–[maxDeviceNameLength] characters once spaces are trimmed, with at least one letter or digit;
/// punctuation is fine alongside them ("Dad's band", "Band-2"), but not on its own (`"`, `---`).
bool isValidDeviceName(String name) {
  final v = name.trim();
  return v.isNotEmpty && v.length <= maxDeviceNameLength && _letterOrDigit.hasMatch(v);
}

/// 1–[maxSsidBytes] bytes of UTF‑8. Spaces count: they can be part of a network name.
bool isValidSsid(String ssid) {
  final bytes = utf8.encode(ssid).length;
  return ssid.trim().isNotEmpty && bytes <= maxSsidBytes;
}

/// Empty for an open network, otherwise a WPA password of 8–63 characters.
bool isValidWifiPassword(String password) =>
    password.isEmpty ||
    (password.length >= minWifiPasswordLength && password.length <= maxWifiPasswordLength);
