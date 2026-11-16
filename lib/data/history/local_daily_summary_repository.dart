import '../../domain/history/local_day.dart';
import '../../domain/history/summarise_day.dart';
import '../../domain/services/daily_summary_repository.dart';
import '../db/app_database.dart';

/// [DailySummaryRepository] over the local database; the same in both phases. The database adds
/// the readings up per hour; [summariseDays] makes days of them.
class LocalDailySummaryRepository implements DailySummaryRepository {
  LocalDailySummaryRepository(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<int> refresh({required DateTime from, required DateTime to, int? deviceId}) async {
    final today = startOfDay(_now());
    final end = to.isAfter(today) ? today : to;
    if (!from.isBefore(end)) return 0;
    final days = summariseDays(await _hours(from, end, deviceId: deviceId));
    await _db.dailySummariesDao.replaceDays(
      deviceId: deviceId,
      fromDay: dayNumber(from),
      toDay: dayNumber(end),
      rows: [for (final d in days) _row(d)],
    );
    return {for (final d in days) d.day}.length;
  }

  @override
  Future<void> refreshDaysOf(int deviceId, Iterable<DateTime> times) async {
    final today = startOfDay(_now());
    final days = {
      for (final t in times)
        if (startOfDay(t) case final day when day.isBefore(today)) day,
    };
    for (final day in days) {
      await refresh(from: day, to: nextDay(day), deviceId: deviceId);
    }
  }

  @override
  Stream<List<DaySummary>> watch(int deviceId, String key, DateTime from) => _db.dailySummariesDao
      .watch(deviceId, key, dayNumber(from))
      .map((rows) => rows.map(_summary).toList());

  @override
  Future<List<DaySummary>> today(int deviceId) async {
    final day = startOfDay(_now());
    return summariseDays(await _hours(day, nextDay(day), deviceId: deviceId));
  }

  @override
  Future<int> deleteBefore(DateTime day) => _db.dailySummariesDao.deleteBefore(dayNumber(day));

  Future<List<HourStats>> _hours(DateTime from, DateTime to, {int? deviceId}) async {
    final fromMs = from.toUtc().millisecondsSinceEpoch;
    final rows = await _db.readingsDao.hourStats(
      fromMs,
      to.toUtc().millisecondsSinceEpoch,
      deviceId: deviceId,
    );
    return [
      for (final r in rows)
        HourStats(
          deviceId: r.deviceId,
          key: r.key,
          start: DateTime.fromMillisecondsSinceEpoch(fromMs + r.bucket * 3600000, isUtc: true),
          min: r.min,
          max: r.max,
          sum: r.sum,
          count: r.count,
        ),
    ];
  }

  static DailySummariesCompanion _row(DaySummary s) => DailySummariesCompanion.insert(
    deviceId: s.deviceId,
    key: s.key,
    day: dayNumber(s.day),
    minValue: s.min,
    avgValue: s.avg,
    maxValue: s.max,
    readingCount: s.count,
    hours: s.hours,
  );

  static DaySummary _summary(DailySummaryRow r) => DaySummary(
    deviceId: r.deviceId,
    key: r.key,
    day: dayFromNumber(r.day),
    min: r.minValue,
    avg: r.avgValue,
    max: r.maxValue,
    count: r.readingCount,
    hours: r.hours,
  );
}
