import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/services/auth_service.dart';
import '../domain/services/biometric_auth.dart';

part 'auth_controller.g.dart';

/// Who is logged in (null = nobody). The router redirects on every change.
///
/// Built during the splash screen, which restores a saved session.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  AuthService get _service => ref.read(authServiceProvider);

  @override
  Future<AuthUser?> build() => ref.watch(authServiceProvider).currentUser();

  /// Checks the password and starts the session, but does not switch screens yet: on
  /// [LoginSuccess] the screen may first offer biometrics, then must call [completeLogin].
  Future<LoginResult> login(String email, String password) => _service.login(email, password);

  /// Logs in with Face ID / fingerprint and switches screens on success. [reason] is shown in the
  /// phone's prompt.
  Future<LoginResult> loginWithBiometrics({required String reason}) async {
    final result = await _service.loginWithBiometrics(reason: reason);
    if (result is LoginSuccess) state = AsyncData(result.user);
    return result;
  }

  /// Finishes a password login; the router then leaves the login screen.
  Future<void> completeLogin(AuthUser user, {bool enableBiometrics = false}) async {
    if (enableBiometrics) await _service.setBiometricLogin(enabled: true);
    state = AsyncData(enableBiometrics ? user.copyWith(biometricEnabled: true) : user);
  }

  /// Creates the account, logs it in and switches screens (to home). No biometric offer here:
  /// that comes with the first password login.
  ///
  /// Throws [EmailAlreadyUsedException]; nobody is logged in then.
  Future<void> register(RegistrationData data) async {
    await _service.register(data);
    final result = await _service.login(data.email, data.password);
    if (result is! LoginSuccess) throw StateError('New account could not log in');
    state = AsyncData(result.user);
  }

  /// Forgot password: confirms the phone's owner, then saves the new password. Nobody is logged
  /// in afterwards; the screen goes back to login.
  Future<ResetResult> resetPassword(String email, String newPassword, {required String reason}) =>
      _service.resetPassword(email: email, newPassword: newPassword, reason: reason);

  /// Saves Edit profile; every screen showing the user (profile, home greeting) updates.
  /// Throws [EmailAlreadyUsedException]; nothing is saved then.
  Future<void> updateProfile(ProfileChanges changes) async {
    state = AsyncData(await _service.updateProfile(changes));
  }

  /// The Profile switch for Face ID / fingerprint login.
  Future<void> setBiometricLogin({required bool enabled}) async {
    await _service.setBiometricLogin(enabled: enabled);
    state = AsyncData(state.value?.copyWith(biometricEnabled: enabled));
    ref.invalidate(biometricLoginProvider);
  }

  Future<void> logout() async {
    await _service.logout();
    state = const AsyncData(null);
  }
}

/// Whether the login screen should show the biometric button, and with which label.
@riverpod
Future<BiometricKind?> biometricLogin(Ref ref) async {
  final service = ref.watch(authServiceProvider);
  if (!await service.canLoginWithBiometrics()) return null;
  return ref.watch(biometricAuthProvider).kind();
}
