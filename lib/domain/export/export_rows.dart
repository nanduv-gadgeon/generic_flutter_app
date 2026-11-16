/// The rows of an exported CSV: every stored reading of the days exported, with each day's
/// status, and one row for a day without data. Pure Dart.
library;

import '../decoder/decoded_packet.dart';
import '../history/history_days.dart';
import '../models/reading.dart';
import '../services/export_service.dart';

/// One row of the CSV, as text. [time], [reading], [value] and [unit] are empty on a day's
/// "No data" row.
typedef ExportRow = ({
  String date,
  String time,
  String reading,
  String value,
  String unit,
  String dayStatus,
});

/// The CSV's rows for [request] from [samples] (any order, any keys): the request's readings, in
/// time order, each with its day's status. A day's status is worked out from the samples' own
/// hours, as History's day strip does: Complete, Partial, or a single "No data" row.
List<ExportRow> exportRows(ExportRequest request, Iterable<Sample> samples) {
  final byKey = {for (final r in request.readings) r.key: r};
  final kept = samples.where((s) => byKey.containsKey(s.key)).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  final text = request.text;
  final rows = <ExportRow>[];
  for (final day in request.days) {
    final ofDay = [
      for (final s in kept)
        if (day.contains(s.at.toLocal())) s,
    ];
    final date = isoDate(day.start);
    if (ofDay.isEmpty) {
      rows.add((date: date, time: '', reading: '', value: '', unit: '', dayStatus: text.noData));
      continue;
    }
    final hours = {for (final s in ofDay) s.at.toLocal().hour};
    final status = switch (dayStatus(hours, hoursToCheck(day, request.now))) {
      DayStatus.complete => text.complete,
      DayStatus.partial || DayStatus.noData => text.partial,
    };
    for (final s in ofDay) {
      final reading = byKey[s.key]!;
      rows.add((
        date: date,
        time: isoTime(s.at.toLocal()),
        reading: reading.label,
        value: plainValue(reading, s.value),
        unit: text.units[reading.key] ?? reading.unit,
        dayStatus: status,
      ));
    }
  }
  return rows;
}

/// [value] with the reading's decimals and no thousands separators, so spreadsheets read it as a
/// number: "72", "36.6", "0.222".
String plainValue(Reading reading, double value) => value.toStringAsFixed(reading.decimals);

/// "2026-10-20": a date spreadsheets read in every language.
String isoDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${_two(day.month)}-${_two(day.day)}';

/// "08:05:09", local time.
String isoTime(DateTime at) => '${_two(at.hour)}:${_two(at.minute)}:${_two(at.second)}';

String _two(int n) => n.toString().padLeft(2, '0');
