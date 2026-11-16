import 'day_summary.dart';
import 'local_day.dart';

/// Adds up hourly [stats] into one [DaySummary] per device, reading and local day, in that
/// order (days oldest first). An hour belongs to the local day and hour it starts in, so days
/// with a daylight-saving change come out right. Hours with no readings are skipped.
List<DaySummary> summariseDays(Iterable<HourStats> stats) {
  final groups = <(int, String, DateTime), List<HourStats>>{};
  for (final hour in stats) {
    if (hour.count <= 0) continue;
    (groups[(hour.deviceId, hour.key, startOfDay(hour.start))] ??= []).add(hour);
  }
  final keys = groups.keys.toList()
    ..sort((a, b) {
      final byDevice = a.$1.compareTo(b.$1);
      if (byDevice != 0) return byDevice;
      final byKey = a.$2.compareTo(b.$2);
      return byKey != 0 ? byKey : a.$3.compareTo(b.$3);
    });
  return [for (final k in keys) summariseDay(k.$3, groups[k]!)];
}

/// One day's summary from its hours (all of the same device and reading, all on the day that
/// starts at [dayStart]); [hours] must not be empty.
DaySummary summariseDay(DateTime dayStart, List<HourStats> hours) {
  final first = hours.first;
  var min = first.min;
  var max = first.max;
  var sum = 0.0;
  var count = 0;
  var mask = 0;
  for (final hour in hours) {
    if (hour.min < min) min = hour.min;
    if (hour.max > max) max = hour.max;
    sum += hour.sum;
    count += hour.count;
    mask |= 1 << hour.start.toLocal().hour;
  }
  return DaySummary(
    deviceId: first.deviceId,
    key: first.key,
    day: dayStart,
    min: min,
    avg: sum / count,
    max: max,
    count: count,
    hours: mask,
  );
}
