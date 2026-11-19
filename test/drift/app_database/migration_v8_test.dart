// dart format width=80
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v7.dart' as v7;
import 'generated/schema_v8.dart' as v8;

/// Schema v8 (task 1.5.3): the raised alerts table.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  // Devices, readings, heartbeats and events stay as they were, with no alerts yet.
  test('migration from v7 to v8 does not corrupt data', () async {
    final oldUsersData = <v7.UsersData>[
      v7.UsersData(
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
    final oldDevicesData = <v7.DevicesData>[
      const v7.DevicesData(
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
    final oldReadingsData = <v7.ReadingsData>[
      const v7.ReadingsData(
        id: 1,
        deviceId: 1,
        key: 'heart_rate',
        value: 70,
        atMs: 1767225600000,
      ),
    ];
    final oldHeartbeatsData = <v7.HeartbeatsData>[
      const v7.HeartbeatsData(
        id: 1,
        deviceId: 1,
        atMs: 1767225600000,
        batteryPercent: 80,
      ),
    ];
    final oldEventsData = <v7.DeviceEventsData>[
      const v7.DeviceEventsData(
        id: 1,
        deviceId: 1,
        kind: 'start',
        code: 0,
        atMs: 1767225600000,
      ),
    ];
    final expectedNewDevicesData = <v8.DevicesData>[
      const v8.DevicesData(
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
    final expectedNewReadingsData = <v8.ReadingsData>[
      const v8.ReadingsData(
        id: 1,
        deviceId: 1,
        key: 'heart_rate',
        value: 70,
        atMs: 1767225600000,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 7,
      newVersion: 8,
      createOld: v7.DatabaseAtV7.new,
      createNew: v8.DatabaseAtV8.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.users, oldUsersData);
        batch.insertAll(oldDb.devices, oldDevicesData);
        batch.insertAll(oldDb.readings, oldReadingsData);
        batch.insertAll(oldDb.heartbeats, oldHeartbeatsData);
        batch.insertAll(oldDb.deviceEvents, oldEventsData);
      },
      validateItems: (newDb) async {
        expect(expectedNewDevicesData, await newDb.select(newDb.devices).get());
        expect(
          expectedNewReadingsData,
          await newDb.select(newDb.readings).get(),
        );
        expect(await newDb.select(newDb.heartbeats).get(), [
          const v8.HeartbeatsData(
            id: 1,
            deviceId: 1,
            atMs: 1767225600000,
            batteryPercent: 80,
          ),
        ]);
        expect(await newDb.select(newDb.deviceEvents).get(), [
          const v8.DeviceEventsData(
            id: 1,
            deviceId: 1,
            kind: 'start',
            code: 0,
            atMs: 1767225600000,
          ),
        ]);
        expect(await newDb.select(newDb.raisedAlerts).get(), isEmpty);
      },
    );
  });
}
