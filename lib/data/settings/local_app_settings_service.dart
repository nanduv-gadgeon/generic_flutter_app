import '../../domain/services/app_settings_service.dart';
import '../db/app_database.dart';

/// App settings in the local database (both phases: notifications are local).
class LocalAppSettingsService implements AppSettingsService {
  const LocalAppSettingsService(this._db);

  final AppDatabase _db;

  @override
  Stream<bool> watchNotificationsEnabled(int userId) => _db.settingsDao.watchNotifications(userId);

  @override
  Future<void> setNotificationsEnabled(int userId, {required bool enabled}) =>
      _db.settingsDao.setNotifications(userId, enabled: enabled);
}
