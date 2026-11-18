/// What the phone uses for biometric login; picks the button label.
enum BiometricKind { face, fingerprint, other }

/// How a Face ID / fingerprint check went, so the screen can say why it did not work.
enum BiometricOutcome {
  success,

  /// The user, or the phone, closed the prompt.
  cancelled,

  /// Not recognised, or an unknown error.
  failed,

  /// The phone has no Face ID / fingerprint, or it cannot be used right now.
  notAvailable,

  /// The phone has it, but no face or fingerprint (or no passcode) is set up.
  notEnrolled,

  /// Too many tries; it works again after a short wait.
  lockedOut,

  /// Too many tries; the phone must be unlocked with its passcode first.
  permanentlyLockedOut,
}

/// Face ID / fingerprint, with the device passcode as fallback.
abstract interface class BiometricAuth {
  /// True when the phone supports it and the user has enrolled a face or fingerprint.
  Future<bool> isAvailable();

  /// [BiometricOutcome.success] when [isAvailable]; otherwise [BiometricOutcome.notAvailable] or
  /// [BiometricOutcome.notEnrolled] (the phone has it, nothing is set up). Never throws.
  Future<BiometricOutcome> availability();

  /// True when the phone has any screen lock (PIN, pattern, passcode or biometrics), so
  /// [authenticate] can confirm the owner. Unlike [isAvailable], no face or fingerprint is needed.
  Future<bool> canVerifyOwner();

  Future<BiometricKind> kind();

  /// Shows the system prompt. Anything but [BiometricOutcome.success] means the user was not
  /// verified. Never throws.
  Future<BiometricOutcome> authenticate(String reason);

  /// Saves the phone's current set of enrolled faces / fingerprints, when biometric login is
  /// turned on. False if the phone cannot track changes (then biometric login stays off).
  Future<bool> rememberEnrollment();

  /// True when a face or fingerprint was added or removed since [rememberEnrollment], or nothing
  /// was saved. Never throws; when unsure, true.
  Future<bool> enrollmentChanged();

  /// Drops what [rememberEnrollment] saved, when biometric login is turned off.
  Future<void> forgetEnrollment();
}
