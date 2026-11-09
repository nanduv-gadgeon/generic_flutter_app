/// What the phone uses for biometric login; picks the button label.
enum BiometricKind { face, fingerprint, other }

/// Face ID / fingerprint, with the device passcode as fallback.
abstract interface class BiometricAuth {
  /// True when the phone supports it and the user has enrolled a face or fingerprint.
  Future<bool> isAvailable();

  /// True when the phone has any screen lock (PIN, pattern, passcode or biometrics), so
  /// [authenticate] can confirm the owner. Unlike [isAvailable], no face or fingerprint is needed.
  Future<bool> canVerifyOwner();

  Future<BiometricKind> kind();

  /// Shows the system prompt. Returns false if cancelled or failed; never throws.
  Future<bool> authenticate(String reason);

  /// Saves the phone's current set of enrolled faces / fingerprints, when biometric login is
  /// turned on. False if the phone cannot track changes (then biometric login stays off).
  Future<bool> rememberEnrollment();

  /// True when a face or fingerprint was added or removed since [rememberEnrollment], or nothing
  /// was saved. Never throws; when unsure, true.
  Future<bool> enrollmentChanged();

  /// Drops what [rememberEnrollment] saved, when biometric login is turned off.
  Future<void> forgetEnrollment();
}
