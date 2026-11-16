/// What History shows for one day: which wall-clock hours have data, the gaps, and which readings
/// get a card. The figures themselves are the daily summaries ([DaySummary]). Pure Dart.
library;

import '../models/device_profile.dart';
import 'day_summary.dart';
import 'history_days.dart';

/// The wall-clock hours set in a daily summary's [mask] (bit h for the hour starting at h:00).
Set<int> hoursOfMask(int mask) => {
  for (var h = 0; h < 24; h++)
    if (mask & (1 << h) != 0) h,
};

/// The hours in which any of [summaries] (one per reading of a device and day) had readings.
Set<int> hoursWithData(Iterable<DaySummary> summaries) =>
    hoursOfMask(summaries.fold(0, (mask, s) => mask | s.hours));

/// The hours of [toCheck] without data, in order.
List<int> missingHours(Set<int> withData, Set<int> toCheck) =>
    [...toCheck.where((h) => !withData.contains(h))]..sort();

/// Runs of [hours] (in rising order) that follow one another in [day], as (first, last) pairs:
/// 2, 3, 4, 5, 9 gives (2, 5), (9, 9). An hour skipped by a clock change does not break a run.
List<(int, int)> hourRanges(List<int> hours, HistoryDay day) {
  final ranges = <(int, int)>[];
  for (final h in hours) {
    final previous = ranges.isEmpty ? null : ranges.last.$2;
    if (previous != null && nextHourOf(day, previous) == h) {
      ranges.last = (ranges.last.$1, h);
    } else {
      ranges.add((h, h));
    }
  }
  return ranges;
}

/// The wall-clock hour after [hour] in [day]; null after its last hour (midnight).
int? nextHourOf(HistoryDay day, int hour) {
  final index = day.clockHours.indexOf(hour);
  return index < 0 || index + 1 >= day.clockHours.length ? null : day.clockHours[index + 1];
}

/// How many of the hours that should have data do, in whole percent: rounded down, and at least
/// 1 when any hour has data, so a Partial day never reads 0 % or 100 %.
int coveragePercent(Set<int> withData, Set<int> toCheck) {
  if (toCheck.isEmpty) return 0;
  final covered = toCheck.where(withData.contains).length;
  if (covered == 0) return 0;
  final percent = covered * 100 ~/ toCheck.length;
  return percent < 1 ? 1 : percent;
}

/// The reading keys of [profile] that the device itself sends and the phone stores: what the
/// daily summaries hold and the day strip looks at.
List<String> storedKeys(DeviceProfile profile) => [
  for (final r in profile.readings)
    if (r.source == ReadingSource.device) r.key,
];

/// The readings of [profile] that get a card on History, in the order its Live dashboard shows
/// them (main reading, then tiles), then any others in profile order. Left out: readings worked
/// out from events (today only), coded states (no average), readings only drawn live by a
/// waveform (not stored), and the second half of a pair (shown with the first).
List<Reading> historyReadings(DeviceProfile profile) {
  final paired = {for (final r in profile.readings) ?r.pair};
  final views = profile.dashboardOrDefault.views;
  final waveforms = {
    for (final v in views)
      if (v.type == DashboardViewType.waveform) ?v.reading,
  };
  final byKey = {for (final r in profile.readings) r.key: r};
  final order = <String>{
    for (final v in views) ...[?v.reading, ...v.readings],
    ...byKey.keys,
  };
  return [
    for (final key in order)
      if (byKey[key] case final r?)
        if (r.source == ReadingSource.device &&
            r.states.isEmpty &&
            !paired.contains(r.key) &&
            !waveforms.contains(r.key))
          r,
  ];
}

/// The average value in each wall-clock hour of the reading [key], from [hours] (figures per key
/// and hour; each belongs to the local hour it starts in, so the hour repeated when the clocks go
/// back is one hour). Hours without readings are left out.
Map<int, double> hourlyAverages(Iterable<HourStats> hours, String key) {
  final totals = <int, (double, int)>{};
  for (final h in hours) {
    if (h.key != key || h.count <= 0) continue;
    final hour = h.start.toLocal().hour;
    final (sum, count) = totals[hour] ?? (0.0, 0);
    totals[hour] = (sum + h.sum, count + h.count);
  }
  return {for (final MapEntry(:key, value: (sum, count)) in totals.entries) key: sum / count};
}

/// The bottom and top of a chart of [values] (not empty). With a [normal] range, the chart always
/// takes it in too, so the normal band shows and the line is seen above, in or below it; the span
/// is then widened by 10 % on each side. Without one, the values' range is widened by 35 % (as in
/// the mockup). Widened by 1 when everything is the same value.
({double low, double high}) chartRange(Iterable<double> values, {NormalRange? normal}) {
  var low = values.reduce((a, b) => a < b ? a : b);
  var high = values.reduce((a, b) => a > b ? a : b);
  if (normal != null) {
    if (normal.low < low) low = normal.low;
    if (normal.high > high) high = normal.high;
  }
  final pad = high > low ? (high - low) * (normal == null ? 0.35 : 0.1) : 1.0;
  return (low: low - pad, high: high + pad);
}
