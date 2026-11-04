import '../models/auth_user.dart';
import '../models/login_result.dart';
import '../models/reset_result.dart';

export '../models/auth_user.dart';
export '../models/login_result.dart';
export '../models/reset_result.dart';

/// Accounts and the login session. Phase 1: on the phone; Phase 2: cloud API.
abstract interface class AuthService {
  /// The logged-in user, restored from the saved session, or null.
  Future<AuthUser?> currentUser();

  Future<LoginResult> login(String email, String password);

  /// [reason] is shown in the phone's own prompt; the screen passes its text.
  Future<LoginResult> loginWithBiometrics({required String reason});

  /// True when some user has turned on biometric login and the phone can do it now.
  Future<bool> canLoginWithBiometrics();

  /// Turns biometric login on or off for the logged-in user.
  Future<void> setBiometricLogin({required bool enabled});

  /// Creates an account. Throws [EmailAlreadyUsedException]. Does not log in.
  Future<AuthUser> register(RegistrationData data);

  /// Forgot password. Phase 1: confirms the phone's owner with its screen lock, then saves
  /// [newPassword] for the account with [email]. Does not log in. [reason] is shown in the phone's
  /// prompt.
  Future<ResetResult> resetPassword({
    required String email,
    required String newPassword,
    required String reason,
  });

  Future<void> logout();
}
