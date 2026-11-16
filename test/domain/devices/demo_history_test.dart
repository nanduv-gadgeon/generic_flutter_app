import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/devices/demo_history.dart';
import 'package:generic_flutter_app/domain/history/local_day.dart';

import '../../fixtures/ppg_motion_profile.dart';

/// Made-up history for the debug History demo device. Now is Mon 26 Oct 2026, 10:42.
void main() {
  final now = DateTime(2026, 10, 26, 10, 42);
  final readings = ppgMotionProfile().readings;
  final samples = demoHistory(now, readings);
  final keys = [for (final r in readings) r.key];

  /// The local hours with samples of [key] on the day [back] days before today.
  Set<int> hoursOf(String key, int back) {
    final day = addDays(startOfDay(now), -back);
    return {
      for (final s in samples)
        if (s.key == key && startOfDay(s.at) == day) s.at.toLocal().hour,
    };
  }

  final all = {for (var h = 0; h < 24; h++) h};
  final cases = <({int back, String shows, Set<int> hours})>[
    (back: 6, shows: 'Complete', hours: all),
    (back: 5, shows: 'Partial, missing 02:00–06:00', hours: all.difference({2, 3, 4, 5})),
    (back: 4, shows: 'No data', hours: {}),
    (back: 3, shows: 'Partial, 09:00–21:00 only', hours: {for (var h = 9; h < 21; h++) h}),
    (back: 2, shows: 'Partial, several gaps', hours: all.difference({1, 13, 14, 16, 17})),
    (back: 1, shows: 'Complete', hours: all),
    (back: 0, shows: 'today up to now', hours: {for (var h = 0; h <= 10; h++) h}),
  ];
  for (final c in cases) {
    test('${c.back} days ago: ${c.shows}', () {
      for (final key in keys) {
        expect(hoursOf(key, c.back), c.hours, reason: key);
      }
    });
  }

  test('one value a minute for every reading of the profile', () {
    final perKey = {for (final k in keys) k: samples.where((s) => s.key == k).length};
    // 24 + 20 + 0 + 12 + 19 + 24 hours, and today 00:00–10:41 (10:42:30 is still to come).
    const minutes = (24 + 20 + 0 + 12 + 19 + 24) * 60 + 10 * 60 + 42;

    expect(perKey.values, everyElement(minutes));
  });

  test('nothing after now', () {
    expect(samples.where((s) => s.at.isAfter(now)), isEmpty);
  });

  test('every value is inside its reading\'s normal range', () {
    for (final r in readings) {
      final normal = r.normal!;
      final values = [
        for (final s in samples)
          if (s.key == r.key) s.value,
      ];
      expect(values, everyElement(inInclusiveRange(normal.low, normal.high)), reason: r.key);
    }
  });

  test('the same every time', () {
    final again = demoHistory(now, readings);

    expect(
      [for (final s in again) (s.key, s.value, s.at)],
      [for (final s in samples) (s.key, s.value, s.at)],
    );
  });

  test('readings without a normal range get no values', () {
    final noRange = readings.first.copyWith(normal: null);

    expect(demoHistory(now, [noRange]), isEmpty);
  });
}
