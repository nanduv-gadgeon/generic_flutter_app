import '../../core/config/config_sections.dart';
import '../../domain/services/auth_service.dart';

/// Phase 2 accounts through the cloud API. Empty hooks until the API contract is agreed.
class CloudAuthService implements AuthService {
  const CloudAuthService(this.config);

  final CloudConfig config;

  @override
  Future<AuthUser?> currentUser() async {
    // TODO(phase2): restore the session from tokens in secure storage (GET /me).
    return null;
  }

  @override
  Future<LoginResult> login(String email, String password) =>
      // TODO(phase2): POST /auth/login over HTTPS; keep tokens in secure storage.
      throw UnimplementedError('Phase 2: cloud login');

  @override
  Future<LoginResult> loginWithBiometrics({required String reason}) =>
      // TODO(phase2): unlock the stored refresh token with biometrics.
      throw UnimplementedError('Phase 2: cloud biometric login');

  @override
  Future<bool> canLoginWithBiometrics() async {
    // TODO(phase2): true when a refresh token is stored for biometric login.
    return false;
  }

  @override
  Future<void> setBiometricLogin({required bool enabled}) =>
      // TODO(phase2): store or remove the refresh token behind biometrics.
      throw UnimplementedError('Phase 2: cloud biometric setting');

  @override
  Future<AuthUser> register(RegistrationData data) =>
      // TODO(phase2): POST /auth/register.
      throw UnimplementedError('Phase 2: cloud registration');

  @override
  Future<ResetResult> resetPassword({
    required String email,
    required String newPassword,
    required String reason,
  }) =>
      // TODO(phase2): POST /auth/forgot-password; the cloud emails a reset link instead, so the
      // forgot-password screen will need a "link sent" variant.
      throw UnimplementedError('Phase 2: cloud password reset');

  @override
  Future<void> logout() async {
    // TODO(phase2): POST /auth/logout, clear tokens, stop the uploader.
  }
}
