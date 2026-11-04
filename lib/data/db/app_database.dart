import 'package:drift/drift.dart';

import 'app_database.steps.dart';
import 'daos/devices_dao.dart';
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
  tables: [Users, Sessions, Devices, AppSettings],
  daos: [UsersDao, SessionDao, DevicesDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  /// Use [openEncryptedDatabase] in the app; tests pass `NativeDatabase.memory()`.
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      // v2 (task 1.1.11): per-user settings, starting with the notifications switch.
      from1To2: (m, schema) => m.createTable(schema.appSettings),
    ),
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
