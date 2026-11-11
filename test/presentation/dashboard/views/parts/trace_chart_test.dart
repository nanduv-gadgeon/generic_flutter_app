import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/parts/trace_chart.dart';

import '../../../../fixtures/dashboard_harness.dart';

void main() {
  final cases = <String, TraceChart>{
    'a sparkline with an area': const TraceChart(
      lines: [
        [1, 3, 2],
      ],
      colors: [Colors.teal],
      area: Colors.black12,
    ),
    'a waveform on grid paper, filling from the right': const TraceChart(
      lines: [
        [0, 1, 0, -1],
      ],
      colors: [Colors.red],
      height: 120,
      slots: 1500,
      grid: (paper: Colors.white, line: Colors.pink, cell: 15),
    ),
    'nothing yet': const TraceChart(lines: [[]], colors: [Colors.teal]),
    'a flat line': const TraceChart(
      lines: [
        [5, 5, 5],
      ],
      colors: [Colors.teal],
    ),
    'several lines': const TraceChart(
      lines: [
        [1, 2],
        [3, 4],
      ],
      colors: [Colors.red, Colors.green],
    ),
  };
  for (final MapEntry(key: name, value: chart) in cases.entries) {
    testWidgets('draws $name at its height', (tester) async {
      await pumpView(tester, chart);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TraceChart)).height, chart.height);
    });
  }
}
