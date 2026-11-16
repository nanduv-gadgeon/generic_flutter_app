/// Made-up history for trying History without hardware (debug builds only): a week of readings
/// with a fixed pattern of full, partial and empty days. Never real data. Pure Dart.
library;

import 'dart:math' as math;

import '../decoder/decoded_packet.dart' show Sample;
import '../history/local_day.dart';
import '../models/reading.dart';

/// The hours with readings on each day, by days before today (0 = today, up to now), so every
/// state of History shows: Complete, Partial with one or several gaps, and No data.
final Map<int, Set<int>> demoHistoryHours = {
  6: _all,
  5: _all.difference({2, 3, 4, 5}), // missing 02:00–06:00
  4: const {}, // No data
  3: {for (var h = 9; h < 21; h++) h}, // 09:00–21:00 only
  2: _all.difference({1, 13, 14, 16, 17}), // several gaps
  1: _all,
  0: _all,
};

final _all = {for (var h = 0; h < 24; h++) h};

/// One value a minute for each of [readings] (those with a normal range) over [demoHistoryHours]
/// up to [now], oldest first. Values stay inside each reading's normal range and drift through the
/// day (lowest around 04:00), with a little noise; the same every time for the same [now].
List<Sample> demoHistory(DateTime now, List<Reading> readings, {int everyMinutes = 1}) {
  final random = math.Random(4);
  final today = startOfDay(now);
  final withRange = [
    for (final r in readings)
      if (r.normal case final normal?) (reading: r, normal: normal),
  ];
  final samples = <Sample>[];
  for (var back = 6; back >= 0; back--) {
    final day = addDays(today, -back);
    final hours = demoHistoryHours[back] ?? const <int>{};
    for (var h = 0; h < 24; h++) {
      if (!hours.contains(h)) continue;
      for (var m = 0; m < 60; m += everyMinutes) {
        final at = DateTime(day.year, day.month, day.day, h, m, 30);
        // Skipped by a clock change, or still to come.
        if (at.hour != h || at.isAfter(now)) continue;
        // Lowest around 04:00, highest around 16:00.
        final drift = math.sin(2 * math.pi * (h + m / 60 - 10) / 24);
        for (final (:reading, :normal) in withRange) {
          final span = normal.high - normal.low;
          final share = (0.45 + 0.25 * drift + 0.08 * (random.nextDouble() * 2 - 1)).clamp(
            0.05,
            0.95,
          );
          samples.add(Sample(reading.key, _round(normal.low + span * share, reading), at.toUtc()));
        }
      }
    }
  }
  return samples;
}

double _round(double value, Reading reading) {
  final scale = math.pow(10, reading.decimals);
  return (value * scale).round() / scale;
}
