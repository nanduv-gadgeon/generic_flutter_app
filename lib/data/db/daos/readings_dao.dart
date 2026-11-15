import 'package:drift/drift.dart';

import '../app_database.dart';

part 'readings_dao.g.dart';

/// One hour of one device's readings of one key, added up (see [ReadingsDao.hourStats]).
typedef HourRow = ({
  int deviceId,
  String key,
  int bucket,
  double min,
  double max,
  double sum,
  int count,
});

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

  /// The readings measured from [fromMs] to [toMs] (not included), of [deviceId] or of every
  /// device, added up per device, key and hour: `bucket` counts whole hours from [fromMs]. One
  /// pass over the table, so a whole week costs one query.
  Future<List<HourRow>> hourStats(int fromMs, int toMs, {int? deviceId}) =>
      customSelect(
        'SELECT device_id, "key", (at_ms - ?1) / 3600000 AS bucket, MIN(value) AS lo, '
        'MAX(value) AS hi, SUM(value) AS total, COUNT(*) AS n FROM readings '
        'WHERE at_ms >= ?1 AND at_ms < ?2${deviceId == null ? '' : ' AND device_id = ?3'} '
        'GROUP BY device_id, "key", bucket',
        variables: [
          Variable.withInt(fromMs),
          Variable.withInt(toMs),
          if (deviceId != null) Variable.withInt(deviceId),
        ],
        readsFrom: {readings},
      ).get().then(
        (rows) => [
          for (final r in rows)
            (
              deviceId: r.read<int>('device_id'),
              key: r.read<String>('key'),
              bucket: r.read<int>('bucket'),
              min: r.read<double>('lo'),
              max: r.read<double>('hi'),
              sum: r.read<double>('total'),
              count: r.read<int>('n'),
            ),
        ],
      );

  /// Deletes readings measured before [beforeMs]; returns how many.
  Future<int> deleteOlderThan(int beforeMs) =>
      (delete(readings)..where((r) => r.atMs.isSmallerThanValue(beforeMs))).go();
}
