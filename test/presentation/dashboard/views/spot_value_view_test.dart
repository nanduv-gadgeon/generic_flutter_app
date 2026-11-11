import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/parts/scale_bar.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/spot_value_view.dart';

import '../../../fixtures/dashboard_harness.dart';
import '../../../fixtures/dashboard_readings.dart';

void main() {
  final at = DateTime(2026, 11, 11, 8, 42);

  final cases = <double, String>{37.2: 'Normal', 37.9: 'High', 38.4: 'Fever'};
  for (final MapEntry(key: value, value: zone) in cases.entries) {
    testWidgets('$value °C: the $zone zone, in words', (tester) async {
      await pumpView(
        tester,
        SpotValueView(reading: tempReading, latest: Sample('temp', value, at)),
      );

      expect(find.text('LAST READING'), findsOneWidget);
      expect(find.text('$value'), findsOneWidget);
      expect(find.text(zone), findsOneWidget);
      expect(find.text('Measured today at 08:42'), findsOneWidget);
      expect(find.bySemanticsLabel('Temperature, $value °C, $zone'), findsOneWidget);
    });
  }

  testWidgets('the zone bar: three joined zones, the marker on the value, zone labels', (
    tester,
  ) async {
    await pumpView(tester, SpotValueView(reading: tempReading, latest: Sample('temp', 37.9, at)));

    final bar = tester.widget<ScaleBar>(find.byType(ScaleBar));
    expect(bar.joined, isTrue);
    expect(bar.bands.map((b) => (b.start, b.end)), [(0.0, 0.5), (0.5, 0.6), (0.6, 1.0)]);
    expect(bar.marker, closeTo(0.58, 1e-9));
    for (final label in ['Normal < 37.5', 'High 37.5–38.0', 'Fever ≥ 38.0']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('nothing measured today yet', (tester) async {
    await pumpView(tester, const SpotValueView(reading: tempReading, latest: null));

    expect(find.text('–'), findsOneWidget);
    expect(find.text('No reading yet'), findsOneWidget);
    expect(tester.widget<ScaleBar>(find.byType(ScaleBar)).marker, isNull);
  });
}
