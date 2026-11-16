import 'package:intl/intl.dart';

import '../../application/history_export_controller.dart';
import '../../domain/history/history_days.dart';
import '../../domain/history/summary_chart.dart';
import '../../domain/models/reading.dart';
import '../dashboard/dashboard_format.dart';
import 'history_strings.dart';

/// Export text that needs logic: the sheet's description and every word of the exported files.
extension ExportStrings on AppLocalizations {
  /// "Smart Band S2 · last 7 days (20–26 Oct). All readings, …" for [days] (oldest first).
  String exportSheetDescription(String device, List<HistoryDay> days) =>
      exportSheetText(device, days.length, historyRange(days.first.start, days.last.start));

  /// The unit a reading's values are written in in the files: its history unit, else its unit;
  /// hours for a reading shown as "7h 12m".
  String exportUnitOf(Reading reading) =>
      reading.format == ReadingFormat.hoursMinutes ? exportHoursUnit : historyUnitOf(reading);

  /// The words of the file exported for [device] over [content].
  ExportText exportText(String device, ExportContent content) {
    final days = content.days;
    return ExportText(
      csvDate: exportCsvDate,
      csvTime: exportCsvTime,
      csvReading: exportCsvReading,
      csvValue: exportCsvValue,
      csvUnit: exportCsvUnit,
      csvDayStatus: exportCsvDayStatus,
      complete: historyComplete,
      partial: historyPartial,
      noData: historyNoData,
      reportTitle: exportReportTitle,
      reportSubtitle: exportReportSubtitle(
        device,
        days.length,
        historyRange(days.first.start, days.last.start),
      ),
      reportMade: exportReportMade(DateFormat.yMMMd(localeName).add_Hm().format(content.now)),
      reportNote: exportReportNote,
      columnDate: exportColumnDate,
      columnMin: historyMin,
      columnAverage: historyAverage,
      columnMax: historyMax,
      columnStatus: exportColumnStatus,
      rowStatus: {for (final s in SummaryRowStatus.values) s: historyRowStatus(s)},
      dayLabels: {for (final d in days) d.start: historyBannerDate(d.start)},
      barLabels: {
        for (final d in days) d.start: d == days.last ? historyToday : historyWeekday(d.start),
      },
      units: {for (final r in content.readings) r.key: exportUnitOf(r)},
      chartTitles: {
        for (final r in content.charted) r.key: historySummaryTitle(r, dailyValueOf(r)),
      },
    );
  }
}
