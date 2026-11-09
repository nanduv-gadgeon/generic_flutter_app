// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // v2 only adds the app_settings table: existing accounts, the session and
  // devices must come through unchanged, with no settings rows yet (defaults).
  // Fake data only; dates and booleans are stored as integers.
  test('migration from v1 to v2 does not corrupt data', () async {
    final hash = Uint8List.fromList([1, 2, 3]);
    final salt = Uint8List.fromList([4, 5, 6]);

    final oldUsersData = <v1.UsersData>[
      v1.UsersData(
        id: 1,
        name: 'Test User',
        email: 'test@example.com',
        mobile: '+91 0000000000',
        passwordHash: hash,
        passwordSalt: salt,
        hashParams: 'test;m=1;t=1;p=1',
        failedLoginCount: 0,
        biometricEnabled: 0,
        termsAcceptedAt: 1767225600,
        createdAt: 1767225600,
        updatedAt: 1767225600,
      ),
    ];
    final expectedNewUsersData = <v2.UsersData>[
      v2.UsersData(
        id: 1,
        name: 'Test User',
        email: 'test@example.com',
        mobile: '+91 0000000000',
        passwordHash: hash,
        passwordSalt: salt,
        hashParams: 'test;m=1;t=1;p=1',
        failedLoginCount: 0,
        biometricEnabled: 0,
        termsAcceptedAt: 1767225600,
        createdAt: 1767225600,
        updatedAt: 1767225600,
      ),
    ];

    final oldSessionsData = <v1.SessionsData>[
      const v1.SessionsData(
        id: 1,
        userId: 1,
        startedAt: 1767225600,
        lastActiveAt: 1767225600,
      ),
    ];
    final expectedNewSessionsData = <v2.SessionsData>[
      const v2.SessionsData(
        id: 1,
        userId: 1,
        startedAt: 1767225600,
        lastActiveAt: 1767225600,
      ),
    ];

    final oldDevicesData = <v1.DevicesData>[
      const v1.DevicesData(
        id: 1,
        userId: 1,
        name: 'Test band',
        profileId: 'test_device_v1',
        transport: 'ble',
        address: 'AA:BB:CC:00:00:01',
        sortOrder: 0,
        createdAt: 1767225600,
      ),
    ];
    final expectedNewDevicesData = <v2.DevicesData>[
      const v2.DevicesData(
        id: 1,
        userId: 1,
        name: 'Test band',
        profileId: 'test_device_v1',
        transport: 'ble',
        address: 'AA:BB:CC:00:00:01',
        sortOrder: 0,
        createdAt: 1767225600,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.users, oldUsersData);
        batch.insertAll(oldDb.sessions, oldSessionsData);
        batch.insertAll(oldDb.devices, oldDevicesData);
      },
      validateItems: (newDb) async {
        expect(expectedNewUsersData, await newDb.select(newDb.users).get());
        expect(
          expectedNewSessionsData,
          await newDb.select(newDb.sessions).get(),
        );
        expect(expectedNewDevicesData, await newDb.select(newDb.devices).get());
        expect(await newDb.select(newDb.appSettings).get(), isEmpty);
      },
    );
  });

  // v3 adds the device_alerts table and devices.ip_address: existing devices
  // keep their data, with no IP and no alert rows yet.
  test('migration from v2 to v3 does not corrupt data', () async {
    final oldUsersData = <v2.UsersData>[
      v2.UsersData(
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
    final oldDevicesData = <v2.DevicesData>[
      const v2.DevicesData(
        id: 1,
        userId: 1,
        name: 'Test band',
        profileId: 'test_device_v1',
        transport: 'ble',
        address: 'AA:BB:CC:00:00:01',
        sortOrder: 0,
        createdAt: 1767225600,
      ),
    ];
    final expectedNewDevicesData = <v3.DevicesData>[
      const v3.DevicesData(
        id: 1,
        userId: 1,
        name: 'Test band',
        profileId: 'test_device_v1',
        transport: 'ble',
        address: 'AA:BB:CC:00:00:01',
        sortOrder: 0,
        createdAt: 1767225600,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.users, oldUsersData);
        batch.insertAll(oldDb.devices, oldDevicesData);
      },
      validateItems: (newDb) async {
        expect(expectedNewDevicesData, await newDb.select(newDb.devices).get());
        expect(await newDb.select(newDb.deviceAlerts).get(), isEmpty);
      },
    );
  });
}
