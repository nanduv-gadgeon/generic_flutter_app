import 'package:drift/drift.dart';

import '../app_database.dart';

part 'device_events_dao.g.dart';

/// Sessions and errors devices logged.
@DriftAccessor(tables: [DeviceEvents])
class DeviceEventsDao extends DatabaseAccessor<AppDatabase> with _$DeviceEventsDaoMixin {
  DeviceEventsDao(super.attachedDatabase);

  /// Adds [row]; an event already stored (same device, time and kind) is kept as it is.
  Future<void> add(DeviceEventsCompanion row) =>
      into(deviceEvents).insert(row, mode: InsertMode.insertOrIgnore);

  /// The device's events from [fromMs] on, oldest first; emits again when one is added.
  Stream<List<DeviceEventRow>> watchSince(int deviceId, int fromMs) =>
      (select(deviceEvents)
            ..where((e) => e.deviceId.equals(deviceId) & e.atMs.isBiggerOrEqualValue(fromMs))
            ..orderBy([(e) => OrderingTerm.asc(e.atMs)]))
          .watch();

  /// Deletes events from before [beforeMs]; returns how many.
  Future<int> deleteOlderThan(int beforeMs) =>
      (delete(deviceEvents)..where((e) => e.atMs.isSmallerThanValue(beforeMs))).go();
}
