import '../export/export_text.dart';
import '../history/day_summary.dart';
import '../history/history_days.dart';
import '../models/reading.dart';

export '../export/export_text.dart';

/// The file types History can export (requirement 6.6).
enum ExportFormat { csv, pdf }

/// What to export: one device's readings over the days History shows.
class ExportRequest {
  const ExportRequest({
    required this.deviceId,
    required this.deviceName,
    required this.readings,
    required this.charted,
    required this.days,
    required this.summaries,
    required this.now,
    required this.format,
    required this.text,
    required this.colours,
  });

  final int deviceId;
  final String deviceName;

  /// The readings of the device's profile that the phone stores: the CSV's rows.
  final List<Reading> readings;

  /// The readings that get a chart and a daily table in the PDF, in Live dashboard order.
  final List<Reading> charted;

  /// Oldest first, today last.
  final List<HistoryDay> days;

  /// Each day's summaries by day start, then by reading key (for the PDF).
  final Map<DateTime, Map<String, DaySummary>> summaries;
  final DateTime now;
  final ExportFormat format;
  final ExportText text;
  final ExportColours colours;
}

/// Makes a file of a device's last days of readings and opens the phone's share sheet with it.
/// Local mode only: the History screen offers it only when `exportAvailable` is true. Values are
/// health data: never log them.
abstract interface class ExportService {
  /// Makes the file, shares it and deletes it once the share sheet is closed.
  Future<void> exportAndShare(ExportRequest request);
}
