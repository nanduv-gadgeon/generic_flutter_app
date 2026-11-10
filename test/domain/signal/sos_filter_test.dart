import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/signal/sos_filter.dart';

import '../../fixtures/ppg_motion_profile.dart';

void main() {
  final ppg = ppgMotionProfile().signal!.ppgOximetry!;

  List<double> impulse(List<List<double>> sections, int n) {
    final filter = SosFilter(sections);
    return [for (var i = 0; i < n; i++) filter.filter(i == 0 ? 1 : 0)];
  }

  // Expected values from an independent port of the INOS Direct Form II filter.
  test('band-pass impulse response', () {
    final expected = [3.12389769e-05, 2.363924103942804e-4, 8.803376585130425e-4];
    for (final (i, v) in impulse(ppg.bandPass, 3).indexed) {
      expect(v, closeTo(expected[i], 1e-15));
    }
  });

  test('low-pass impulse response', () {
    final expected = [2.46193005e-06, 9.836782130219457e-06, 1.9640774422693895e-05];
    for (final (i, v) in impulse(ppg.lowPass, 3).indexed) {
      expect(v, closeTo(expected[i], 1e-18));
    }
  });

  test('the low-pass keeps a steady level and the band-pass removes it', () {
    final low = SosFilter(ppg.lowPass);
    final band = SosFilter(ppg.bandPass);
    double lowOut = 0;
    double bandOut = 0;
    for (var i = 0; i < 20000; i++) {
      lowOut = low.filter(1000);
      bandOut = band.filter(1000);
    }
    expect(lowOut, closeTo(999.5655897, 1e-4)); // DC gain 0.99957
    expect(bandOut, closeTo(0, 1e-3));
  });

  test('normalises sections whose a0 is not 1', () {
    final scaled = SosFilter([
      [2, 4, 2, 2, -0.5, 0.25],
    ]);
    final plain = SosFilter([
      [1, 2, 1, 1, -0.25, 0.125],
    ]);
    for (final x in [1.0, 0.0, -3.0, 5.0]) {
      expect(scaled.filter(x), closeTo(plain.filter(x), 1e-12));
    }
  });
}
