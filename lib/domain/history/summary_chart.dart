/// The 7-day summary of one reading (requirement 6.5, mockup 24): one value per day, how complete
/// each day is, and the lowest, average and highest of those values. Pure Dart.
library;

import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/reading.dart';
import 'day_detail.dart';
import 'day_summary.dart';
import 'history_days.dart';

part 'summary_chart.freezed.dart';

/// Which of a day's figures the summary shows for a reading.
enum DailyValue {
  /// The day's average, e.g. heart rate.
  average,

  /// The day's total: for a reading with a goal (steps, sleep, active time), which counts up
  /// through the day, its highest value.
  total,
}

/// A day's value against the reading's normal range.
enum SummaryFlag { none, high, low }

/// What a row of the day list says, in the mockup's order: a day without data is Missing, then
/// a value out of range, then a day with gaps.
enum SummaryRowStatus { missing, high, low, partial, normal }

/// One day of the summary.
@freezed
abstract class SummaryDay with _$SummaryDay {
  const factory SummaryDay({
    required HistoryDay day,

    /// The day's value; null when the reading has no data that day.
    double? value,
    required DayStatus status,
    @Default(SummaryFlag.none) SummaryFlag flag,
    @Default(false) bool isToday,
  }) = _SummaryDay;
}

/// The summary of one reading over the days History shows.
@freezed
abstract class SummaryChart with _$SummaryChart {
  const factory SummaryChart({
    /// Oldest first, today last.
    required List<SummaryDay> days,
    required DailyValue dailyValue,

    /// The lowest, average and highest of the days' values; null when no day has data.
    double? min,
    double? avg,
    double? max,
  }) = _SummaryChart;

  const SummaryChart._();

  bool get hasData => min != null;
}

/// The reading the summary shows: the one picked ([picked] is its key), or the first of
/// [readings] when none is picked or the device has no such reading (e.g. after picking another
/// device); null when there are none.
Reading? summaryReading(List<Reading> readings, String? picked) =>
    readings.where((r) => r.key == picked).firstOrNull ?? readings.firstOrNull;

/// The total for a reading with a goal, else the average.
DailyValue dailyValueOf(Reading reading) =>
    reading.goal != null ? DailyValue.total : DailyValue.average;

/// [value] against [reading]'s normal range; never flagged for a reading with a goal or no range.
SummaryFlag flagOf(Reading reading, double value) {
  final normal = reading.normal;
  if (normal == null || reading.goal != null) return SummaryFlag.none;
  if (value > normal.high) return SummaryFlag.high;
  if (value < normal.low) return SummaryFlag.low;
  return SummaryFlag.none;
}

/// The summary of [reading] over [days] (oldest first) from [summaries] (by day start, then by
/// reading key), at [now]. A day's status counts this reading's own hours with data against the
/// hours that should have data: all of a past day, the hours begun so far today.
SummaryChart summaryChart(
  Reading reading,
  List<HistoryDay> days,
  Map<DateTime, Map<String, DaySummary>> summaries,
  DateTime now,
) {
  final daily = dailyValueOf(reading);
  final summaryDays = [
    for (final day in days) _day(reading, daily, day, summaries[day.start]?[reading.key], now),
  ];
  final values = [for (final d in summaryDays) ?d.value];
  return SummaryChart(
    days: summaryDays,
    dailyValue: daily,
    min: values.isEmpty ? null : values.reduce(math.min),
    avg: values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length,
    max: values.isEmpty ? null : values.reduce(math.max),
  );
}

SummaryDay _day(Reading reading, DailyValue daily, HistoryDay day, DaySummary? s, DateTime now) {
  final isToday = day.contains(now);
  if (s == null) return SummaryDay(day: day, status: DayStatus.noData, isToday: isToday);
  final value = daily == DailyValue.total ? s.max : s.avg;
  final status = dayStatus(hoursOfMask(s.hours), hoursToCheck(day, now));
  return SummaryDay(
    day: day,
    value: value,
    // A day with a value has data, even when its hours fall outside those checked.
    status: status == DayStatus.noData ? DayStatus.partial : status,
    flag: flagOf(reading, value),
    isToday: isToday,
  );
}

/// Where the bars start: 0 for totals; otherwise a little under the lowest value, so small
/// differences between days still show (mockup: lowest − 0.8 × the spread, or 10 % of the lowest
/// when every day is the same), not below 0 unless a value is.
double barFloor(SummaryChart chart) {
  final low = chart.min;
  final high = chart.max;
  if (low == null || high == null || chart.dailyValue == DailyValue.total) return 0;
  final spread = high - low == 0 ? low.abs() * 0.1 : high - low;
  final floor = low - spread * 0.8;
  return low >= 0 ? math.max(0, floor) : floor;
}

/// How tall [value]'s bar is, from 0 at [barFloor] to 1 at the highest value.
double barFraction(SummaryChart chart, double value) {
  final high = chart.max;
  if (high == null) return 0;
  final floor = barFloor(chart);
  if (high <= floor) return 1;
  return ((value - floor) / (high - floor)).clamp(0, 1).toDouble();
}

/// The word of [day]'s row in the day list.
SummaryRowStatus rowStatus(SummaryDay day) {
  if (day.value == null) return SummaryRowStatus.missing;
  return switch (day.flag) {
    SummaryFlag.high => SummaryRowStatus.high,
    SummaryFlag.low => SummaryRowStatus.low,
    SummaryFlag.none =>
      day.status == DayStatus.partial ? SummaryRowStatus.partial : SummaryRowStatus.normal,
  };
}
