/// What History shows for one day: which wall-clock hours have data, the gaps, and which readings
/// get a card. The figures themselves are the daily summaries ([DaySummary]). Pure Dart.
library;

import 'dart:math' as math;

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

/// One wall-clock hour of one reading on the chart through the day: its lowest, average and
/// highest value and how many readings it had. Health data: never log it.
typedef HourFigures = ({double min, double avg, double max, int count});

/// The figures of each wall-clock hour of the reading [key], from [hours] (figures per key and
/// hour; each belongs to the local hour it starts in, so the hour repeated when the clocks go back
/// is one hour). Hours without readings are left out.
Map<int, HourFigures> hourlyStats(Iterable<HourStats> hours, String key) {
  final totals = <int, ({double min, double max, double sum, int count})>{};
  for (final h in hours) {
    if (h.key != key || h.count <= 0) continue;
    final hour = h.start.toLocal().hour;
    final t = totals[hour];
    totals[hour] = t == null
        ? (min: h.min, max: h.max, sum: h.sum, count: h.count)
        : (
            min: h.min < t.min ? h.min : t.min,
            max: h.max > t.max ? h.max : t.max,
            sum: t.sum + h.sum,
            count: t.count + h.count,
          );
  }
  return {
    for (final MapEntry(:key, value: t) in totals.entries)
      key: (min: t.min, avg: t.sum / t.count, max: t.max, count: t.count),
  };
}

/// Which side of the normal range a value is on.
enum NormalSide { below, above }

/// The side of [normal] that [value] is on as it is shown, rounded to [decimals]: 94.75 shown
/// with no decimals is 95, inside 95–100, so the chart agrees with the text. Null when inside, or
/// without a normal range.
NormalSide? sideOfNormal(double value, NormalRange? normal, int decimals) {
  if (normal == null) return null;
  final scale = math.pow(10, decimals);
  final shown = (value * scale).round() / scale;
  if (shown < normal.low) return NormalSide.below;
  if (shown > normal.high) return NormalSide.above;
  return null;
}

/// What the strip under a chart through the day shows for an hour.
enum HourCoverage { data, missing, notYet }

/// Each wall-clock hour of [day] in order, with whether it has data, should have had data and has
/// none, or has not begun yet (later hours of today).
List<(int, HourCoverage)> hourCoverage(HistoryDay day, Set<int> withData, Set<int> toCheck) => [
  for (final h in day.clockHours)
    (
      h,
      withData.contains(h)
          ? HourCoverage.data
          : toCheck.contains(h)
          ? HourCoverage.missing
          : HourCoverage.notYet,
    ),
];

/// The hour of [hours] whose middle is nearest to [at] (hours of the day, e.g. 14.3); the earlier
/// one on a tie, null when there are none. A tap on the chart picks the nearest hour with data.
int? nearestHour(Iterable<int> hours, double at) {
  int? best;
  for (final h in hours) {
    final distance = (h + 0.5 - at).abs();
    if (best == null ||
        distance < (best + 0.5 - at).abs() ||
        (distance == (best + 0.5 - at).abs() && h < best)) {
      best = h;
    }
  }
  return best;
}

/// The bottom and top of a chart of [values] (not empty; the hours' lowest and highest values). With a [normal] range, the chart always
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
