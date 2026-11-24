import 'package:drift/drift.dart';

import '../app_database.dart';

part 'alerts_dao.g.dart';

/// Alerts the phone raised. Values are health data: never log them.
@DriftAccessor(tables: [RaisedAlerts, Devices])
class AlertsDao extends DatabaseAccessor<AppDatabase> with _$AlertsDaoMixin {
  AlertsDao(super.attachedDatabase);

  /// Stores [row] and returns its id.
  Future<int> add(RaisedAlertsCompanion row) => into(raisedAlerts).insert(row);

  /// The alerts of [userId]'s devices, newest first; emits again when they change.
  Stream<List<RaisedAlertRow>> watchForUser(int userId) {
    final query =
        select(raisedAlerts).join([innerJoin(devices, devices.id.equalsExp(raisedAlerts.deviceId))])
          ..where(devices.userId.equals(userId))
          ..orderBy([OrderingTerm.desc(raisedAlerts.atMs), OrderingTerm.desc(raisedAlerts.id)]);
    return query.watch().map((rows) => [for (final row in rows) row.readTable(raisedAlerts)]);
  }

  /// How many of [userId]'s alerts are not read; emits again when it changes.
  Stream<int> watchUnreadCount(int userId) {
    final count = raisedAlerts.id.count();
    final query =
        selectOnly(raisedAlerts)
            .join([innerJoin(devices, devices.id.equalsExp(raisedAlerts.deviceId))])
          ..addColumns([count])
          ..where(devices.userId.equals(userId) & raisedAlerts.isRead.equals(false));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Marks all of [userId]'s alerts read; with [kinds], only alerts of those kinds.
  Future<void> markAllRead(int userId, {Set<String>? kinds}) =>
      (update(raisedAlerts)..where(
            (a) =>
                a.isRead.equals(false) &
                a.deviceId.isInQuery(_deviceIdsOf(userId)) &
                _ofKinds(a, kinds),
          ))
          .write(const RaisedAlertsCompanion(isRead: Value(true)));

  /// Deletes [userId]'s alert [alertId]; nothing if it is not theirs.
  Future<void> deleteOne(int userId, int alertId) => (delete(
    raisedAlerts,
  )..where((a) => a.id.equals(alertId) & a.deviceId.isInQuery(_deviceIdsOf(userId)))).go();

  /// Deletes all of [userId]'s alerts; with [kinds], only alerts of those kinds.
  Future<void> deleteAllFor(int userId, {Set<String>? kinds}) => (delete(
    raisedAlerts,
  )..where((a) => a.deviceId.isInQuery(_deviceIdsOf(userId)) & _ofKinds(a, kinds))).go();

  /// Alerts of [kinds]; every alert when null.
  static Expression<bool> _ofKinds($RaisedAlertsTable a, Set<String>? kinds) =>
      kinds == null ? const Constant(true) : a.kind.isIn(kinds);

  /// The ids of [userId]'s devices.
  JoinedSelectStatement<HasResultSet, dynamic> _deviceIdsOf(int userId) => selectOnly(devices)
    ..addColumns([devices.id])
    ..where(devices.userId.equals(userId));

  /// Deletes alerts raised before [beforeMs]; returns how many.
  Future<int> deleteOlderThan(int beforeMs) =>
      (delete(raisedAlerts)..where((a) => a.atMs.isSmallerThanValue(beforeMs))).go();
}
