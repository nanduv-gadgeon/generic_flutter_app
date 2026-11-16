import 'package:intl/intl.dart';

import '../../domain/history/day_detail.dart';
import '../../domain/history/history_days.dart';
import '../../l10n/app_localizations.dart';

/// History text that needs logic: dates in the phone's language and day statuses.
extension HistoryStrings on AppLocalizations {
  /// "Last 7 days · 20–26 Oct" for [days] (oldest first, not empty).
  String historyWindowText(List<HistoryDay> days) =>
      historySubtitle(days.length, historyRange(days.first.start, days.last.start));

  /// "20–26 Oct", or "28 Oct – 3 Nov" across a month.
  String historyRange(DateTime first, DateTime last) {
    final day = DateFormat.d(localeName);
    final month = DateFormat.MMM(localeName);
    return first.year == last.year && first.month == last.month
        ? historyRangeOneMonth(day.format(first), day.format(last), month.format(last))
        : historyRangeTwoMonths(
            day.format(first),
            month.format(first),
            day.format(last),
            month.format(last),
          );
  }

  /// "Tue": the top line of a day tile.
  String historyWeekday(DateTime day) => DateFormat.E(localeName).format(day);

  /// "20": the big number of a day tile.
  String historyDayNumber(DateTime day) => DateFormat.d(localeName).format(day);

  String historyStatus(DayStatus status) => switch (status) {
    DayStatus.complete => historyComplete,
    DayStatus.partial => historyPartial,
    DayStatus.noData => historyNoData,
  };

  /// "Thursday, October 22, No data" for screen readers; "…, checking data" while [status] is
  /// not known yet.
  String historyDayLabel(DateTime day, {required bool today, DayStatus? status}) {
    final date = DateFormat.MMMMEEEEd(localeName).format(day);
    return switch ((today, status)) {
      (true, final s?) => historyTodaySpoken(date, historyStatus(s)),
      (false, final s?) => historyDaySpoken(date, historyStatus(s)),
      (true, null) => historyTodayLoadingSpoken(date),
      (false, null) => historyDayLoadingSpoken(date),
    };
  }

  /// "Thu 22 Oct", for the banner.
  String historyBannerDate(DateTime day) => historyShortDate(
    DateFormat.E(localeName).format(day),
    DateFormat.d(localeName).format(day),
    DateFormat.MMM(localeName).format(day),
  );

  /// The wall-clock [hour] of [day] ("06:00"); "24:00", the day's end, when null.
  String historyHour(HistoryDay day, int? hour) => hour == null
      ? historyEndOfDay
      : DateFormat.Hm(localeName)
            .format(DateTime(day.start.year, day.start.month, day.start.day, hour));

  /// "00:00–07:00, 22:00–24:00" for runs of hours (first, last) of [day]. A run ends where the
  /// next hour of the day starts.
  String historyRanges(HistoryDay day, List<(int, int)> ranges) => [
    for (final (first, last) in ranges)
      historyHourRange(historyHour(day, first), historyHour(day, nextHourOf(day, last))),
  ].join(historyListSeparator);
}
