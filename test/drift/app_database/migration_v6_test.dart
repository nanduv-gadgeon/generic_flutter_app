// dart format width=80
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;

/// Schema v6 (task 1.3.4): the device events table.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  // Devices, readings and heartbeats stay as they were, with no events yet.
  test('migration from v5 to v6 does not corrupt data', () async {
    final oldUsersData = <v5.UsersData>[
      v5.UsersData(
        id: 1,
        name: 'Test User',
        email: 'test@example.com',
        mobile: '+91 0000000000',
        passwordHash: Uint8List.fromList([1, 2, 3]),
        passwordSalt: Uint8List.fromList([4, 5, 6]),
        hashParams: 'test;m=1;t=1;p=1',
        failedLoginCount: 0,
        biometricEnabled: 0,
        termsAcceptedAt: 1767225600,
        createdAt: 1767225600,
        updatedAt: 1767225600,
      ),
    ];
    final oldDevicesData = <v5.DevicesData>[
      const v5.DevicesData(
        id: 1,
        userId: 1,
        name: 'Test band',
        profileId: 'test_device_v1',
        transport: 'ble',
        address: 'test-device-1',
        sortOrder: 0,
        createdAt: 1767225600,
        lastHeartbeatAt: 1767225600,
      ),
    ];
    final oldReadingsData = <v5.ReadingsData>[
      const v5.ReadingsData(
        id: 1,
        deviceId: 1,
        key: 'heart_rate',
        value: 70,
        atMs: 1767225600000,
      ),
    ];
    final oldHeartbeatsData = <v5.HeartbeatsData>[
      const v5.HeartbeatsData(
        id: 1,
        deviceId: 1,
        atMs: 1767225600000,
        batteryPercent: 80,
      ),
    ];
    final expectedNewDevicesData = <v6.DevicesData>[
      const v6.DevicesData(
        id: 1,
        userId: 1,
        name: 'Test band',
        profileId: 'test_device_v1',
        transport: 'ble',
        address: 'test-device-1',
        sortOrder: 0,
        createdAt: 1767225600,
        lastHeartbeatAt: 1767225600,
      ),
    ];
    final expectedNewReadingsData = <v6.ReadingsData>[
      const v6.ReadingsData(
        id: 1,
        deviceId: 1,
        key: 'heart_rate',
        value: 70,
        atMs: 1767225600000,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 5,
      newVersion: 6,
      createOld: v5.DatabaseAtV5.new,
      createNew: v6.DatabaseAtV6.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.users, oldUsersData);
        batch.insertAll(oldDb.devices, oldDevicesData);
        batch.insertAll(oldDb.readings, oldReadingsData);
        batch.insertAll(oldDb.heartbeats, oldHeartbeatsData);
      },
      validateItems: (newDb) async {
        expect(expectedNewDevicesData, await newDb.select(newDb.devices).get());
        expect(
          expectedNewReadingsData,
          await newDb.select(newDb.readings).get(),
        );
        expect(await newDb.select(newDb.heartbeats).get(), [
          const v6.HeartbeatsData(
            id: 1,
            deviceId: 1,
            atMs: 1767225600000,
            batteryPercent: 80,
          ),
        ]);
        expect(await newDb.select(newDb.deviceEvents).get(), isEmpty);
      },
    );
  });
}
