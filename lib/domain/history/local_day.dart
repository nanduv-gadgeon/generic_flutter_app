/// Calendar days on the phone's clock. History, the daily summaries and "today" on the dashboard
/// all count days in local time, from midnight to midnight.
library;

/// The start of the local day that [now] is in.
DateTime startOfDay(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// The midnight after [dayStart], keeping it UTC or local. Counted in calendar days, so a day
/// with a daylight-saving change is 23 or 25 hours long.
DateTime nextDay(DateTime dayStart) => dayStart.isUtc
    ? DateTime.utc(dayStart.year, dayStart.month, dayStart.day + 1)
    : DateTime(dayStart.year, dayStart.month, dayStart.day + 1);

/// The local midnight [days] calendar days after [dayStart] (before it when negative).
DateTime addDays(DateTime dayStart, int days) =>
    DateTime(dayStart.year, dayStart.month, dayStart.day + days);

/// [day]'s date as one number, e.g. 13 Nov 2026 → 20261113. Stored with the daily summaries: it
/// names the calendar day, so it does not move when the phone's time zone changes.
int dayNumber(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

/// The local midnight of [number] (see [dayNumber]).
DateTime dayFromNumber(int number) => DateTime(number ~/ 10000, number ~/ 100 % 100, number % 100);
