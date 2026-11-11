// dart format width=80
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

/// Schema v5 (task 1.2.8): the heartbeats table.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  // Devices and readings stay as they were, with no heartbeats yet.
  test('migration from v4 to v5 does not corrupt data', () async {
    final oldUsersData = <v4.UsersData>[
      v4.UsersData(
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
    final oldDevicesData = <v4.DevicesData>[
      const v4.DevicesData(
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
    final oldReadingsData = <v4.ReadingsData>[
      const v4.ReadingsData(
        id: 1,
        deviceId: 1,
        key: 'heart_rate',
        value: 70,
        atMs: 1767225600000,
      ),
    ];
    final expectedNewDevicesData = <v5.DevicesData>[
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
    final expectedNewReadingsData = <v5.ReadingsData>[
      const v5.ReadingsData(
        id: 1,
        deviceId: 1,
        key: 'heart_rate',
        value: 70,
        atMs: 1767225600000,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 4,
      newVersion: 5,
      createOld: v4.DatabaseAtV4.new,
      createNew: v5.DatabaseAtV5.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.users, oldUsersData);
        batch.insertAll(oldDb.devices, oldDevicesData);
        batch.insertAll(oldDb.readings, oldReadingsData);
      },
      validateItems: (newDb) async {
        expect(expectedNewDevicesData, await newDb.select(newDb.devices).get());
        expect(
          expectedNewReadingsData,
          await newDb.select(newDb.readings).get(),
        );
        expect(await newDb.select(newDb.heartbeats).get(), isEmpty);
      },
    );
  });
}
