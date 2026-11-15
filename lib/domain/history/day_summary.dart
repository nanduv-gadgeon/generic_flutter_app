import 'package:freezed_annotation/freezed_annotation.dart';

import 'local_day.dart';

part 'day_summary.freezed.dart';

/// One hour of one device's [key] readings, as the database adds them up: the hour starting at
/// [start], its lowest and highest value, their sum and how many there were. Health data: never
/// log it.
@freezed
abstract class HourStats with _$HourStats {
  const factory HourStats({
    required int deviceId,
    required String key,
    required DateTime start,
    required double min,
    required double max,
    required double sum,
    required int count,
  }) = _HourStats;
}

/// One calendar day of one device's [key] readings, for History and Export: the lowest, average
/// and highest value, how many readings there were, and which local hours had any ([hours], bit
/// `h` for the hour starting at `h`:00). For a reading with a goal (steps, sleep), which counts up
/// through the day, [max] is the day's total. Health data: never log it.
@freezed
abstract class DaySummary with _$DaySummary {
  const factory DaySummary({
    required int deviceId,
    required String key,

    /// The day's local midnight.
    required DateTime day,
    required double min,
    required double avg,
    required double max,
    required int count,
    required int hours,
  }) = _DaySummary;

  const DaySummary._();

  /// Whether the hour starting at [hour]:00 had any readings.
  bool hasHour(int hour) => hours & (1 << hour) != 0;

  /// How many of the day's hours had readings.
  int get hoursWithData => [for (var h = 0; h < 24; h++) h].where(hasHour).length;

  /// The share of the day with readings, 0 to 1. A day that loses an hour to daylight saving has
  /// 23 hours to fill.
  double get coverage => hoursWithData / hoursIn(day);
}

/// How many local hours the day starting at [dayStart] has: 23 when the clocks go forward, else
/// 24 (the hour repeated when they go back is the same hour twice).
int hoursIn(DateTime dayStart) {
  final length = nextDay(dayStart).difference(dayStart).inHours;
  return length < 24 ? length : 24;
}
