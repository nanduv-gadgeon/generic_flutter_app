import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/services/biometric_auth.dart';
import 'app_config_provider.dart';
import 'auth_controller.dart';

part 'profile_providers.g.dart';

/// The logged-in user's Notifications switch; on when nobody is logged in.
@riverpod
Stream<bool> notificationsEnabled(Ref ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return Stream.value(true);
  return ref.watch(appSettingsServiceProvider).watchNotificationsEnabled(user.id);
}

/// Which biometric the Profile switch is for, or null to hide it: the config turns Face ID
/// login off, or the phone has no biometrics set up.
@riverpod
Future<BiometricKind?> biometricSetting(Ref ref) async {
  final features = ref.watch(appConfigProvider).value?.features;
  if (features?.faceIdLogin != true) return null;
  final biometrics = ref.watch(biometricAuthProvider);
  if (!await biometrics.isAvailable()) return null;
  return biometrics.kind();
}
