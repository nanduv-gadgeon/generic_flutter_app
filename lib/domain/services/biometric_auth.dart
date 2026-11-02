/// What the phone uses for biometric login; picks the button label.
enum BiometricKind { face, fingerprint, other }

/// Face ID / fingerprint, with the device passcode as fallback.
abstract interface class BiometricAuth {
  /// True when the phone supports it and the user has enrolled a face or fingerprint.
  Future<bool> isAvailable();

  Future<BiometricKind> kind();

  /// Shows the system prompt. Returns false if cancelled or failed; never throws.
  Future<bool> authenticate(String reason);
}
