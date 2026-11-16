import 'package:drift/drift.dart';

import '../app_database.dart';

part 'daily_summaries_dao.g.dart';

/// Each device's readings summed up per key and day. Values are health data: never log them.
@DriftAccessor(tables: [DailySummaries])
class DailySummariesDao extends DatabaseAccessor<AppDatabase> with _$DailySummariesDaoMixin {
  DailySummariesDao(super.attachedDatabase);

  /// Replaces the summaries of days [fromDay] to [toDay] (yyyymmdd, [toDay] not included), of
  /// [deviceId] or of every device, with [rows], in one transaction. A day left out of [rows]
  /// loses its old summary.
  Future<void> replaceDays({
    int? deviceId,
    required int fromDay,
    required int toDay,
    required List<DailySummariesCompanion> rows,
  }) => transaction(() async {
    await (delete(dailySummaries)..where(
          (s) =>
              s.day.isBiggerOrEqualValue(fromDay) &
              s.day.isSmallerThanValue(toDay) &
              (deviceId == null ? const Constant(true) : s.deviceId.equals(deviceId)),
        ))
        .go();
    if (rows.isNotEmpty) await batch((b) => b.insertAll(dailySummaries, rows));
  });

  /// The device's [key] summaries from [fromDay] (yyyymmdd) on, oldest first, kept up to date.
  Stream<List<DailySummaryRow>> watch(int deviceId, String key, int fromDay) =>
      (select(dailySummaries)
            ..where(
              (s) =>
                  s.deviceId.equals(deviceId) &
                  s.key.equals(key) &
                  s.day.isBiggerOrEqualValue(fromDay),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.day)]))
          .watch();

  /// Deletes the summaries of days before [day] (yyyymmdd); returns how many.
  Future<int> deleteBefore(int day) =>
      (delete(dailySummaries)..where((s) => s.day.isSmallerThanValue(day))).go();
}
