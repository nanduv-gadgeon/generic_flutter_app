import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/history/day_summary.dart';
import 'package:generic_flutter_app/domain/history/local_day.dart';
import 'package:generic_flutter_app/domain/history/summarise_day.dart';

/// Made-up hourly stats: device 1's heart rate unless given.
HourStats _hour(
  DateTime start,
  double min,
  double max,
  double sum,
  int count, {
  int deviceId = 1,
  String key = 'hr',
}) => HourStats(
  deviceId: deviceId,
  key: key,
  start: start,
  min: min,
  max: max,
  sum: sum,
  count: count,
);

/// Days summed up from hourly stats, in local time.
void main() {
  final day = DateTime(2026, 11, 10);
  DateTime at(int hour) => DateTime(2026, 11, 10, hour);

  // (hours, min, avg, max, count, hours with data)
  final cases = <String, (List<HourStats>, double, double, double, int, List<int>)>{
    'one reading': ([_hour(at(9), 70, 70, 70, 1)], 70, 70, 70, 1, [9]),
    'one hour of several readings': ([_hour(at(0), 60, 80, 280, 4)], 60, 70, 80, 4, [0]),
    'lowest, average and highest across hours (average of every reading, not of hours)': (
      [_hour(at(1), 60, 70, 130, 2), _hour(at(13), 50, 90, 560, 8), _hour(at(23), 65, 65, 65, 1)],
      50,
      755 / 11,
      90,
      11,
      [1, 13, 23],
    ),
    'an hour with no readings is skipped': (
      [_hour(at(2), 60, 60, 60, 1), _hour(at(3), 0, 0, 0, 0)],
      60,
      60,
      60,
      1,
      [2],
    ),
  };
  for (final MapEntry(key: name, value: (hours, min, avg, max, count, withData)) in cases.entries) {
    test(name, () {
      final summary = summariseDays(hours).single;

      expect(summary.day, day);
      expect(summary.min, min);
      expect(summary.avg, closeTo(avg, 1e-9));
      expect(summary.max, max);
      expect(summary.count, count);
      expect([
        for (var h = 0; h < 24; h++)
          if (summary.hasHour(h)) h,
      ], withData);
      expect(summary.hoursWithData, withData.length);
    });
  }

  test('coverage is the share of the day with readings', () {
    final hours = [for (var h = 0; h < 6; h++) _hour(at(h), 1, 1, 1, 1)];
    expect(summariseDays(hours).single.coverage, 0.25);
    final full = [for (var h = 0; h < 24; h++) _hour(at(h), 1, 1, 1, 1)];
    expect(summariseDays(full).single.coverage, 1);
  });

  test('one summary per device, reading and day, in that order, days oldest first', () {
    final next = DateTime(2026, 11, 11, 8);
    final summaries = summariseDays([
      _hour(next, 1, 1, 1, 1, deviceId: 2),
      _hour(next, 1, 1, 1, 1),
      _hour(at(23), 1, 1, 1, 1, key: 'spo2'),
      _hour(at(8), 1, 1, 1, 1),
      _hour(at(9), 3, 3, 3, 1),
    ]);

    expect(summaries.map((s) => (s.deviceId, s.key, dayNumber(s.day), s.count)), [
      (1, 'hr', 20261110, 2),
      (1, 'hr', 20261111, 1),
      (1, 'spo2', 20261110, 1),
      (2, 'hr', 20261111, 1),
    ]);
  });

  test('no hours, no summaries', () {
    expect(summariseDays(const []), isEmpty);
  });

  test('hours given in UTC count on their local day and hour', () {
    final local = at(23);
    final summary = summariseDays([_hour(local.toUtc(), 1, 1, 1, 1)]).single;

    expect(summary.day, day);
    expect(summary.hasHour(23), isTrue);
  });

  // Run with e.g. TZ=Europe/London to check them; skipped where the clocks do not change.
  final spring = DateTime(2026, 3, 29);
  final autumn = DateTime(2026, 10, 25);
  test('a day the clocks go forward has 23 hours to fill', () {
    expect(hoursIn(spring), 23);
    final hours = [
      for (var t = spring; t.isBefore(nextDay(spring)); t = t.add(const Duration(hours: 1)))
        _hour(t, 1, 1, 1, 1),
    ];
    final summary = summariseDays(hours).single;
    expect(summary.hoursWithData, 23);
    expect(summary.coverage, 1);
  }, skip: nextDay(spring).difference(spring).inHours == 24 ? 'no DST change here' : false);

  test('a day the clocks go back counts the repeated hour once', () {
    expect(hoursIn(autumn), 24);
    final hours = [
      for (var t = autumn; t.isBefore(nextDay(autumn)); t = t.add(const Duration(hours: 1)))
        _hour(t, 1, 1, 1, 1),
    ];
    final summary = summariseDays(hours).single;
    expect(summary.count, 25);
    expect(summary.hoursWithData, 24);
    expect(summary.coverage, 1);
  }, skip: nextDay(autumn).difference(autumn).inHours == 24 ? 'no DST change here' : false);

  test('an ordinary day has 24 hours', () {
    expect(hoursIn(day), 24);
  });
}
