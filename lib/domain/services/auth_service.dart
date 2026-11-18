import '../models/auth_user.dart';
import '../models/login_result.dart';
import '../models/profile_changes.dart';
import '../models/reset_result.dart';
import 'biometric_auth.dart';

export '../models/auth_user.dart';
export '../models/login_result.dart';
export '../models/profile_changes.dart';
export '../models/reset_result.dart';
export 'biometric_auth.dart' show BiometricOutcome;

/// Accounts and the login session. Phase 1: on the phone; Phase 2: cloud API.
abstract interface class AuthService {
  /// The logged-in user, restored from the saved session, or null.
  Future<AuthUser?> currentUser();

  Future<LoginResult> login(String email, String password);

  /// [reason] is shown in the phone's own prompt; the screen passes its text.
  Future<LoginResult> loginWithBiometrics({required String reason});

  /// True when some user has turned on biometric login and the phone can do it now.
  Future<bool> canLoginWithBiometrics();

  /// Turns biometric login on for the logged-in user, but only after the phone's own prompt
  /// (showing [reason]) verifies them. It is on afterwards only for [BiometricOutcome.success];
  /// any other outcome says why it stayed off ([BiometricOutcome.notAvailable] also when the phone
  /// cannot track enrolment changes).
  Future<BiometricOutcome> enableBiometricLogin({required String reason});

  /// Turns biometric login off for the logged-in user. No prompt.
  Future<void> disableBiometricLogin();

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

  /// Saves the logged-in user's profile (name, mobile, photo) and returns it as stored.
  Future<AuthUser> updateProfile(ProfileChanges changes);

  Future<void> logout();
}
