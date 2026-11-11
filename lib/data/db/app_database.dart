import 'package:drift/drift.dart';

import 'app_database.steps.dart';
import 'daos/device_events_dao.dart';
import 'daos/devices_dao.dart';
import 'daos/heartbeats_dao.dart';
import 'daos/readings_dao.dart';
import 'daos/session_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/users_dao.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

/// The encrypted local database (same in both phases).
///
/// Changing the schema: bump [schemaVersion], run `dart run drift_dev make-migrations`, then
/// write the migration step and its test.
@DriftDatabase(
  tables: [Users, Sessions, Devices, AppSettings, DeviceAlerts, Readings, Heartbeats, DeviceEvents],
  daos: [
    UsersDao,
    SessionDao,
    DevicesDao,
    SettingsDao,
    ReadingsDao,
    HeartbeatsDao,
    DeviceEventsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Use [openEncryptedDatabase] in the app; tests pass `NativeDatabase.memory()`.
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      // v2 (task 1.1.11): per-user settings, starting with the notifications switch.
      from1To2: (m, schema) => m.createTable(schema.appSettings),
      // v3 (task 1.2.7): per-device alert limits, and the last IP of Wi‑Fi devices.
      from2To3: (m, schema) async {
        await m.createTable(schema.deviceAlerts);
        await m.addColumn(schema.devices, schema.devices.ipAddress);
      },
      // v4 (task 1.3.3): stored readings. Some test builds reached v3 through another branch
      // without ip_address and device_alerts, so add those too when they are missing.
      from3To4: (m, schema) async {
        final columns = await customSelect('PRAGMA table_info(devices)').get();
        if (!columns.any((c) => c.read<String>('name') == 'ip_address')) {
          await m.addColumn(schema.devices, schema.devices.ipAddress);
        }
        final alerts = await customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'device_alerts'",
        ).get();
        if (alerts.isEmpty) await m.createTable(schema.deviceAlerts);
        await m.createTable(schema.readings);
        await m.createIndex(schema.readingsDeviceKeyTime);
      },
      // v5 (task 1.2.8): heartbeats, kept for 24 hours.
      from4To5: (m, schema) async {
        await m.createTable(schema.heartbeats);
        await m.createIndex(schema.heartbeatsDeviceTime);
      },
      // v6 (task 1.3.4): device events (session start / stop, errors) for the dashboard.
      from5To6: (m, schema) async {
        await m.createTable(schema.deviceEvents);
        await m.createIndex(schema.deviceEventsDeviceTime);
      },
    ),
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
