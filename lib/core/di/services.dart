import 'package:flutter/foundation.dart';
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
import '../../data/devices/cloud_device_registration.dart';
import '../../data/devices/active_device.dart';
import '../../data/devices/demo_live_readings.dart';
import '../../data/devices/heartbeat_recorder.dart';
import '../../data/devices/reading_writer.dart';
import '../../data/events/local_device_event_repository.dart';
import '../../data/heartbeats/local_heartbeat_repository.dart';
import '../../data/readings/local_reading_repository.dart';
import '../../data/devices/local_device_service.dart';
import '../../data/devices/no_device_registration.dart';
import '../../data/profile/image_picker_photo_picker.dart';
import '../../data/profile/profile_photo_store.dart';
import '../../data/settings/local_app_settings_service.dart';
import '../../data/upload/cloud_uploader.dart';
import '../../data/upload/no_uploader.dart';
import '../../domain/services/app_settings_service.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/services/backend_health.dart';
import '../../domain/services/biometric_auth.dart';
import '../../domain/services/device_event_repository.dart';
import '../../domain/services/device_registration.dart';
import '../../domain/services/device_service.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/services/heartbeat_repository.dart';
import '../../domain/services/live_readings.dart';
import '../../domain/services/reading_repository.dart';
import '../../domain/services/password_hasher.dart';
import '../../domain/services/photo_picker.dart';
import '../../domain/services/uploader.dart';
import '../config/dashboard_checks.dart';
import '../config/device_profile_registry.dart';
import '../jobs/reading_cleanup_job.dart';
import 'database.dart';
import 'transports.dart';

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

/// Phase 2 registers new devices with the cloud; Phase 1 registers nothing.
@Riverpod(keepAlive: true)
DeviceRegistration deviceRegistration(Ref ref) {
  final config = ref.watch(appConfigProvider).requireValue;
  return config.isCloud ? CloudDeviceRegistration(config.cloud!) : const NoDeviceRegistration();
}

/// Add device shows the device key and cloud checklist only with the cloud, without checking
/// isCloud itself.
@Riverpod(keepAlive: true)
bool cloudRegistrationAvailable(Ref ref) => ref.watch(appConfigProvider).requireValue.isCloud;

/// Both phases keep devices in the local DB; the registration differs.
@Riverpod(keepAlive: true)
DeviceService deviceService(Ref ref) => LocalDeviceService(
  ref.watch(appDatabaseProvider).requireValue,
  ref.watch(deviceRegistrationProvider),
  ref.watch(devicePairingProvider),
);

/// Stored readings: the local database in both phases.
// TODO(phase2): the uploader reads the rows it has not sent yet.
@Riverpod(keepAlive: true)
ReadingRepository readingRepository(Ref ref) =>
    LocalReadingRepository(ref.watch(appDatabaseProvider).requireValue);

/// Stored heartbeats: the local database in both phases.
// TODO(phase2): the uploader sends them with the readings.
@Riverpod(keepAlive: true)
HeartbeatRepository heartbeatRepository(Ref ref) =>
    LocalHeartbeatRepository(ref.watch(appDatabaseProvider).requireValue);

/// Stored device events (session start / stop, errors): the local database in both phases.
// TODO(phase2): the uploader sends them with the readings.
@Riverpod(keepAlive: true)
DeviceEventRepository deviceEventRepository(Ref ref) =>
    LocalDeviceEventRepository(ref.watch(appDatabaseProvider).requireValue);

/// Deletes readings and device events older than the config's `history.daysOnPhone`, and
/// heartbeats older than 24 hours, now and once a day.
@Riverpod(keepAlive: true)
ReadingCleanupJob readingCleanupJob(Ref ref) {
  final days = ref.watch(appConfigProvider).requireValue.history.daysOnPhone;
  final job = ReadingCleanupJob(
    ref.watch(readingRepositoryProvider),
    days,
    heartbeats: ref.watch(heartbeatRepositoryProvider),
    events: ref.watch(deviceEventRepositoryProvider),
  )..start();
  ref.onDispose(job.stop);
  return job;
}

/// Live readings work the same in both phases: from the one connected device to the screen and
/// the local database. Debug builds also play made-up readings for dummy devices (home's hidden
/// long-press), so every dashboard can be tried without hardware.
@Riverpod(keepAlive: true)
LiveReadings liveReadings(Ref ref) {
  final profiles = DeviceProfileRegistry(ref.watch(appConfigProvider).requireValue);
  final db = ref.watch(appDatabaseProvider).requireValue;
  final readings = ref.watch(readingRepositoryProvider);
  final heartbeats = ref.watch(heartbeatRepositoryProvider);
  final events = ref.watch(deviceEventRepositoryProvider);
  DeviceProfile? profileFor(String id) => profiles.contains(id) ? profiles.byId(id) : null;
  ReadingWriter writerFor(int deviceId, DeviceProfile profile) => ReadingWriter(
    deviceId,
    readings,
    (id, percent) => db.devicesDao.updateStatus(id, batteryPercent: percent),
    events: events,
    skip: waveformKeys(profile),
  );
  HeartbeatRecorder recorderFor(int deviceId, HeartbeatSettings settings) => HeartbeatRecorder(
    deviceId,
    heartbeats,
    (id, seenAt) => db.devicesDao.updateStatus(id, lastHeartbeatAt: seenAt),
    interval: settings.interval,
  );
  final LiveReadings active = ActiveDevice(
    db,
    profileFor,
    ref.watch(deviceLinkFactoryProvider),
    writerFor,
    recorderFor,
  );
  final live = kDebugMode
      ? DemoLiveReadings(
          active,
          (id) async {
            final row = await db.devicesDao.byId(id);
            return row == null ? null : (address: row.address, profileId: row.profileId);
          },
          profileFor,
          writerFor,
          recorderFor,
        )
      : active;
  ref.onDispose(live.stop);
  return live;
}

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

/// Sync now on the dashboard (requirement 5.6) exists only with the cloud; Phase 1 does not
/// show the button, without checking isCloud itself.
@Riverpod(keepAlive: true)
bool syncNowAvailable(Ref ref) => ref.watch(appConfigProvider).requireValue.isCloud;

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
