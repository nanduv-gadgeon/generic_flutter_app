import 'package:drift/drift.dart';

import '../app_database.dart';

part 'settings_dao.g.dart';

/// Per-user app settings. A user without a row gets the defaults.
@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  /// Whether [userId] wants notifications; true until they turn them off.
  Stream<bool> watchNotifications(int userId) =>
      (select(appSettings)..where((s) => s.userId.equals(userId))).watchSingleOrNull().map(
        (row) => row?.notificationsEnabled ?? true,
      );

  Future<void> setNotifications(int userId, {required bool enabled}) => into(appSettings).insert(
    AppSettingsCompanion.insert(userId: Value(userId), notificationsEnabled: Value(enabled)),
    onConflict: DoUpdate((_) => AppSettingsCompanion(notificationsEnabled: Value(enabled))),
  );
}
