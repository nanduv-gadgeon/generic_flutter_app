import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/device_profile_registry.dart';
import 'package:generic_flutter_app/domain/history/day_detail.dart';
import 'package:generic_flutter_app/domain/history/day_summary.dart';
import 'package:generic_flutter_app/domain/history/history_days.dart';
import 'package:generic_flutter_app/domain/models/reading.dart';

import '../../fixtures/history_harness.dart';

/// A day whose clock skips [skipped] (a spring-forward day), whatever the test machine's zone.
class _ShortDay extends HistoryDay {
  _ShortDay(this.skipped) : super(DateTime(2026, 3, 29));

  final int skipped;

  @override
  List<int> get clockHours => [
    for (var h = 0; h < 24; h++)
      if (h != skipped) h,
  ];
}

DaySummary _summary(String key, int hours) => DaySummary(
  deviceId: 1,
  key: key,
  day: DateTime(2026, 10, 21),
  min: 1,
  avg: 1,
  max: 1,
  count: 1,
  hours: hours,
);

void main() {
  final day = HistoryDay(DateTime(2026, 10, 21));
  final all = {for (var h = 0; h < 24; h++) h};

  group('hoursOfMask and hoursWithData', () {
    final cases = <({String name, int mask, Set<int> hours})>[
      (name: 'none', mask: 0, hours: {}),
      (name: 'midnight and 23:00', mask: 1 | 1 << 23, hours: {0, 23}),
      (name: 'every hour', mask: (1 << 24) - 1, hours: all),
    ];
    for (final c in cases) {
      test(c.name, () => expect(hoursOfMask(c.mask), c.hours));
    }

    test('a device has data in an hour when any of its readings has', () {
      final summaries = [
        _summary('heart_rate', 1 << 2 | 1 << 3),
        _summary('spo2', 1 << 3 | 1 << 9),
      ];

      expect(hoursWithData(summaries), {2, 3, 9});
      expect(hoursWithData(const []), isEmpty);
    });
  });

  group('missingHours and hourRanges', () {
    final cases = <({String name, Set<int> data, Set<int> check, List<(int, int)> ranges})>[
      (name: 'no gaps', data: all, check: all, ranges: []),
      (
        name: 'gap 02:00–06:00 (TC-1.4-006)',
        data: all.difference({2, 3, 4, 5}),
        check: all,
        ranges: [(2, 5)],
      ),
      (
        name: 'gaps at the start and the end',
        data: {for (var h = 7; h < 22; h++) h},
        check: all,
        ranges: [(0, 6), (22, 23)],
      ),
      (
        name: '09–12, 13–15 and 16–18',
        data: all.difference({9, 10, 11, 13, 14, 16, 17}),
        check: all,
        ranges: [(9, 11), (13, 14), (16, 17)],
      ),
      (
        name: 'every other hour: 12 gaps',
        data: {for (var h = 1; h < 24; h += 2) h},
        check: all,
        ranges: [for (var h = 0; h < 24; h += 2) (h, h)],
      ),
      (name: 'nothing at all', data: {}, check: all, ranges: [(0, 23)]),
      (
        name: 'today: hours not begun are not missing',
        data: {0, 1, 2},
        check: {0, 1, 2},
        ranges: [],
      ),
      (name: 'today: a gap so far', data: {0, 3}, check: {0, 1, 2, 3}, ranges: [(1, 2)]),
    ];
    for (final c in cases) {
      test(c.name, () => expect(hourRanges(missingHours(c.data, c.check), day), c.ranges));
    }

    test('an hour skipped by the clocks going forward does not split a gap', () {
      final short = _ShortDay(2);

      expect(hourRanges([1, 3], short), [(1, 3)]);
      expect(nextHourOf(short, 1), 3);
      expect(nextHourOf(short, 23), isNull);
    });
  });

  group('coveragePercent', () {
    final cases = <({String name, Set<int> data, Set<int> check, int percent})>[
      (name: 'all', data: all, check: all, percent: 100),
      (name: 'none', data: {}, check: all, percent: 0),
      (name: 'two thirds', data: {for (var h = 0; h < 16; h++) h}, check: all, percent: 66),
      (
        name: 'rounded down, never 100 when partial',
        data: all.difference({5}),
        check: all,
        percent: 95,
      ),
      (name: 'nothing to check', data: {}, check: {}, percent: 0),
      (name: 'hours after now do not count', data: {5}, check: {0, 1, 2}, percent: 0),
    ];
    for (final c in cases) {
      test(c.name, () => expect(coveragePercent(c.data, c.check), c.percent));
    }

    test('at least 1 with any data', () {
      final many = {for (var h = 0; h < 200; h++) h};
      expect(coveragePercent({0}, many), 1);
    });
  });

  group('storedKeys and historyReadings', () {
    final registry = DeviceProfileRegistry(historyConfig());

    test('stored keys leave out readings worked out from events', () {
      expect(storedKeys(registry.byId('ief_device_v1')), ['current']);
    });

    final cases = <({String profile, List<String> keys})>[
      // The Live dashboard's order: the SpO₂ gauge, then the tiles.
      (profile: 'ppg_motion_v1', keys: ['spo2', 'heart_rate', 'pi_ir', 'pi_red']),
      // Run time, Sessions and Errors are worked out from today's events.
      (profile: 'ief_device_v1', keys: ['current']),
      // Diastolic is shown with systolic.
      (profile: 'smart_band_v1', keys: ['hr', 'spo2', 'bp', 'temp', 'steps', 'sleep', 'resp']),
      // The ECG trace is only drawn live; rhythm, electrodes and signal are coded states.
      (profile: 'ecg_monitor_v1', keys: ['hr', 'hrv', 'rr', 'resp']),
    ];
    for (final c in cases) {
      test(c.profile, () {
        final keys = historyReadings(registry.byId(c.profile)).map((r) => r.key);
        expect(keys, c.keys);
      });
    }
  });

  group('hourlyAverages', () {
    HourStats hour(String key, int h, double sum, int count) => HourStats(
      deviceId: 1,
      key: key,
      start: DateTime(2026, 10, 21, h).toUtc(),
      min: 0,
      max: 0,
      sum: sum,
      count: count,
    );

    test('the average of each hour of one reading; other readings and empty hours left out', () {
      final hours = [
        hour('spo2', 9, 970, 10),
        hour('spo2', 10, 1920, 20),
        hour('heart_rate', 9, 720, 10),
        hour('spo2', 11, 0, 0),
      ];

      expect(hourlyAverages(hours, 'spo2'), {9: 97.0, 10: 96.0});
    });

    test('two figures for the same wall-clock hour are one hour', () {
      final hours = [hour('spo2', 1, 950, 10), hour('spo2', 1, 990, 10)];

      expect(hourlyAverages(hours, 'spo2'), {1: 97.0});
    });
  });

  group('chartRange', () {
    final cases = <({String name, List<double> values, double low, double high})>[
      (name: 'widened by 35 % of the span', values: [95, 97], low: 94.3, high: 97.7),
      (name: 'one value: widened by 1', values: [72], low: 71, high: 73),
      (name: 'all the same', values: [0.2, 0.2], low: -0.8, high: 1.2),
    ];
    for (final c in cases) {
      test(c.name, () {
        final range = chartRange(c.values);
        expect(range.low, closeTo(c.low, 1e-9));
        expect(range.high, closeTo(c.high, 1e-9));
      });
    }

    final withNormal =
        <({String name, List<double> values, NormalRange normal, double low, double high})>[
          (
            name: 'SpO₂ below its normal range: the band is taken in',
            values: [88, 90],
            normal: const NormalRange(low: 95, high: 100),
            low: 86.8,
            high: 101.2,
          ),
          (
            name: 'PI above its normal range: the band is taken in',
            values: [2, 3],
            normal: const NormalRange(low: 0.1, high: 1),
            low: -0.19,
            high: 3.29,
          ),
          (
            name: 'values inside the normal range: the normal range is the span',
            values: [70, 80],
            normal: const NormalRange(low: 60, high: 100),
            low: 56,
            high: 104,
          ),
        ];
    for (final c in withNormal) {
      test(c.name, () {
        final range = chartRange(c.values, normal: c.normal);
        expect(range.low, closeTo(c.low, 1e-9));
        expect(range.high, closeTo(c.high, 1e-9));
      });
    }
  });
}
