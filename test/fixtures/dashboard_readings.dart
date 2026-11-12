import 'package:generic_flutter_app/domain/models/reading.dart';

/// Readings like the VitaCare profiles', for view tests.
const hrReading = Reading(
  key: 'hr',
  label: 'Heart rate',
  unit: 'bpm',
  icon: ReadingIcon.pulse,
  normal: NormalRange(low: 60, high: 100),
  scale: NormalRange(low: 40, high: 160),
);
const bpReading = Reading(
  key: 'bp',
  label: 'Blood pressure',
  unit: 'mmHg',
  icon: ReadingIcon.heart,
  normal: NormalRange(low: 90, high: 120),
  pair: 'bp_dia',
);
const stepsReading = Reading(
  key: 'steps',
  label: 'Steps',
  unit: 'today',
  icon: ReadingIcon.trend,
  goal: 10000,
);
const sleepReading = Reading(
  key: 'sleep',
  label: 'Sleep',
  unit: 'last night',
  icon: ReadingIcon.moon,
  decimals: 1,
  goal: 8,
  format: ReadingFormat.hoursMinutes,
);
const sessionsReading = Reading(
  key: 'sessions',
  label: 'Sessions',
  unit: '',
  icon: ReadingIcon.list,
  source: ReadingSource.eventsSessionsToday,
);
const tempReading = Reading(
  key: 'temp',
  label: 'Temperature',
  unit: '°C',
  icon: ReadingIcon.thermo,
  decimals: 1,
  scale: NormalRange(low: 35, high: 40),
  zones: [
    ReadingZone(below: 37.5, label: 'Normal', kind: StatusKind.ok),
    ReadingZone(below: 38, label: 'High', kind: StatusKind.warn),
    ReadingZone(label: 'Fever', kind: StatusKind.danger),
  ],
);
const rhythmReading = Reading(
  key: 'rhythm',
  label: 'Rhythm',
  unit: '',
  icon: ReadingIcon.ecg,
  states: {'1': ReadingState(label: 'Sinus rhythm', kind: StatusKind.ok)},
);
