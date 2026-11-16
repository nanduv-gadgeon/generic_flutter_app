// Made-up export requests for the export tests. No real readings.
import 'package:generic_flutter_app/domain/history/day_summary.dart';
import 'package:generic_flutter_app/domain/history/history_days.dart';
import 'package:generic_flutter_app/domain/history/summary_chart.dart';
import 'package:generic_flutter_app/domain/models/reading.dart';
import 'package:generic_flutter_app/domain/services/export_service.dart';

const exportHr = Reading(
  key: 'hr',
  label: 'Heart rate',
  unit: 'bpm',
  icon: ReadingIcon.pulse,
  normal: NormalRange(low: 60, high: 100),
);
const exportTemp = Reading(
  key: 'temp',
  label: 'Skin temp',
  unit: '°C',
  icon: ReadingIcon.thermo,
  decimals: 1,
);
const exportSteps = Reading(
  key: 'steps',
  label: 'Steps',
  unit: 'today',
  historyUnit: 'steps',
  icon: ReadingIcon.trend,
  goal: 10000,
);

/// Now: Mon 26 Oct 2026 10:42; the days are 20–26 Oct.
final exportNow = DateTime(2026, 10, 26, 10, 42);

/// The English words of the files, as the app gives them.
ExportText exportTextFor(List<HistoryDay> days) => ExportText(
  csvDate: 'Date',
  csvTime: 'Time',
  csvReading: 'Reading',
  csvValue: 'Value',
  csvUnit: 'Unit',
  csvDayStatus: 'Day status',
  complete: 'Complete',
  partial: 'Partial',
  noData: 'No data',
  reportTitle: 'History report',
  reportSubtitle: 'Test band · last 7 days (20–26 Oct)',
  reportMade: 'Made on Oct 26, 2026 10:42',
  reportNote: 'Days with missing data are marked.',
  columnDate: 'Date',
  columnMin: 'Min',
  columnAverage: 'Average',
  columnMax: 'Max',
  columnStatus: 'Status',
  rowStatus: const {
    SummaryRowStatus.missing: 'Missing',
    SummaryRowStatus.high: 'High',
    SummaryRowStatus.low: 'Low',
    SummaryRowStatus.partial: 'Partial',
    SummaryRowStatus.normal: 'Normal',
  },
  dayLabels: {for (final d in days) d.start: 'D${d.start.day}'},
  barLabels: {for (final d in days) d.start: 'B${d.start.day}'},
  units: const {'hr': 'bpm', 'temp': '°C', 'steps': 'steps'},
  chartTitles: const {'hr': 'Heart rate · daily average'},
);

const exportColours = ExportColours(
  primary: 0xFF123456,
  barSoft: 0x40123456,
  warn: 0xFFB45309,
  danger: 0xFFB91C1C,
  muted: 0xFF5B6472,
  border: 0xFFE2E6EC,
);

/// A request for device 1 over 20–26 Oct with [summaries].
ExportRequest exportRequest({
  ExportFormat format = ExportFormat.csv,
  List<Reading> readings = const [exportHr, exportTemp],
  List<Reading> charted = const [exportHr],
  Map<DateTime, Map<String, DaySummary>> summaries = const {},
  String deviceName = 'Test band',
}) {
  final days = historyDays(exportNow, 7);
  return ExportRequest(
    deviceId: 1,
    deviceName: deviceName,
    readings: readings,
    charted: charted,
    days: days,
    summaries: summaries,
    now: exportNow,
    format: format,
    text: exportTextFor(days),
    colours: exportColours,
  );
}
