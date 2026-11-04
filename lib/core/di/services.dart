import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/app_config_provider.dart';
import '../../data/auth/argon2id_password_hasher.dart';
import '../../data/auth/biometric_user_store.dart';
import '../../data/auth/cloud_auth_service.dart';
import '../../data/auth/local_auth_service.dart';
import '../../data/auth/local_biometric_auth.dart';
import '../../data/cloud/cloud_backend_health.dart';
import '../../data/cloud/local_backend_health.dart';
import '../../data/devices/local_device_service.dart';
import '../../data/profile/image_picker_photo_picker.dart';
import '../../data/profile/profile_photo_store.dart';
import '../../data/settings/local_app_settings_service.dart';
import '../../data/upload/cloud_uploader.dart';
import '../../data/upload/no_uploader.dart';
import '../../domain/services/app_settings_service.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/services/backend_health.dart';
import '../../domain/services/biometric_auth.dart';
import '../../domain/services/device_service.dart';
import '../../domain/services/password_hasher.dart';
import '../../domain/services/photo_picker.dart';
import '../../domain/services/uploader.dart';
import 'database.dart';

part 'services.g.dart';

// The only place in the app that branches on isCloud. Screens and controllers read these
// providers and never check isCloud themselves.
//
// `requireValue` is safe: the splash screen waits for the config before anything else runs.

@Riverpod(keepAlive: true)
Uploader uploader(Ref ref) {
  final config = ref.watch(appConfigProvider).requireValue;
  return config.isCloud ? CloudUploader(config.cloud!) : const NoUploader();
}

@Riverpod(keepAlive: true)
BackendHealth backendHealth(Ref ref) {
  final config = ref.watch(appConfigProvider).requireValue;
  return config.isCloud ? CloudBackendHealth(config.cloud!) : const LocalBackendHealth();
}

@Riverpod(keepAlive: true)
PasswordHasher passwordHasher(Ref ref) => const Argon2idPasswordHasher();

@Riverpod(keepAlive: true)
BiometricAuth biometricAuth(Ref ref) => LocalBiometricAuth();

/// Both phases list devices from the local DB (Phase 2 only adds cloud registration, task 1.2.7),
/// so there is no isCloud branch here yet.
@Riverpod(keepAlive: true)
DeviceService deviceService(Ref ref) =>
    LocalDeviceService(ref.watch(appDatabaseProvider).requireValue);

/// `requireValue` on the database is safe for the same reason: the splash opens it first.
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  final config = ref.watch(appConfigProvider).requireValue;
  if (config.isCloud) return CloudAuthService(config.cloud!);
  return LocalAuthService(
    db: ref.watch(appDatabaseProvider).requireValue,
    hasher: ref.watch(passwordHasherProvider),
    biometrics: ref.watch(biometricAuthProvider),
    biometricUser: BiometricUserStore(const FlutterSecureStorage()),
    photos: ProfilePhotoStore(getApplicationSupportDirectory),
  );
}

/// Auto sync (requirement 9.4) exists only with the cloud; the Profile screen hides its row
/// otherwise, without checking isCloud itself.
@Riverpod(keepAlive: true)
bool autoSyncAvailable(Ref ref) => ref.watch(appConfigProvider).requireValue.isCloud;

/// Notifications are local in both phases, so no isCloud branch.
@Riverpod(keepAlive: true)
AppSettingsService appSettingsService(Ref ref) =>
    LocalAppSettingsService(ref.watch(appDatabaseProvider).requireValue);

@Riverpod(keepAlive: true)
PhotoPicker photoPicker(Ref ref) => ImagePickerPhotoPicker();

/// Version and build number of the installed app, e.g. `('1.0.0', '1')`.
@Riverpod(keepAlive: true)
Future<(String, String)> appVersion(Ref ref) async {
  final info = await PackageInfo.fromPlatform();
  return (info.version, info.buildNumber);
}
