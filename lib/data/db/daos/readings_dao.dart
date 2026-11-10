import 'package:drift/drift.dart';

import '../app_database.dart';

part 'readings_dao.g.dart';

/// Stored device readings. Values are health data: never log them.
@DriftAccessor(tables: [Readings])
class ReadingsDao extends DatabaseAccessor<AppDatabase> with _$ReadingsDaoMixin {
  ReadingsDao(super.attachedDatabase);

  /// Adds [rows] in one transaction; a reading already stored (same device, key and time) is
  /// skipped.
  Future<void> addAll(List<ReadingsCompanion> rows) {
    if (rows.isEmpty) return Future.value();
    return batch((b) => b.insertAll(readings, rows, mode: InsertMode.insertOrIgnore));
  }

  /// The device's [key] readings measured at or after [fromMs], oldest first.
  Stream<List<Reading>> watchRange(int deviceId, String key, int fromMs) =>
      (select(readings)
            ..where(
              (r) =>
                  r.deviceId.equals(deviceId) &
                  r.key.equals(key) &
                  r.atMs.isBiggerOrEqualValue(fromMs),
            )
            ..orderBy([(r) => OrderingTerm.asc(r.atMs)]))
          .watch();

  /// The newest reading of each key the device has.
  Stream<List<Reading>> watchLatest(int deviceId) => customSelect(
    'SELECT r.* FROM readings r '
    'JOIN (SELECT "key" AS k, MAX(at_ms) AS m FROM readings WHERE device_id = ?1 GROUP BY "key") '
    'last ON r."key" = last.k AND r.at_ms = last.m '
    'WHERE r.device_id = ?1',
    variables: [Variable.withInt(deviceId)],
    readsFrom: {readings},
  ).watch().map((rows) => [for (final row in rows) readings.map(row.data)]);

  /// Deletes readings measured before [beforeMs]; returns how many.
  Future<int> deleteOlderThan(int beforeMs) =>
      (delete(readings)..where((r) => r.atMs.isSmallerThanValue(beforeMs))).go();
}
