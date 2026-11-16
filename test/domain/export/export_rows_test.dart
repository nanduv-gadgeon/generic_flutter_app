import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/export/export_rows.dart';

import '../../fixtures/export_fixtures.dart';

/// The CSV's rows: every stored reading in time order with its day's status, and a "No data" row
/// for an empty day. Made-up readings; now is Mon 26 Oct 2026 10:42.
void main() {
  Sample at(String key, double value, int day, int hour, [int minute = 0, int second = 0]) =>
      Sample(key, value, DateTime(2026, 10, day, hour, minute, second).toUtc());

  /// A reading of [key] in every hour of the 20th: a complete day.
  List<Sample> fullDay(String key) => [for (var h = 0; h < 24; h++) at(key, 70, 20, h, 30)];

  test('readings in time order, each with its day status; empty days get one row', () {
    final rows = exportRows(exportRequest(), [
      ...fullDay('hr'),
      at('temp', 36.64, 20, 0, 5, 9),
      at('hr', 72, 21, 9),
    ]);

    // 24 + 1 on the 20th, 1 on the 21st, one "No data" row for each of 22–26.
    expect(rows, hasLength(24 + 1 + 1 + 5));
    expect(rows[0], (
      date: '2026-10-20',
      time: '00:05:09',
      reading: 'Skin temp',
      value: '36.6',
      unit: '°C',
      dayStatus: 'Complete',
    ));
    expect(rows[1].time, '00:30:00');
    expect(rows[25], (
      date: '2026-10-21',
      time: '09:00:00',
      reading: 'Heart rate',
      value: '72',
      unit: 'bpm',
      dayStatus: 'Partial',
    ));
    expect(rows.skip(26).map((r) => (r.date, r.reading, r.dayStatus)), [
      for (final d in [22, 23, 24, 25, 26]) ('2026-10-$d', '', 'No data'),
    ]);
  });

  test('today is complete when every hour so far has a reading', () {
    final today = [for (var h = 0; h <= 10; h++) at('hr', 70, 26, h)];
    expect(exportRows(exportRequest(), today).last.dayStatus, 'Complete');
    expect(exportRows(exportRequest(), today.skip(1)).last.dayStatus, 'Partial');
  });

  test('readings not in the request are left out', () {
    final rows = exportRows(exportRequest(readings: [exportTemp]), [at('hr', 70, 20, 8)]);
    expect(rows.first.dayStatus, 'No data');
  });

  test('readings outside the days are left out', () {
    final rows = exportRows(exportRequest(), [at('hr', 70, 19, 8), at('hr', 70, 27, 8)]);
    expect(rows.every((r) => r.dayStatus == 'No data'), isTrue);
  });

  // (reading, value, written)
  final values = {
    'no decimals': (exportHr, 72.4, '72'),
    'the reading\'s decimals': (exportTemp, 36.65, '36.6'),
    'no thousands separators': (exportSteps, 12345.0, '12345'),
    'negative values': (exportTemp, -2.5, '-2.5'),
  };
  for (final MapEntry(key: name, value: (reading, value, written)) in values.entries) {
    test('value: $name', () => expect(plainValue(reading, value), written));
  }

  test('dates and times every spreadsheet reads', () {
    expect(isoDate(DateTime(2026, 3, 5)), '2026-03-05');
    expect(isoTime(DateTime(2026, 3, 5, 7, 8, 9)), '07:08:09');
  });
}
