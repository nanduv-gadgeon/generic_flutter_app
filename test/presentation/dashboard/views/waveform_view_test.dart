import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/theme/app_tokens.dart';
import 'package:generic_flutter_app/domain/models/reading.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/parts/trace_chart.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/waveform_view.dart';

import '../../../fixtures/dashboard_harness.dart';
import '../../../fixtures/dashboard_readings.dart';

const _signal = Reading(
  key: 'signal',
  label: 'Signal',
  unit: '',
  icon: ReadingIcon.ecg,
  states: {'2': ReadingState(label: 'Signal good', kind: StatusKind.ok)},
);

void main() {
  testWidgets('title, status, trace on grid paper, axis and stats', (tester) async {
    await pumpView(
      tester,
      const WaveformView(
        title: 'Live ECG · Lead I · 250 Hz',
        samples: [0, 1, 0],
        capacity: 1500,
        seconds: 6,
        scaleLabel: '25 mm/s · 10 mm/mV',
        status: (_signal, 2),
        stats: [(hrReading, 76), (rhythmReading, 1)],
      ),
    );

    for (final text in [
      'Live ECG · Lead I · 250 Hz',
      'Signal good',
      '−6 s',
      '25 mm/s · 10 mm/mV',
      'now',
      'Heart rate',
      '76 bpm',
      'Rhythm',
      'Sinus rhythm',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    final chart = tester.widget<TraceChart>(find.byType(TraceChart));
    expect((chart.slots, chart.grid != null), (1500, true));
    final tokens = Theme.of(tester.element(find.text('Rhythm'))).extension<AppTokens>()!;
    expect(tester.widget<Text>(find.text('Sinus rhythm')).style!.color, tokens.ok);
    expect(find.bySemanticsLabel('Live ECG · Lead I · 250 Hz, live waveform'), findsOneWidget);
    expect(find.bySemanticsLabel('Rhythm, Sinus rhythm'), findsOneWidget);
  });

  testWidgets('before any data: an empty trace and "–" stats', (tester) async {
    await pumpView(
      tester,
      const WaveformView(
        title: 'Live ECG',
        samples: [],
        capacity: 1500,
        seconds: 6,
        stats: [(hrReading, null)],
      ),
    );

    expect(find.text('–'), findsOneWidget);
    expect(find.text('25 mm/s · 10 mm/mV'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
