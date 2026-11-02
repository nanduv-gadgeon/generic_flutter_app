import 'auth_user.dart';

/// Outcome of a login attempt.
sealed class LoginResult {
  const LoginResult();
}

/// Logged in. [offerBiometrics] is true when the app should offer Face ID for next time.
final class LoginSuccess extends LoginResult {
  const LoginSuccess(this.user, {this.offerBiometrics = false});

  final AuthUser user;
  final bool offerBiometrics;
}

/// Email or password is wrong. Deliberately does not say which.
final class InvalidCredentials extends LoginResult {
  const InvalidCredentials();
}

/// Face ID / fingerprint was cancelled, failed, or is not set up.
final class BiometricFailed extends LoginResult {
  const BiometricFailed();
}

/// An account with this email already exists.
class EmailAlreadyUsedException implements Exception {
  const EmailAlreadyUsedException();
}
