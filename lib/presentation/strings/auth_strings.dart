import '../../domain/services/biometric_auth.dart';
import '../../l10n/app_localizations.dart';

/// Account text that needs more than a message from `app_en.arb`.
extension AuthStrings on AppLocalizations {
  /// [wait] is rounded up: under a minute in seconds, otherwise in minutes.
  String authAccountLocked(Duration wait) {
    final seconds = (wait.inMilliseconds / 1000).ceil().clamp(1, 1 << 31);
    return seconds < 60
        ? authAccountLockedSeconds(seconds)
        : authAccountLockedMinutes((seconds / 60).ceil());
  }

  /// "Fingerprint login did not work. Use your password."
  String authBiometricFailed(String method) => authBiometricFailedMessage(_capital(method));

  /// Why a Face ID / fingerprint check did not work. [method] is "Face ID", "fingerprint", …;
  /// [enabling] is true when turning biometric login on (Profile switch, offer after login),
  /// false when logging in with it.
  String authBiometricProblem(String method, BiometricOutcome outcome, {required bool enabling}) =>
      switch (outcome) {
        BiometricOutcome.notAvailable => authBiometricNotAvailable(_capital(method)),
        BiometricOutcome.notEnrolled => authBiometricNotEnrolled(method),
        BiometricOutcome.lockedOut => authBiometricLockedOut(method),
        BiometricOutcome.permanentlyLockedOut => authBiometricPermanentlyLockedOut(
          _capital(method),
        ),
        BiometricOutcome.success || BiometricOutcome.cancelled || BiometricOutcome.failed =>
          enabling ? authBiometricNotTurnedOn(_capital(method)) : authBiometricFailed(method),
      };
}

String _capital(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
