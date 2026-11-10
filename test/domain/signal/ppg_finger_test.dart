import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/models/streaming_settings.dart';
import 'package:generic_flutter_app/domain/signal/ppg_oximetry.dart';

import '../../fixtures/ppg_motion_profile.dart';

final _t = DateTime.utc(2026, 11, 3);

/// One second (100 pairs) of light levels: a finger with a 1.2 Hz pulse, or the sensor's
/// background with nothing on it (protocol doc §3.3: about 3 000 red, 6 000 IR).
List<Sample> _second(int s, {required bool finger}) => [
  for (var k = 0; k < 100; k++) ...[
    if (finger) ...[
      Sample('ppg_red', 200000 + 2000 * math.sin(2 * math.pi * 1.2 * (s * 100 + k) / 100), _t),
      Sample('ppg_ir', 300000 + 6000 * math.sin(2 * math.pi * 1.2 * (s * 100 + k) / 100), _t),
    ] else ...[
      Sample('ppg_red', 3000, _t),
      Sample('ppg_ir', 6000, _t),
    ],
  ],
];

/// What [oximetry] gave over each second, and its contact at the end of it.
List<({SensorContact? contact, Map<String, double> values})> _run(
  PpgOximetry oximetry,
  List<bool> fingerBySecond,
) => [
  for (final (s, finger) in fingerBySecond.indexed)
    (() {
      final values = <String, double>{};
      for (final sample in _second(s, finger: finger)) {
        for (final r in oximetry.feed(sample)) {
          values[r.key] = r.value;
        }
      }
      return (contact: oximetry.contact, values: values);
    })(),
];

PpgOximetrySettings _settings() => ppgMotionProfile().signal!.ppgOximetry!;

void main() {
  test('the shipped profile checks for a finger (protocol doc §6.4–6.5)', () {
    expect(_settings().finger, const FingerSettings(minDcIr: 12000, minAcIr: 35, settleSeconds: 5));
  });

  // Algorithm vectors from docs/protocols/ppg_motion_v1.md §8.5.
  group('hasFinger', () {
    final cases = <(double, double), bool>{
      (11999, 100): false,
      (26000, 34): false,
      (26000, 50): true,
      (12000, 35): true,
    };
    for (final MapEntry(key: (dc, ac), value: expected) in cases.entries) {
      test('DC_ir = $dc, AC_ir = $ac → $expected', () {
        expect(hasFinger(dc, ac, _settings().finger!), expected);
      });
    }
  });

  test('without a finger block there is no contact state and results always come', () {
    final oximetry = PpgOximetry(_settings().copyWith(finger: null));
    final seconds = _run(oximetry, List.filled(3, false));

    expect(seconds.map((s) => s.contact), everyElement(isNull));
    expect(seconds.last.values, isNotEmpty);
  });

  test('nothing on the sensor: no contact and no results', () {
    final seconds = _run(PpgOximetry(_settings()), List.filled(8, false));

    expect(seconds.map((s) => s.contact), everyElement(SensorContact.none));
    expect(seconds.map((s) => s.values), everyElement(isEmpty));
  });

  test('a finger settles for 5 s before results are given', () {
    final seconds = _run(PpgOximetry(_settings()), List.filled(12, true));
    final contacts = seconds.map((s) => s.contact).toList();
    final settling = contacts.where((c) => c == SensorContact.settling).length;
    final firstOk = contacts.indexOf(SensorContact.ok);

    // None while the DC filter rises, then settling, then results: never out of order.
    expect(contacts.takeWhile((c) => c == SensorContact.none).length, lessThanOrEqualTo(2));
    expect(settling, inInclusiveRange(4, 6)); // 500 pairs after the finger is first seen
    expect(contacts.skip(firstOk), everyElement(SensorContact.ok));
    for (final s in seconds.take(firstOk)) {
      expect(s.values, isEmpty);
    }
    expect(seconds.last.values.keys, containsAll(['spo2', 'heart_rate', 'pi_red', 'pi_ir']));
  });

  test('lifting the finger stops results and forgets the averages', () {
    final oximetry = PpgOximetry(_settings());
    _run(oximetry, List.filled(15, true)); // settled, heart rate found
    final lifted = _run(oximetry, List.filled(20, false));

    expect(lifted.last.contact, SensorContact.none);
    expect(lifted.last.values, isEmpty);

    // Back on: settling again, and no heart rate carried over from before.
    final again = _run(oximetry, List.filled(8, true));
    final contacts = again.map((s) => s.contact);
    expect(contacts.firstWhere((c) => c != SensorContact.none), SensorContact.settling);
    final firstValues = again.firstWhere((s) => s.values.isNotEmpty).values;
    expect(firstValues.containsKey('heart_rate'), isFalse);
  });

  group('lastCheck says which part of the finger rule failed', () {
    test('nothing on the sensor: light too low', () {
      final oximetry = PpgOximetry(_settings());
      _run(oximetry, List.filled(3, false));
      expect(oximetry.lastCheck, FingerCheck.lightTooLow);
    });

    test('bright but no pulse: pulse too small', () {
      final oximetry = PpgOximetry(_settings());
      for (var i = 0; i < 800; i++) {
        oximetry
          ..feed(Sample('ppg_red', 20000, _t))
          ..feed(Sample('ppg_ir', 26000, _t));
      }
      expect(oximetry.lastCheck, FingerCheck.pulseTooSmall);
    });

    test('a finger with a pulse: ok', () {
      final oximetry = PpgOximetry(_settings());
      _run(oximetry, List.filled(4, true));
      expect(oximetry.lastCheck, FingerCheck.ok);
    });

    test('no finger block: no check', () {
      final oximetry = PpgOximetry(_settings().copyWith(finger: null));
      _run(oximetry, List.filled(2, true));
      expect(oximetry.lastCheck, isNull);
    });
  });
}
