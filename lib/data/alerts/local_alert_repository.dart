import 'package:drift/drift.dart';

import '../../domain/services/alert_repository.dart';
import '../db/app_database.dart';

/// [AlertRepository] in the local database (both phases).
class LocalAlertRepository implements AlertRepository {
  LocalAlertRepository(this._db);

  final AppDatabase _db;

  @override
  Future<int> add(RaisedAlert alert) => _db.alertsDao.add(
    RaisedAlertsCompanion.insert(
      deviceId: alert.deviceId,
      kind: alert.kind.name,
      readingKey: Value(alert.key),
      value: Value(alert.value),
      limitValue: Value(alert.limit),
      atMs: alert.at.toUtc().millisecondsSinceEpoch,
      isRead: Value(alert.read),
    ),
  );

  @override
  Stream<List<RaisedAlert>> watchAll(int userId) =>
      _db.alertsDao.watchForUser(userId).map((rows) => rows.map(_toAlert).nonNulls.toList());

  @override
  Stream<int> watchUnreadCount(int userId) => _db.alertsDao.watchUnreadCount(userId);

  @override
  Future<void> markAllRead(int userId, {Set<AlertKind>? kinds}) =>
      _db.alertsDao.markAllRead(userId, kinds: _names(kinds));

  @override
  Future<void> delete(int userId, int alertId) => _db.alertsDao.deleteOne(userId, alertId);

  @override
  Future<void> deleteAll(int userId, {Set<AlertKind>? kinds}) =>
      _db.alertsDao.deleteAllFor(userId, kinds: _names(kinds));

  static Set<String>? _names(Set<AlertKind>? kinds) => kinds?.map((k) => k.name).toSet();

  @override
  Future<int> deleteOlderThan(DateTime before) =>
      _db.alertsDao.deleteOlderThan(before.toUtc().millisecondsSinceEpoch);

  /// Null for a kind this version does not know.
  static RaisedAlert? _toAlert(RaisedAlertRow row) {
    final kind = AlertKind.values.asNameMap()[row.kind];
    if (kind == null) return null;
    return RaisedAlert(
      id: row.id,
      deviceId: row.deviceId,
      kind: kind,
      key: row.readingKey,
      value: row.value,
      limit: row.limitValue,
      at: DateTime.fromMillisecondsSinceEpoch(row.atMs, isUtc: true),
      read: row.isRead,
    );
  }
}
