import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/signal/ppg_oximetry.dart';

import '../../fixtures/ppg_motion_profile.dart';

/// Synthetic PPG at 100 Hz: a pulse of [hz] on a steady level, as red and infrared samples.
List<Sample> _pulse(int pairs, {double hz = 1.2, double redAc = 2000, double irAc = 6000}) {
  final t0 = DateTime.utc(2026, 11, 3);
  return [
    for (var k = 0; k < pairs; k++) ...[
      Sample('ppg_red', 200000 + redAc * math.sin(2 * math.pi * hz * k / 100), t0),
      Sample('ppg_ir', 300000 + irAc * math.sin(2 * math.pi * hz * k / 100), t0),
    ],
  ];
}

/// Results by the number of pairs fed when they came.
Map<int, Map<String, double>> _run(List<Sample> samples) {
  final oximetry = PpgOximetry(ppgMotionProfile().signal!.ppgOximetry!.copyWith(finger: null));
  final results = <int, Map<String, double>>{};
  var pairs = 0;
  for (final sample in samples) {
    if (sample.key == 'ppg_ir') pairs++;
    final out = oximetry.feed(sample);
    if (out.isNotEmpty) results[pairs] = {for (final s in out) s.key: s.value};
  }
  return results;
}

void main() {
  // Expected values from an independent Python port of the INOS processor on the same signal.
  final expected = <int, (double?, double?, double, double)>{
    500: (98, null, 1.0165123256885993, 2.138221223536583),
    1000: (96, 78, 0.7206638766125473, 1.4369332604494947),
    1500: (96, 73, 0.657947081464341, 1.3159319630175839),
  };
  final results = _run(_pulse(1500));

  for (final MapEntry(key: pairs, value: (spo2, hr, piRed, piIr)) in expected.entries) {
    test('after $pairs samples: SpO₂ $spo2, heart rate $hr', () {
      final r = results[pairs]!;
      expect(r['spo2'], spo2);
      expect(r['heart_rate'], hr);
      expect(r['pi_red'], closeTo(piRed, 1e-9));
      expect(r['pi_ir'], closeTo(piIr, 1e-9));
    });
  }

  test('gives results once per 100 samples', () {
    expect(results.keys, [for (var n = 100; n <= 1500; n += 100) n]);
  });

  test('has no heart rate while the filters settle', () {
    for (final n in [100, 600, 900]) {
      expect(results[n]!.containsKey('heart_rate'), isFalse, reason: 'after $n samples');
    }
  });

  test('a pulse of 72 per minute settles near 72', () {
    final settled = _run(_pulse(3000));
    expect(settled[3000]!['heart_rate'], closeTo(72, 1));
  });

  // Known behaviour of the INOS algorithm (same in the reference port), kept for parity and
  // listed for review in docs/decisions.md.
  test('a pulse of 180 per minute reads as about half, as in INOS', () {
    expect(_run(_pulse(3000, hz: 3))[3000]!['heart_rate'], 91);
  });

  test('no pulse gives no heart rate, but SpO₂ 80 from filter ringing, as in INOS', () {
    final flat = _run(_pulse(3000, redAc: 0, irAc: 0));
    expect(flat[3000]!.containsKey('heart_rate'), isFalse);
    expect(flat[3000]!['spo2'], 80);
  });

  test('SpO₂ is never above 100, even when the formula gives more', () {
    // R ≈ 0.05 gives about 111 from the formula.
    final spo2 = [for (final r in _run(_pulse(1000, redAc: 200)).values) ?r['spo2']];

    expect(spo2, everyElement(lessThanOrEqualTo(100)));
    expect(spo2.last, 100); // Once the filters settle.
  });

  test('ignores other readings and waits for both colours', () {
    final oximetry = PpgOximetry(ppgMotionProfile().signal!.ppgOximetry!.copyWith(finger: null));
    final t = DateTime.utc(2026);
    for (var i = 0; i < 300; i++) {
      expect(oximetry.feed(Sample('battery', 80, t)), isEmpty);
      expect(oximetry.feed(Sample('ppg_red', 200000, t)), isEmpty);
    }
  });
}
