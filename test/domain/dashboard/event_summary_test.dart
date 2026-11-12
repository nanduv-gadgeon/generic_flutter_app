import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/dashboard/event_summary.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/models/reading.dart';

final _dayStart = DateTime.utc(2026, 11, 11);

/// An event [minutes] after the start of the day (negative: the day before).
DeviceEvent _e(DeviceEventKind kind, int minutes) =>
    DeviceEvent(kind, _dayStart.add(Duration(minutes: minutes)), code: 0);

const _start = DeviceEventKind.start;
const _stop = DeviceEventKind.stop;
const _error = DeviceEventKind.error;

void main() {
  // (events, sessions, run time in minutes, errors, running)
  final cases = <String, (List<DeviceEvent>, int, int, int, bool)>{
    'one session': ([_e(_start, 60), _e(_stop, 90)], 1, 30, 0, false),
    'two sessions: from the first START to the last STOP, the break included': (
      [_e(_start, 360), _e(_stop, 420), _e(_start, 450), _e(_stop, 480)],
      2,
      120,
      0,
      false,
    ),
    'an error during a session': ([_e(_start, 60), _e(_error, 70), _e(_stop, 90)], 1, 30, 1, false),
    'still running after the last STOP: up to that STOP, not the clock': (
      [_e(_start, 360), _e(_stop, 420), _e(_start, 480)],
      2,
      60,
      0,
      true,
    ),
    'a START with no STOP yet: zero': ([_e(_start, 600)], 1, 0, 0, true),
    'a STOP before the first START is not the last STOP': (
      [_e(_stop, 30), _e(_start, 60)],
      1,
      0,
      0,
      true,
    ),
    'a STOP before the first START, then a later STOP': (
      [_e(_stop, 30), _e(_start, 60), _e(_stop, 70)],
      1,
      10,
      0,
      false,
    ),
    'a session from yesterday: only today’s logs count': (
      [_e(_start, -30), _e(_stop, 30)],
      0,
      0,
      0,
      false,
    ),
    'yesterday’s START does not count, today’s does': (
      [_e(_start, -30), _e(_stop, 30), _e(_start, 60), _e(_stop, 120)],
      1,
      60,
      0,
      false,
    ),
    'logs dated after today do not count': (
      [_e(_start, 60), _e(_stop, 120), _e(_stop, 24 * 60 + 5), _e(_error, 24 * 60 + 6)],
      1,
      60,
      0,
      false,
    ),
    'yesterday’s errors do not count': ([_e(_error, -5), _e(_error, 5)], 0, 0, 1, false),
    'events in any order': ([_e(_stop, 90), _e(_start, 60)], 1, 30, 0, false),
    'unknown events are ignored': ([_e(DeviceEventKind.unknown, 10)], 0, 0, 0, false),
  };
  for (final MapEntry(key: name, value: (events, sessions, minutes, errors, running))
      in cases.entries) {
    test(name, () {
      expect(
        summarise(events, dayStart: _dayStart),
        EventSummary(
          sessions: sessions,
          runTime: Duration(minutes: minutes),
          errors: errors,
          running: running,
        ),
      );
    });
  }

  test('no events: nothing known', () {
    final summary = summarise(const [], dayStart: _dayStart);
    expect(summary, EventSummary.empty);
    expect(summary.hasEvents, isFalse);
  });

  test('a local day ends at the next local midnight', () {
    final dayStart = DateTime(2026, 11, 11);
    DeviceEvent at(DeviceEventKind kind, DateTime time) => DeviceEvent(kind, time, code: 0);
    final summary = summarise([
      at(_start, DateTime(2026, 11, 11, 8)),
      at(_stop, DateTime(2026, 11, 11, 23, 30)),
      at(_stop, DateTime(2026, 11, 12, 0, 30)),
    ], dayStart: dayStart);

    expect(summary.runTime, const Duration(hours: 15, minutes: 30));
  });

  test('values for event readings: run time in hours, counts as numbers', () {
    const summary = EventSummary(
      sessions: 3,
      runTime: Duration(hours: 2, minutes: 30),
      errors: 1,
      running: true,
    );
    expect(summary.valueFor(ReadingSource.eventsRunTimeToday), 2.5);
    expect(summary.valueFor(ReadingSource.eventsSessionsToday), 3);
    expect(summary.valueFor(ReadingSource.eventsErrorsToday), 1);
    expect(summary.valueFor(ReadingSource.device), isNull);
  });
}
