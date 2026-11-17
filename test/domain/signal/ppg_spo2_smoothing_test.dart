import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/models/streaming_settings.dart';
import 'package:generic_flutter_app/domain/signal/ppg_oximetry.dart';

import '../../fixtures/ppg_motion_profile.dart';

final _t = DateTime.utc(2026, 11, 3);

/// Synthetic PPG at 100 Hz, one entry of [redAc] per second: a 1.2 Hz pulse on a steady level.
/// A red swing of 2000 reads about 96 %; a larger one reads lower (a dip). Made-up data only.
List<Sample> _signal(List<double> redAc, {double irAc = 6000}) => [
  for (final (s, red) in redAc.indexed)
    for (var k = 0; k < 100; k++) ...[
      Sample('ppg_red', 200000 + red * math.sin(2 * math.pi * 1.2 * (s * 100 + k) / 100), _t),
      Sample('ppg_ir', 300000 + irAc * math.sin(2 * math.pi * 1.2 * (s * 100 + k) / 100), _t),
    ],
];

/// SpO₂ given each second (null: none), and whether a heart rate came with it.
List<({double? spo2, bool heartRate})> _seconds(PpgOximetrySettings settings, List<Sample> signal) {
  final oximetry = PpgOximetry(settings.copyWith(finger: null));
  return [
    for (final sample in signal)
      if (oximetry.feed(sample) case final out when out.isNotEmpty)
        (
          spo2: out.where((r) => r.key == 'spo2').firstOrNull?.value,
          heartRate: out.any((r) => r.key == 'heart_rate'),
        ),
  ];
}

PpgOximetrySettings get _shipped => ppgMotionProfile().signal!.ppgOximetry!;

void main() {
  test('the shipped profile averages SpO₂ per result and needs a pulse', () {
    expect(_shipped.spo2.averageOf, Spo2AverageOf.results);
    expect(_shipped.spo2.needsPulse, isTrue);
  });

  test('without either setting, SpO₂ is worked out as in INOS', () {
    const spo2 = Spo2Settings(key: 'spo2', coefficients: [1, 2, 3], min: 0, max: 1, average: 1);
    expect(spo2.averageOf, Spo2AverageOf.pairs);
    expect(spo2.needsPulse, isFalse);
  });

  group('no pulse, no SpO₂', () {
    final flat = _signal(List.filled(30, 0), irAc: 0);

    test('a signal with no pulse gives none (INOS gives 80 from filter ringing)', () {
      expect(_seconds(_shipped, flat).map((s) => s.spo2), everyElement(isNull));
      expect(_seconds(inosSpo2(_shipped), flat).last.spo2, 80);
    });

    test('with a pulse, SpO₂ comes only once a heart rate is found', () {
      final seconds = _seconds(_shipped, _signal(List.filled(30, 2000)));

      final firstSpo2 = seconds.indexWhere((s) => s.spo2 != null);
      expect(firstSpo2, greaterThanOrEqualTo(seconds.indexWhere((s) => s.heartRate)));
      expect(seconds.last.spo2, 96);
    });
  });

  group('averaged per result', () {
    // 20 s steady, a 2 s dip (as when the finger moves), then 20 s steady again.
    final dip = _signal([...List.filled(20, 2000.0), 3000, 3000, ...List.filled(20, 2000.0)]);
    double lowest(PpgOximetrySettings s) =>
        [for (final second in _seconds(s, dip).skip(15)) ?second.spo2].reduce(math.min);

    test('a short dip is smoothed out instead of shown', () {
      final inos = lowest(inosSpo2(_shipped));
      final smoothed = lowest(_shipped);

      expect(inos, lessThan(90));
      expect(smoothed, greaterThan(inos + 3));
    });

    test('a steady signal reads the same as in INOS', () {
      final steady = _signal(List.filled(30, 2000));
      expect(_seconds(_shipped, steady).last.spo2, _seconds(inosSpo2(_shipped), steady).last.spo2);
    });
  });
}
