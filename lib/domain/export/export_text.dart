import '../history/summary_chart.dart';

/// Every word an exported file contains, in the phone's language (from `app_en.arb`), so the code
/// that makes the files holds no text of its own. Dates and units are worked out beforehand.
class ExportText {
  const ExportText({
    required this.csvDate,
    required this.csvTime,
    required this.csvReading,
    required this.csvValue,
    required this.csvUnit,
    required this.csvDayStatus,
    required this.complete,
    required this.partial,
    required this.noData,
    required this.reportTitle,
    required this.reportSubtitle,
    required this.reportMade,
    required this.reportNote,
    required this.columnDate,
    required this.columnMin,
    required this.columnAverage,
    required this.columnMax,
    required this.columnStatus,
    required this.rowStatus,
    required this.dayLabels,
    required this.barLabels,
    required this.units,
    required this.chartTitles,
  });

  /// CSV column headers.
  final String csvDate;
  final String csvTime;
  final String csvReading;
  final String csvValue;
  final String csvUnit;
  final String csvDayStatus;

  /// A day's status: "Complete", "Partial", "No data".
  final String complete;
  final String partial;
  final String noData;

  /// PDF: "History report", "Test band · last 7 days (20–26 Oct)", "Made on …" and the line
  /// that says missing days are marked.
  final String reportTitle;
  final String reportSubtitle;
  final String reportMade;
  final String reportNote;

  /// PDF table headers.
  final String columnDate;
  final String columnMin;
  final String columnAverage;
  final String columnMax;
  final String columnStatus;

  /// The PDF table's status words (Missing, High, Low, Partial, Normal).
  final Map<SummaryRowStatus, String> rowStatus;

  /// By day start: "Tue 20 Oct" (PDF table) and "Tue" / "Today" (under a PDF bar).
  final Map<DateTime, String> dayLabels;
  final Map<DateTime, String> barLabels;

  /// By reading key: the unit its values are written in ("bpm", "steps"; "h" for hours).
  final Map<String, String> units;

  /// By reading key: the title of its PDF chart ("Heart rate · daily average").
  final Map<String, String> chartTitles;
}

/// The colours of the PDF report, as ARGB values from the app's theme (the config's brand colour
/// and the shared status colours), so the report looks like History.
class ExportColours {
  const ExportColours({
    required this.primary,
    required this.barSoft,
    required this.warn,
    required this.danger,
    required this.muted,
    required this.border,
  });

  final int primary;
  final int barSoft;
  final int warn;
  final int danger;
  final int muted;
  final int border;
}
