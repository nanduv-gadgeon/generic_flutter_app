/// Each user's app settings, kept on the phone in both phases.
abstract interface class AppSettingsService {
  /// Whether [userId] wants notifications; true until they turn them off.
  Stream<bool> watchNotificationsEnabled(int userId);

  Future<void> setNotificationsEnabled(int userId, {required bool enabled});
}
