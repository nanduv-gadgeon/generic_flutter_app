/// The days History shows and whether each has data. Pure Dart: times are compared as instants,
/// so readings stored in UTC fall on the right local day.
library;

/// One local calendar day: from local midnight [start] to the next local midnight [end], so 23 or
/// 25 hours long on a clock change.
class HistoryDay {
  const HistoryDay(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime time) => !time.isBefore(start) && time.isBefore(end);

  /// How many hours the day has (rounded up, for a 30-minute clock change).
  int get hours => (end.difference(start).inMinutes + 59) ~/ 60;

  @override
  bool operator ==(Object other) => other is HistoryDay && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

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
  final local = now.toLocal();
  return [
    for (var back = count - 1; back >= 0; back--)
      HistoryDay(
        DateTime(local.year, local.month, local.day - back),
        DateTime(local.year, local.month, local.day - back + 1),
      ),
  ];
}

/// The hours of [day] that should have data at [now]: all of them for a past day; for today the
/// hours begun so far (the current one included); none for a day not begun.
int hoursToCover(HistoryDay day, DateTime now) {
  if (now.isBefore(day.start)) return 0;
  if (!now.isBefore(day.end)) return day.hours;
  final begun = now.difference(day.start).inHours + 1;
  return begun > day.hours ? day.hours : begun;
}

/// Complete, Partial or No data, from the hours of the day (0 = the first hour after midnight)
/// that have data and the number of hours that should.
DayStatus dayStatus(Set<int> hoursWithData, int hoursToCover) {
  final covered = hoursWithData.where((h) => h >= 0 && h < hoursToCover).length;
  if (covered == 0) return DayStatus.noData;
  return covered == hoursToCover ? DayStatus.complete : DayStatus.partial;
}

/// The status of each of [days] at [now], from the start times of the stretches of time that have
/// data ([slots], e.g. 15-minute slots). A slot counts for the hour of the day it starts in.
List<DayStatus> dayStatuses(List<HistoryDay> days, Iterable<DateTime> slots, DateTime now) => [
  for (final day in days)
    dayStatus({
      for (final slot in slots)
        if (day.contains(slot)) slot.difference(day.start).inHours,
    }, hoursToCover(day, now)),
];

/// The index in [days] of the day the user picked ([picked] is its start; null means today): the
/// last day when it is today or not set, the oldest when the picked day has left the window.
int pickedDayIndex(List<HistoryDay> days, DateTime? picked) {
  if (days.isEmpty) return -1;
  if (picked == null) return days.length - 1;
  final index = days.indexWhere((d) => d.start == picked);
  return index < 0 ? 0 : index;
}
