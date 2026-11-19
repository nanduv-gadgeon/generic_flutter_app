import '../history/day_summary.dart';

export '../history/day_summary.dart';

/// Each device's readings summed up per key and local calendar day, for History and Export (the
/// same in both phases). Finished days are stored; today is worked out when asked for. Values
/// are health data: never log them.
abstract interface class DailySummaryRepository {
  /// Works out again and stores the summaries of the finished days from the local midnight
  /// [from] up to [to] (not included; never past today), of [deviceId] or of every device. A day
  /// with no readings left loses its summary. Returns how many days were stored.
  Future<int> refresh({required DateTime from, required DateTime to, int? deviceId});

  /// Works out again the finished days that [times] fall on, for [deviceId]: readings from an
  /// earlier day arrived late (e.g. logs a device kept while it was away). Times today are left
  /// alone.
  Future<void> refreshDaysOf(int deviceId, Iterable<DateTime> times);

  /// The device's [key] summaries of finished days from the local midnight [from] on, oldest
  /// first, kept up to date.
  Stream<List<DaySummary>> watch(int deviceId, String key, DateTime from);

  /// Today's summaries so far for each of the device's keys, worked out now and not stored.
  Future<List<DaySummary>> today(int deviceId);

  /// The device's readings of the local day starting [day], added up per key and hour (for
  /// History's chart through the day), worked out now and not stored.
  Future<List<HourStats>> hours(int deviceId, DateTime day);

  /// [hours], worked out again each time the device's readings are stored (today's chart keeps
  /// up while a device streams).
  Stream<List<HourStats>> watchHours(int deviceId, DateTime day);

  /// Deletes the summaries of days before the local midnight [day]; returns how many.
  Future<int> deleteBefore(DateTime day);
}
