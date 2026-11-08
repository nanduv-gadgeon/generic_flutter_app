import 'dart:convert';

/// Add device form rules: pure functions, no text. Screens pair them with messages through
/// `AddDeviceValidators` (see CLAUDE.md).

const maxDeviceNameLength = 40;

/// Wi‑Fi (802.11) limits: network names are 1–32 bytes, WPA passwords 8–63 characters.
const maxSsidBytes = 32;
const minWifiPasswordLength = 8;
const maxWifiPasswordLength = 63;

/// 1–[maxDeviceNameLength] characters once spaces are trimmed.
bool isValidDeviceName(String name) {
  final v = name.trim();
  return v.isNotEmpty && v.length <= maxDeviceNameLength;
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
