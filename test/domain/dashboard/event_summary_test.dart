import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/dashboard/event_summary.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/models/reading.dart';

final _dayStart = DateTime.utc(2026, 11, 11);
final _now = _dayStart.add(const Duration(hours: 12));

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
    'two sessions and an error': (
      [_e(_start, 60), _e(_error, 70), _e(_stop, 90), _e(_start, 120), _e(_stop, 180)],
      2,
      90,
      1,
      false,
    ),
    'a session still running counts up to now': ([_e(_start, 600)], 1, 120, 0, true),
    'a stop with no start is ignored': (
      [_e(_stop, 30), _e(_start, 60), _e(_stop, 70)],
      1,
      10,
      0,
      false,
    ),
    'a start while running starts another session': (
      [_e(_start, 60), _e(_start, 100), _e(_stop, 110)],
      2,
      50,
      0,
      false,
    ),
    'a session from yesterday counts only from midnight': (
      [_e(_start, -30), _e(_stop, 30)],
      0,
      30,
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
        summarise(events, dayStart: _dayStart, now: _now),
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
    final summary = summarise(const [], dayStart: _dayStart, now: _now);
    expect(summary, EventSummary.empty);
    expect(summary.hasEvents, isFalse);
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
