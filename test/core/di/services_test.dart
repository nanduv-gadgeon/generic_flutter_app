import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/di/database.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/data/auth/cloud_auth_service.dart';
import 'package:generic_flutter_app/data/auth/local_auth_service.dart';
import 'package:generic_flutter_app/data/cloud/cloud_backend_health.dart';
import 'package:generic_flutter_app/data/cloud/local_backend_health.dart';
import 'package:generic_flutter_app/data/devices/cloud_device_registration.dart';
import 'package:generic_flutter_app/data/devices/local_device_service.dart';
import 'package:generic_flutter_app/data/devices/no_device_registration.dart';
import 'package:generic_flutter_app/data/export/local_export_service.dart';
import 'package:generic_flutter_app/data/upload/cloud_uploader.dart';
import 'package:generic_flutter_app/domain/models/new_device.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/upload/no_uploader.dart';

import '../../fixtures/test_config.dart';

Future<ProviderContainer> _containerFor({required bool isCloud, bool export = true}) async {
  final json = validConfigJson(isCloud: isCloud);
  (json['features'] as Map<String, dynamic>)['export'] = export;
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith((ref) async => AppConfig.fromJson(json)),
      appDatabaseProvider.overrideWith((ref) async {
        final db = AppDatabase(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appConfigProvider.future);
  await container.read(appDatabaseProvider.future);
  return container;
}

void main() {
  test('isCloud false wires the Phase 1 services', () async {
    final container = await _containerFor(isCloud: false);

    expect(container.read(uploaderProvider), isA<NoUploader>());
    expect(container.read(backendHealthProvider), isA<LocalBackendHealth>());
    expect(container.read(authServiceProvider), isA<LocalAuthService>());
    expect(container.read(deviceRegistrationProvider), isA<NoDeviceRegistration>());
    expect(container.read(cloudRegistrationAvailableProvider), isFalse);
    expect(container.read(deviceServiceProvider), isA<LocalDeviceService>());
  });

  test('isCloud true wires the Phase 2 hooks', () async {
    final container = await _containerFor(isCloud: true);

    expect(container.read(uploaderProvider), isA<CloudUploader>());
    expect(container.read(backendHealthProvider), isA<CloudBackendHealth>());
    expect(container.read(authServiceProvider), isA<CloudAuthService>());
    expect(container.read(deviceRegistrationProvider), isA<CloudDeviceRegistration>());
    expect(container.read(cloudRegistrationAvailableProvider), isTrue);
  });

  // (isCloud, features.export) -> Export offered on History
  final exportCases = {(false, true): true, (true, true): false, (false, false): false};
  for (final MapEntry(key: (isCloud, export), value: offered) in exportCases.entries) {
    test('export offered: isCloud $isCloud, feature $export -> $offered', () async {
      final container = await _containerFor(isCloud: isCloud, export: export);
      expect(container.read(exportAvailableProvider), offered);
    });
  }

  test('export makes files from the local database', () async {
    final container = await _containerFor(isCloud: false);
    expect(container.read(exportServiceProvider), isA<LocalExportService>());
  });

  test('the PDF font comes from the config\'s theme font', () {
    expect(reportFontPath('Nunito', bold: false), 'assets/fonts/Nunito/Nunito-Regular.ttf');
    expect(reportFontPath('Nunito', bold: true), 'assets/fonts/Nunito/Nunito-Bold.ttf');
  });

  // Phase 1 must not register anywhere; the Phase 2 hook is empty until the cloud API exists.
  for (final isCloud in [false, true]) {
    test('device registration returns nothing yet (isCloud $isCloud)', () async {
      final container = await _containerFor(isCloud: isCloud);
      const device = NewDevice(
        userId: 1,
        profileId: 'test_device_v1',
        transport: Transport.ble,
        address: 'AA:BB:CC:00:00:01',
        name: 'Test band',
      );

      expect(await container.read(deviceRegistrationProvider).register(device), isNull);
    });
  }

  test('Phase 1 backend is always reachable', () async {
    expect(await const LocalBackendHealth().isReachable(), isTrue);
  });
}
