import '../alerts/alert.dart';

export '../alerts/alert.dart';

/// The alerts raised on this phone. Values are health data: never log them.
abstract interface class AlertRepository {
  /// Stores [alert] and returns its id.
  Future<int> add(RaisedAlert alert);

  /// [userId]'s alerts, newest first; emits again when they change.
  Stream<List<RaisedAlert>> watchAll(int userId);

  /// How many of [userId]'s alerts are not read yet; emits again when it changes.
  Stream<int> watchUnreadCount(int userId);

  /// Marks all of [userId]'s alerts read.
  Future<void> markAllRead(int userId);

  /// Deletes [userId]'s alert [alertId]; nothing if it is not theirs.
  Future<void> delete(int userId, int alertId);

  /// Deletes all of [userId]'s alerts.
  Future<void> deleteAll(int userId);

  /// Deletes alerts raised before [before]; returns how many.
  Future<int> deleteOlderThan(DateTime before);
}
