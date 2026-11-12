import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/reading.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/parts/scale_bar.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/reading_tile.dart';

import '../../../fixtures/dashboard_harness.dart';
import '../../../fixtures/dashboard_readings.dart';

void main() {
  // (reading, value, pair, live) → (texts shown, spoken label, has a bar, has a marker)
  final cases = <String, ((Reading, double?, double?, bool), (List<String>, String, bool, bool))>{
    'in range: range bar, marker, Normal': (
      (hrReading, 72, null, true),
      (['72', 'bpm', 'Normal 60–100', 'Normal'], 'Heart rate, 72 bpm, Normal', true, true),
    ),
    'above range: High': (
      (hrReading, 120, null, true),
      (['120', 'High'], 'Heart rate, 120 bpm, High', true, true),
    ),
    'below range: Low': (
      (hrReading, 50, null, true),
      (['50', 'Low'], 'Heart rate, 50 bpm, Low', true, true),
    ),
    'a pair: "a/b"': (
      (bpReading, 118, 76, true),
      (['118/76', 'mmHg'], 'Blood pressure, 118/76 mmHg, Normal', true, true),
    ),
    'a goal: progress and percent': (
      (stepsReading, 6482, null, true),
      (['6,482', 'today', '65% of goal'], 'Steps, 6,482 today', true, false),
    ),
    'hours and minutes': (
      (sleepReading, 7.2, null, true),
      (['7h 12m', '90% of goal'], 'Sleep, 7h 12m last night', true, false),
    ),
    'from events: Today, no bar': (
      (sessionsReading, 3, null, true),
      (['3', 'Today'], 'Sessions, 3', false, false),
    ),
    'no value while live: No signal': (
      (hrReading, null, null, true),
      (['–', 'No signal'], 'Heart rate, no reading yet, No signal', false, false),
    ),
    'no value, not live: just "–"': (
      (hrReading, null, null, false),
      (['–'], 'Heart rate, no reading yet', false, false),
    ),
  };
  for (final MapEntry(
        key: name,
        value: ((reading, value, pair, live), (texts, spoken, bar, marker)),
      )
      in cases.entries) {
    testWidgets(name, (tester) async {
      await pumpView(
        tester,
        SizedBox(
          width: 175,
          child: ReadingTile(reading: reading, value: value, pairValue: pair, live: live),
        ),
      );

      for (final text in texts) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.bySemanticsLabel(spoken), findsOneWidget);
      expect(find.byType(ScaleBar), bar ? findsOneWidget : findsNothing);
      if (bar) expect(tester.widget<ScaleBar>(find.byType(ScaleBar)).marker != null, marker);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a long label is cut off, not wrapped', (tester) async {
    await pumpView(
      tester,
      SizedBox(
        width: 175,
        child: ReadingTile(
          reading: hrReading.copyWith(label: 'CH14 Pump non-drive end bearing'),
          value: 1.8,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
