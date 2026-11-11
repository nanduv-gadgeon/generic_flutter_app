import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/parts/arc_gauge.dart';

import '../../../../fixtures/dashboard_harness.dart';

void main() {
  final cases = <String, (double?, (double, double)?)>{
    'a value and a band': (0.5, (0.25, 0.75)),
    'no value yet': (null, (0.25, 0.75)),
    'no band': (0.3, null),
    'values past the ends are clamped': (1.7, (-0.2, 1.4)),
  };
  for (final MapEntry(key: name, value: (value, band)) in cases.entries) {
    testWidgets('draws $name around its middle', (tester) async {
      await pumpView(
        tester,
        ArcGauge(
          trackColor: Colors.grey,
          valueColor: Colors.teal,
          bandColor: Colors.green,
          value: value,
          band: band,
          child: const Text('72'),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ArcGauge)), const Size.square(132));
      expect(tester.getCenter(find.text('72')), tester.getCenter(find.byType(ArcGauge)));
    });
  }
}
