/// The days History shows and whether each has data. Hours are wall-clock hours 0–23, the way
/// the daily summaries store them (`DaySummary.hours`). Pure Dart.
library;

import 'local_day.dart';

/// One local calendar day: from local midnight [start] to the next local midnight [end].
class HistoryDay {
  HistoryDay(this.start) : end = nextDay(start);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime time) => !time.isBefore(start) && time.isBefore(end);

  /// The wall-clock hours the day has, in order: 0–23, without the hour skipped when the clocks go
  /// forward. The hour repeated when they go back is one hour, as in the daily summaries.
  late final List<int> clockHours = [
    for (var h = 0; h < 24; h++)
      if (DateTime(start.year, start.month, start.day, h).hour == h) h,
  ];

  @override
  bool operator ==(Object other) => other is HistoryDay && other.start == start;

  @override
  int get hashCode => start.hashCode;

  @override
  String toString() => 'HistoryDay($start)';
}

/// How much of a day has data (requirement 6.3).
enum DayStatus {
  /// Data in every hour of the day (for today: every hour so far).
  complete,

  /// Data in some hours only.
  partial,

  /// No data at all.
  noData,
}

/// The last [count] local days up to and including the day [now] is in, oldest first. Worked out
/// from the clock every time, so the strip moves on at midnight.
List<HistoryDay> historyDays(DateTime now, int count) {
  final today = startOfDay(now);
  return [for (var back = count - 1; back >= 0; back--) HistoryDay(addDays(today, -back))];
}

/// The hours of [day] that should have data at [now]: all of them for a past day; for today the
/// hours begun so far (the current one included); none for a day not begun.
Set<int> hoursToCheck(HistoryDay day, DateTime now) {
  if (now.isBefore(day.start)) return const {};
  if (!now.isBefore(day.end)) return day.clockHours.toSet();
  final hour = now.toLocal().hour;
  return {
    for (final h in day.clockHours)
      if (h <= hour) h,
  };
}

/// Complete, Partial or No data, from the hours that have data and the hours that should.
DayStatus dayStatus(Set<int> withData, Set<int> toCheck) {
  final covered = toCheck.where(withData.contains).length;
  if (covered == 0) return DayStatus.noData;
  return covered == toCheck.length ? DayStatus.complete : DayStatus.partial;
}

/// The index in [days] of the day the user picked ([picked] is its start; null means today): the
/// last day when it is today or not set, the oldest when the picked day has left the window.
int pickedDayIndex(List<HistoryDay> days, DateTime? picked) {
  if (days.isEmpty) return -1;
  if (picked == null) return days.length - 1;
  final index = days.indexWhere((d) => d.start == picked);
  return index < 0 ? 0 : index;
}
