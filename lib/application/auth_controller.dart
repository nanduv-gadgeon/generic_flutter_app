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

  /// Logs in with Face ID / fingerprint and switches screens on success.
  Future<LoginResult> loginWithBiometrics() async {
    final result = await _service.loginWithBiometrics();
    if (result is LoginSuccess) state = AsyncData(result.user);
    return result;
  }

  /// Finishes a password login; the router then leaves the login screen.
  Future<void> completeLogin(AuthUser user, {bool enableBiometrics = false}) async {
    if (enableBiometrics) await _service.setBiometricLogin(enabled: true);
    state = AsyncData(enableBiometrics ? user.copyWith(biometricEnabled: true) : user);
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
