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
  String authBiometricFailed(String method) => authBiometricFailedMessage(
    method.isEmpty ? method : method[0].toUpperCase() + method.substring(1),
  );
}
