// dart format width=80
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;

/// Schema v4 (task 1.3.3); the earlier steps are in migration_test.dart.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  // v4 adds the readings table: existing devices and alert limits stay as
  // they were, with no readings yet.
  test('migration from v3 to v4 does not corrupt data', () async {
    final oldUsersData = <v3.UsersData>[
      v3.UsersData(
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
    final oldDevicesData = <v3.DevicesData>[
      const v3.DevicesData(
        id: 1,
        userId: 1,
        name: 'Test band',
        profileId: 'test_device_v1',
        transport: 'wifi',
        address: 'test-device-1',
        ipAddress: '192.168.0.10',
        sortOrder: 0,
        createdAt: 1767225600,
      ),
    ];
    final oldAlertsData = <v3.DeviceAlertsData>[
      const v3.DeviceAlertsData(
        deviceId: 1,
        readingKey: 'heart_rate',
        above: 120,
        enabled: 1,
      ),
    ];
    final expectedNewDevicesData = <v4.DevicesData>[
      const v4.DevicesData(
        id: 1,
        userId: 1,
        name: 'Test band',
        profileId: 'test_device_v1',
        transport: 'wifi',
        address: 'test-device-1',
        ipAddress: '192.168.0.10',
        sortOrder: 0,
        createdAt: 1767225600,
      ),
    ];
    final expectedNewAlertsData = <v4.DeviceAlertsData>[
      const v4.DeviceAlertsData(
        deviceId: 1,
        readingKey: 'heart_rate',
        above: 120,
        enabled: 1,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 4,
      createOld: v3.DatabaseAtV3.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.users, oldUsersData);
        batch.insertAll(oldDb.devices, oldDevicesData);
        batch.insertAll(oldDb.deviceAlerts, oldAlertsData);
      },
      validateItems: (newDb) async {
        expect(expectedNewDevicesData, await newDb.select(newDb.devices).get());
        expect(
          expectedNewAlertsData,
          await newDb.select(newDb.deviceAlerts).get(),
        );
        expect(await newDb.select(newDb.readings).get(), isEmpty);
      },
    );
  });

  // Some test builds reached v3 through another branch (field length limits
  // only), without devices.ip_address and device_alerts, so saving a device
  // failed. The v4 step adds what is missing.
  test(
    'v4 repairs a v3 database without ip_address and device_alerts',
    () async {
      final schema = await verifier.schemaAt(2);
      schema.rawDatabase.execute('PRAGMA user_version = 3');
      final db = AppDatabase(schema.newConnection());

      await verifier.migrateAndValidate(db, 4);
      final userId = await db.usersDao.insertUser(
        UsersCompanion.insert(
          name: 'Test User',
          email: 'test@example.com',
          mobile: '+10000000000',
          passwordHash: Uint8List.fromList([1, 2, 3]),
          passwordSalt: Uint8List.fromList([4, 5, 6]),
          hashParams: 'test;m=1;t=1;p=1',
          termsAcceptedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await db.devicesDao.addDevice(
        DevicesCompanion.insert(
          userId: userId,
          name: 'Test device',
          profileId: 'test_device_v1',
          transport: DeviceTransport.wifi,
          address: 'test-device-1',
          ipAddress: const Value('192.168.0.10'),
          sortOrder: 0,
        ),
      );

      expect(
        (await db.select(db.devices).getSingle()).ipAddress,
        '192.168.0.10',
      );
      await db.close();
    },
  );
}
