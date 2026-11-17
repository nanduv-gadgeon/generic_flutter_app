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

/// Results by the number of pairs fed when they came. With SpO₂ as in INOS and without the
/// profile's PI limit unless [capped], so the values compare with the INOS processor's.
Map<int, Map<String, double>> _run(List<Sample> samples, {bool capped = false}) {
  final settings = inosSpo2(ppgMotionProfile().signal!.ppgOximetry!);
  return _results(
    PpgOximetry(
      settings.copyWith(
        finger: null,
        perfusion: capped ? settings.perfusion : settings.perfusion.copyWith(max: null),
      ),
    ),
    samples,
  );
}

/// What [oximetry] gives for [samples], by the number of pairs fed when it came.
Map<int, Map<String, double>> _results(PpgOximetry oximetry, List<Sample> samples) {
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

  test('SpO₂ above 100 is left out, even when the formula gives it', () {
    // R ≈ 0.05 gives about 111 from the formula once the filters settle; only the values within
    // 60–100 from before then are averaged.
    final results = _run(_pulse(1000, redAc: 200));
    final spo2 = [for (final r in results.values) ?r['spo2']];

    expect(spo2, everyElement(lessThanOrEqualTo(100)));
    // Once settled the formula gives about 111: no SpO₂ at all, rather than 100.
    expect([
      for (final n in [800, 900, 1000]) results[n]!['spo2'],
    ], everyElement(isNull));
  });

  test('SpO₂ outside the limits is left out, not given as the limit', () {
    // This signal reads about 96 %; with an upper limit of 90 every value is out of range.
    final settings = inosSpo2(ppgMotionProfile().signal!.ppgOximetry!);
    final oximetry = PpgOximetry(
      settings.copyWith(finger: null, spo2: settings.spo2.copyWith(max: 90)),
    );

    final seconds = [
      for (final s in _pulse(1500))
        if (oximetry.feed(s) case final out when out.isNotEmpty)
          {for (final r in out) r.key: r.value},
    ];
    final settled = seconds.skip(5); // once the filters have settled (500 samples)

    // Not given as 90, and earlier values are not repeated.
    expect(settled.where((r) => r.containsKey('spo2')), isEmpty);
    expect(settled.where((r) => r.containsKey('heart_rate')), isNotEmpty); // the rest still comes
  });

  test("PI above the profile's limit of 1 is left out; SpO₂ is not changed by it", () {
    // This signal's PI (IR) is about 1.3–2.1 without the limit (see the INOS values above).
    final limited = _run(_pulse(1500), capped: true);
    final free = _run(_pulse(1500));

    expect(ppgMotionProfile().signal!.ppgOximetry!.perfusion.max, 1);
    for (final pairs in limited.keys) {
      final l = limited[pairs]!;
      final f = free[pairs]!;
      for (final key in ['pi_ir', 'pi_red']) {
        expect(l[key], f[key]! > 1 ? isNull : f[key], reason: '$key after $pairs samples');
      }
      expect(l['spo2'], f['spo2'], reason: 'after $pairs samples');
    }
    expect(limited[1000]!.containsKey('pi_ir'), isFalse);
    expect(limited[1000]!['pi_red'], closeTo(0.7206638766125473, 1e-9)); // below the limit
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
