import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/theme/app_tokens.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:generic_flutter_app/presentation/history/history_day_chart.dart';

import '../../fixtures/history_harness.dart';

const _ppg = UserDevice(id: 1, name: 'Test PPG', profileId: 'ppg_motion_v1');
const _band = UserDevice(id: 2, name: 'Test band', profileId: 'smart_band_v1');
const _patch = UserDevice(id: 3, name: 'Test patch', profileId: 'ief_device_v1');

final _allDay = List.generate(24, (h) => h);
DateTime _oct(int day) => DateTime(2026, 10, day);

/// The page's own (vertical) scrollable, not the device chips'.
final _page = find.byType(Scrollable).first;

/// The By day detail under the day picker: banner, reading cards, 24-hour bar. Now is
/// Mon 26 Oct 10:42; the window is 20–26 Oct.
void main() {
  Future<void> pickDay(WidgetTester tester, int day) async {
    await tester.tap(find.text('$day'));
    await tester.pumpAndSettle();
  }

  testWidgets('a complete past day', (tester) async {
    await pumpHistory(
      tester,
      devices: const [_ppg],
      readings: {
        1: {'heart_rate': slotsAt(_oct(20), _allDay)},
      },
    );
    await pickDay(tester, 20);

    expect(find.text('Complete day'), findsOneWidget);
    expect(find.text('All readings received for Tue 20 Oct.'), findsOneWidget);
  });

  testWidgets('today with every hour so far', (tester) async {
    await pumpHistory(
      tester,
      devices: const [_ppg],
      readings: {
        1: {'heart_rate': slotsAt(_oct(26), List.generate(11, (h) => h))},
      },
    );

    expect(find.text('Today so far'), findsOneWidget);
    expect(find.text('All readings received up to 10:42.'), findsOneWidget);
  });

  testWidgets('a day with a gap: banner, Min / Average / Max, chart and note (TC-1.4-005, 006)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpHistory(
      tester,
      devices: const [_ppg],
      readings: {
        1: {'heart_rate': slotsAt(_oct(21), _allDay.where((h) => h < 2 || h >= 6))},
      },
      figures: {
        1: {'heart_rate': (min: 60.0, avg: 80.0, max: 100.0)},
      },
    );
    await pickDay(tester, 21);

    expect(find.text('Partial data · 83% of the day'), findsOneWidget);
    expect(find.text('Missing 02:00–06:00 (device not connected).'), findsOneWidget);
    for (final text in ['Heart rate', 'bpm', 'Min', 'Average', 'Max', '60', '80', '100']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text('No data 02:00–06:00'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Heart rate through the day: hourly average 80 bpm to 80 bpm, no data 02:00–06:00',
      ),
      findsOneWidget,
    );
    // One chart, on the only reading with data that day.
    expect(find.byType(LineChart), findsOneWidget);
    // Drawn with a real size (an empty, zero-height graphic once slipped through).
    final size = tester.getSize(find.byType(LineChart));
    expect(size.height, 70);
    expect(size.width, greaterThan(300));
    // The PPG's other readings sent nothing that day.
    expect(find.text('No data received this day'), findsNWidgets(3));
    semantics.dispose();
  });

  for (final (brightness, alpha) in [
    (Brightness.light, HistoryDayChart.missingAlphaLight),
    (Brightness.dark, HistoryDayChart.missingAlphaDark),
  ]) {
    testWidgets('missing hours are shaded at ${alpha * 100}% in ${brightness.name} mode', (
      tester,
    ) async {
      await pumpHistory(
        tester,
        devices: const [_ppg],
        readings: {
          1: {'heart_rate': slotsAt(_oct(21), _allDay.where((h) => h < 2 || h >= 6))},
        },
        brightness: brightness,
      );
      await pickDay(tester, 21);

      final shading = tester.widget<HistoryChartShading>(find.byType(HistoryChartShading));
      expect(shading.gaps, [(2.0, 6.0)]);
      // Solid, so it looks the same over the normal range or not: the danger colour at [alpha]
      // laid once over the card.
      final theme = Theme.of(tester.element(find.byType(HistoryChartShading)));
      final tokens = theme.extension<AppTokens>()!;
      expect(shading.missingColour.a, 1);
      expect(
        shading.missingColour,
        Color.alphaBlend(tokens.danger.withValues(alpha: alpha), tokens.surface),
      );
    });
  }

  testWidgets('the normal band shows even when the day stays below it', (tester) async {
    await pumpHistory(
      tester,
      devices: const [_ppg],
      readings: {
        1: {
          'spo2': slotsAt(_oct(26), [9, 10]),
        },
      },
      figures: {
        1: {'spo2': (min: 67.0, avg: 89.0, max: 98.0)},
      },
    );

    final shading = tester.widget<HistoryChartShading>(find.byType(HistoryChartShading));
    expect(shading.normal, (95.0, 100.0)); // the profile's SpO₂ range
    expect(shading.low, lessThan(89)); // the line
    expect(shading.high, greaterThan(100)); // and the whole band
  });

  testWidgets('a day with no data: banner and empty cards, never zeros (TC-1.4-007)', (
    tester,
  ) async {
    await pumpHistory(tester, devices: const [_ppg]);
    await pickDay(tester, 22);

    expect(find.text('No data on Thu 22 Oct'), findsOneWidget);
    expect(find.text('No readings were received from Test PPG on this day.'), findsOneWidget);
    expect(find.text('No data received this day'), findsNWidgets(4));
    for (final label in ['SpO₂', 'Heart rate', 'PI (Red)', 'PI (IR)']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Min'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('cards follow the Live dashboard: SpO₂, Heart rate, PI (IR), PI (Red)', (
    tester,
  ) async {
    await pumpHistory(tester, devices: const [_ppg], size: const Size(390, 2400));

    final tops = [
      for (final label in ['SpO₂', 'Heart rate', 'PI (IR)', 'PI (Red)'])
        tester.getTopLeft(find.text(label)).dy,
    ];
    expect(tops, [...tops]..sort());
  });

  testWidgets('a reading with a goal shows the day\'s value against it', (tester) async {
    await pumpHistory(
      tester,
      devices: const [_band],
      readings: {
        2: {
          'steps': slotsAt(_oct(26), [8, 9, 10]),
        },
      },
      figures: {
        2: {'steps': (min: 120.0, avg: 3000.0, max: 6482.0)},
      },
    );
    await tester.scrollUntilVisible(find.text('Steps'), 300, scrollable: _page);

    expect(find.text('6,482'), findsOneWidget);
    expect(find.text('of 10,000 goal'), findsOneWidget);
    expect(find.text('Diastolic pressure'), findsNothing); // shown with blood pressure
  });

  testWidgets('readings worked out from events get no card', (tester) async {
    await pumpHistory(tester, devices: const [_patch]);

    expect(find.text('Current'), findsOneWidget);
    for (final label in ['Run time', 'Sessions', 'Errors']) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('a spinner with a label while the day loads', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHistory(tester, devices: const [_ppg], pending: true);

    expect(find.bySemanticsLabel('Loading this day'), findsOneWidget);
    semantics.dispose();
  });

  for (final (name, brightness, size, scale) in [
    ('dark mode', Brightness.dark, const Size(390, 844), 1.0),
    ('a small phone at double text size', Brightness.light, const Size(320, 568), 2.0),
  ]) {
    testWidgets('works in $name', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpHistory(
        tester,
        devices: const [_ppg, _band],
        readings: {
          1: {
            'heart_rate': slotsAt(_oct(26), [0, 1, 5, 9]),
          },
        },
        figures: {
          1: {'heart_rate': (min: 61.0, avg: 75.0, max: 99.0)},
        },
        brightness: brightness,
        size: size,
      );

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('PI (IR)'), 300, scrollable: _page);
      expect(tester.takeException(), isNull);
    });
  }
}
