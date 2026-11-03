import 'package:drift/drift.dart';

import 'daos/devices_dao.dart';
import 'daos/session_dao.dart';
import 'daos/users_dao.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

/// The encrypted local database (same in both phases).
///
/// Changing the schema: bump [schemaVersion], run `dart run drift_dev make-migrations`, then
/// write the migration step and its test.
@DriftDatabase(tables: [Users, Sessions, Devices], daos: [UsersDao, SessionDao, DevicesDao])
class AppDatabase extends _$AppDatabase {
  /// Use [openEncryptedDatabase] in the app; tests pass `NativeDatabase.memory()`.
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
