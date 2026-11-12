import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/dashboard/reading_status.dart';
import 'package:generic_flutter_app/domain/models/reading.dart';

const _range = Reading(
  key: 'hr',
  label: 'Heart rate',
  unit: 'bpm',
  icon: ReadingIcon.pulse,
  normal: NormalRange(low: 60, high: 100),
);
const _goal = Reading(key: 'steps', label: 'Steps', unit: '', icon: ReadingIcon.trend, goal: 10000);
const _plain = Reading(key: 'ses', label: 'Sessions', unit: '', icon: ReadingIcon.list);
const _zones = Reading(
  key: 'temp',
  label: 'Temperature',
  unit: '°C',
  icon: ReadingIcon.thermo,
  zones: [
    ReadingZone(below: 37.5, label: 'Normal', kind: StatusKind.ok),
    ReadingZone(below: 38, label: 'High', kind: StatusKind.warn),
    ReadingZone(label: 'Fever', kind: StatusKind.danger),
  ],
);
const _states = Reading(
  key: 'rhythm',
  label: 'Rhythm',
  unit: '',
  icon: ReadingIcon.ecg,
  states: {'1': ReadingState(label: 'Sinus rhythm', kind: StatusKind.ok)},
);

void main() {
  const ok = StatusKind.ok;
  const warn = StatusKind.warn;
  final cases = <String, (Reading, double?, bool, ReadingStatus)>{
    'in range': (_range, 72, true, const ReadingStatus(StatusWord.normal, kind: ok)),
    'on the low edge': (_range, 60, true, const ReadingStatus(StatusWord.normal, kind: ok)),
    'above range': (_range, 101, true, const ReadingStatus(StatusWord.high, kind: warn)),
    'below range': (_range, 59, true, const ReadingStatus(StatusWord.low, kind: warn)),
    'no value while live': (
      _range,
      null,
      true,
      const ReadingStatus(StatusWord.noSignal, kind: warn),
    ),
    'no value, not live': (_range, null, false, ReadingStatus.none),
    'no value, nothing to judge': (_plain, null, true, ReadingStatus.none),
    'a plain value': (_plain, 3, true, ReadingStatus.none),
    'goal progress': (
      _goal,
      6500,
      true,
      const ReadingStatus(StatusWord.goal, kind: ok, goalFraction: 0.65),
    ),
    'zone below the first limit': (
      _zones,
      37.2,
      true,
      const ReadingStatus(StatusWord.zone, kind: ok, label: 'Normal'),
    ),
    'zone on a limit goes up': (
      _zones,
      37.5,
      true,
      const ReadingStatus(StatusWord.zone, kind: warn, label: 'High'),
    ),
    'last zone has no limit': (
      _zones,
      38.4,
      true,
      const ReadingStatus(StatusWord.zone, kind: StatusKind.danger, label: 'Fever'),
    ),
    'a coded state': (
      _states,
      1,
      true,
      const ReadingStatus(StatusWord.state, kind: ok, label: 'Sinus rhythm'),
    ),
    'an unknown code': (_states, 2, true, ReadingStatus.none),
  };
  for (final MapEntry(key: name, value: (reading, value, live, expected)) in cases.entries) {
    test('statusOf: $name', () => expect(statusOf(reading, value, live: live), expected));
  }

  final scales = <String, (Reading, NormalRange?)>{
    'its own scale': (
      _range.copyWith(scale: const NormalRange(low: 40, high: 160)),
      const NormalRange(low: 40, high: 160),
    ),
    'normal widened by half its span': (_range, const NormalRange(low: 40, high: 120)),
    'not below 0 for a range from 0': (
      _range.copyWith(normal: const NormalRange(low: 0, high: 15)),
      const NormalRange(low: 0, high: 22.5),
    ),
    'negative ranges keep going down': (
      _range.copyWith(normal: const NormalRange(low: -10, high: 10)),
      const NormalRange(low: -20, high: 20),
    ),
    '0 to the goal': (_goal, const NormalRange(low: 0, high: 10000)),
    'none for a plain reading': (_plain, null),
  };
  for (final MapEntry(key: name, value: (reading, expected)) in scales.entries) {
    test('scaleOf: $name', () => expect(scaleOf(reading), expected));
  }

  const scale = NormalRange(low: 40, high: 160);
  final fractions = <double, double>{40: 0, 100: 0.5, 160: 1, 20: 0, 200: 1};
  for (final MapEntry(key: value, value: expected) in fractions.entries) {
    test('scaleFraction of $value on 40–160 is $expected', () {
      expect(scaleFraction(scale, value), expected);
    });
  }

  test('scaleFraction of an empty scale is 0', () {
    expect(scaleFraction(const NormalRange(low: 0, high: 0), 1), 0);
  });

  test('isWarning is true only for warn and danger', () {
    expect(const ReadingStatus(StatusWord.high, kind: StatusKind.warn).isWarning, isTrue);
    expect(const ReadingStatus(StatusWord.normal, kind: StatusKind.ok).isWarning, isFalse);
  });
}
