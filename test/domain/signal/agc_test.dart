import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/signal/agc.dart';

import '../../fixtures/ppg_motion_profile.dart';

/// Thresholds from the VitaCare profile: high 355200, low 222000, no contact 90000, hold 1.5 s,
/// cooldown 1.2 s, levels 0–32 from 5, 12-sample smoothing.
void main() {
  late Agc agc;
  final t0 = DateTime.utc(2026, 11, 3);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  setUp(() => agc = Agc(ppgMotionProfile().agc!));

  /// Feeds [value] every 10 ms from [fromMs] to [toMs] and returns the first change asked for.
  int? hold(double value, int fromMs, int toMs) {
    for (var ms = fromMs; ms <= toMs; ms += 10) {
      final level = agc.feed(value, at(ms));
      if (level != null) return level;
    }
    return null;
  }

  test('starts at level 5', () => expect(agc.level, 5));

  final cases = <String, (double, int?)>{
    'in range stays': (300000, null),
    'too bright for 1.5 s lowers': (400000, 4),
    'too dark for 1.5 s raises': (150000, 6),
    'no contact at the start level stays': (50000, null),
  };
  for (final MapEntry(key: name, value: (value, expected)) in cases.entries) {
    test(name, () => expect(hold(value, 0, 3000), expected));
  }

  test('waits the full hold time', () {
    expect(hold(400000, 0, 1490), isNull);
    expect(agc.feed(400000, at(1500)), 4);
  });

  test('a stretch back in range restarts the hold', () {
    expect(hold(400000, 0, 1000), isNull);
    expect(hold(300000, 1010, 1300), isNull);
    // Smoothing over 12 samples: the new stretch counts from when the average goes high again.
    expect(hold(400000, 1310, 2700), isNull);
    expect(hold(400000, 2710, 3000), 4);
  });

  test('waits the cooldown after a change', () {
    expect(hold(150000, 0, 2000), 6);
    agc.applied(6, at(1500));
    expect(hold(150000, 1510, 2690), isNull);
    expect(agc.feed(150000, at(2700)), 7);
  });

  test('with no contact, comes back down to the start level', () {
    agc.applied(8, at(0));
    expect(hold(50000, 1200, 1300), 7);
  });

  test('stays within the level limits', () {
    agc.applied(32, at(0));
    expect(hold(150000, 1200, 5000), isNull);
    agc.applied(0, at(0));
    expect(hold(400000, 1200, 5000), isNull);
  });

  test('smooths out a single spike', () {
    for (var ms = 0; ms < 3000; ms += 10) {
      final value = ms == 500 ? 1000000.0 : 300000.0;
      expect(agc.feed(value, at(ms)), isNull, reason: 'at $ms ms');
    }
  });
}
