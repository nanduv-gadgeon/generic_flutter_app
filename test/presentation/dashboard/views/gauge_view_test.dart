import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/theme/app_tokens.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/gauge_view.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/parts/arc_gauge.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/parts/trace_chart.dart';

import '../../../fixtures/dashboard_harness.dart';
import '../../../fixtures/dashboard_readings.dart';

final _now = DateTime.utc(2026, 11, 11, 9);

void main() {
  final trend = [
    for (final (i, v) in <double>[68, 74, 72].indexed)
      Sample('hr', v, _now.subtract(Duration(seconds: 2 + (2 - i) * 60))),
  ];

  testWidgets('value on the arc, status, normal range with unit, trend and its age', (
    tester,
  ) async {
    await pumpView(tester, GaugeView(reading: hrReading, value: 100, trend: trend, now: _now));

    for (final text in ['100', 'bpm', 'Heart rate', 'Normal', 'Normal 60–100 bpm']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text('Last 30 min · updated 2 s ago'), findsOneWidget);
    final arc = tester.widget<ArcGauge>(find.byType(ArcGauge));
    expect(arc.value, 0.5); // 100 on 40–160
    expect(arc.band, (1 / 6, 0.5)); // 60–100
    expect(tester.widget<TraceChart>(find.byType(TraceChart)).lines.single, [68, 74, 72]);
    expect(find.bySemanticsLabel('Heart rate, 100 bpm, Normal'), findsOneWidget);
  });

  testWidgets('out of range: High, and the arc turns to the warning colour', (tester) async {
    await pumpView(tester, GaugeView(reading: hrReading, value: 130, trend: const [], now: _now));

    expect(find.text('High'), findsOneWidget);
    final tokens = Theme.of(tester.element(find.text('High'))).extension<AppTokens>()!;
    expect(tester.widget<ArcGauge>(find.byType(ArcGauge)).valueColor, tokens.warn);
    expect(find.text('Last 30 min · no readings yet'), findsOneWidget);
  });

  testWidgets('a goal fills the arc by progress, with no band', (tester) async {
    await pumpView(
      tester,
      GaugeView(reading: stepsReading, value: 15000, trend: const [], now: _now),
    );

    final arc = tester.widget<ArcGauge>(find.byType(ArcGauge));
    expect((arc.value, arc.band), (1.0, null));
    expect(find.text('150% of goal'), findsOneWidget);
  });

  testWidgets('no value yet', (tester) async {
    await pumpView(tester, GaugeView(reading: hrReading, value: null, trend: const [], now: _now));

    expect(find.text('–'), findsOneWidget);
    expect(tester.widget<ArcGauge>(find.byType(ArcGauge)).value, isNull);
    expect(find.bySemanticsLabel(RegExp('no reading yet')), findsOneWidget);
  });

  testWidgets('a pair fits in the arc', (tester) async {
    await pumpView(
      tester,
      GaugeView(reading: bpReading, value: 126, pairValue: 82, trend: const [], now: _now),
    );
    expect(find.text('126/82'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
