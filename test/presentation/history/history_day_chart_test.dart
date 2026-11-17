import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/theme/app_tokens.dart';
import 'package:generic_flutter_app/domain/history/day_detail.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:generic_flutter_app/presentation/history/history_day_chart.dart';
import 'package:generic_flutter_app/presentation/history/history_day_plot.dart';

import '../../fixtures/history_harness.dart';

const _ppg = UserDevice(id: 1, name: 'Test PPG', profileId: 'ppg_motion_v1');

final _allDay = List.generate(24, (h) => h);
DateTime _oct(int day) => DateTime(2026, 10, day);

/// The chart through the day on a By day reading card: hourly ranges and averages, the strip of
/// missing hours, the normal band and labels, and tapping an hour. Now is Mon 26 Oct 10:42.
void main() {
  Future<void> pickDay(WidgetTester tester, int day) async {
    await tester.tap(find.text('$day'));
    await tester.pumpAndSettle();
  }

  HistoryDayPlot plotOf(WidgetTester tester, [int index = 0]) =>
      tester.widgetList<CustomPaint>(find.byKey(HistoryDayChart.plotKey)).elementAt(index).painter!
          as HistoryDayPlot;

  for (final brightness in Brightness.values) {
    testWidgets('missing hours are marked in the strip under the plot (${brightness.name} mode)', (
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

      final plot = plotOf(tester);
      expect(
        [
          for (final (h, c) in plot.coverage)
            if (c == HourCoverage.missing) h,
        ],
        [2, 3, 4, 5],
      );
      expect(plot.coverage.where((c) => c.$2 == HourCoverage.data).length, 20);
      final tokens = Theme.of(tester.element(find.byKey(HistoryDayChart.plotKey)))
          .extension<AppTokens>()!;
      expect(plot.colours.stripMissing.withValues(alpha: 1), tokens.danger);
      expect(plot.colours.stripData, tokens.accent);
    });
  }

  testWidgets('hours of today not begun are neither data nor missing', (tester) async {
    await pumpHistory(
      tester,
      devices: const [_ppg],
      readings: {
        1: {
          'heart_rate': slotsAt(_oct(26), [9]),
        },
      },
    );

    final coverage = plotOf(tester).coverage;
    expect(coverage[9], (9, HourCoverage.data));
    expect(coverage[10], (10, HourCoverage.missing)); // begun at 10:00, now 10:42
    expect(coverage[11], (11, HourCoverage.notYet));
  });

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

    final plot = plotOf(tester);
    expect(plot.normal, (95.0, 100.0)); // the profile's SpO₂ range
    expect(plot.low, lessThan(67)); // each hour's lowest value
    expect(plot.high, greaterThan(100)); // and the whole band
    // Labelled at its limits, highest first.
    expect(plot.labels, [(100.0, '100'), (95.0, '95')]);
  });

  testWidgets('hours far apart, as from a real device, are each drawn with their range', (
    tester,
  ) async {
    await pumpHistory(
      tester,
      devices: const [_ppg],
      readings: {
        1: {
          'heart_rate': slotsAt(_oct(21), [3, 9, 14, 21]),
        },
      },
      figures: {
        1: {'heart_rate': (min: 62.0, avg: 75.0, max: 91.0)},
      },
    );
    await pickDay(tester, 21);

    final plot = plotOf(tester);
    expect(plot.hours.keys, unorderedEquals([3, 9, 14, 21]));
    expect(plot.hours[14], (min: 62.0, avg: 75.0, max: 91.0, count: 4));
  });

  testWidgets('tapping the chart writes out the nearest hour with data; again clears it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpHistory(
      tester,
      devices: const [_ppg],
      readings: {
        1: {
          'spo2': slotsAt(_oct(26), [2, 9]),
        },
      },
      figures: {
        1: {'spo2': (min: 67.0, avg: 89.0, max: 98.0)},
      },
    );
    final chart = find.byKey(HistoryDayChart.plotKey);
    final box = tester.getRect(chart);
    final gutter = plotOf(tester).gutter;
    // Over 10:00, which has no data: 09:00 is the nearest hour that has.
    final at = Offset(box.left + gutter + (box.width - gutter) * 10.2 / 24, box.center.dy);

    await tester.tapAt(at);
    await tester.pump();

    const detail = '09:00–10:00 · avg 89 % · 67–98 · 4 readings · Below normal';
    expect(find.text(detail), findsOneWidget);
    expect(plotOf(tester).picked, 9);
    expect(find.bySemanticsLabel(detail), findsOneWidget);

    await tester.tapAt(at);
    await tester.pump();

    expect(find.text(detail), findsNothing);
    expect(find.text('Tap the chart to see an hour'), findsOneWidget);
    expect(plotOf(tester).picked, isNull);
    semantics.dispose();
  });

  testWidgets('an hour whose readings were all the same is written without a range', (
    tester,
  ) async {
    await pumpHistory(
      tester,
      devices: const [_ppg],
      readings: {
        1: {
          'spo2': {DateTime(2026, 10, 26, 9, 5)},
        },
      },
      figures: {
        1: {'spo2': (min: 97.0, avg: 97.0, max: 97.0)},
      },
    );
    await tester.tap(find.byKey(HistoryDayChart.plotKey));
    await tester.pump();

    expect(find.text('09:00–10:00 · 97 % · 1 reading'), findsOneWidget);
  });

  /// Taps the chart over the hour starting at [hour] and returns the painter afterwards.
  Future<HistoryDayPlot> tapHour(WidgetTester tester, int hour) async {
    final box = tester.getRect(find.byKey(HistoryDayChart.plotKey));
    final gutter = plotOf(tester).gutter;
    await tester.tapAt(
      Offset(box.left + gutter + (box.width - gutter) * (hour + 0.5) / 24, box.center.dy),
    );
    await tester.pump();
    return plotOf(tester);
  }

  testWidgets('an average that shows as inside the normal range is drawn and written as inside', (
    tester,
  ) async {
    // 94.75 shows as 95 %, inside SpO₂'s 95–100: a filled dot, and no "Below normal".
    await pumpHistory(
      tester,
      devices: const [_ppg],
      readings: {
        1: {
          'spo2': slotsAt(_oct(26), [9]),
        },
      },
      figures: {
        1: {'spo2': (min: 93.0, avg: 94.75, max: 97.0)},
      },
    );

    final plot = await tapHour(tester, 9);

    expect(plot.outside, isEmpty);
    expect(find.text('09:00–10:00 · avg 95 % · 93–97 · 4 readings'), findsOneWidget);
  });

  testWidgets('an average below the normal range is a ring and says Below normal', (tester) async {
    await pumpHistory(
      tester,
      devices: const [_ppg],
      readings: {
        1: {
          'spo2': slotsAt(_oct(26), [9, 10]),
        },
      },
      dayFigures: {
        1: {
          'spo2': {_oct(26): (min: 68.0, avg: 92.0, max: 99.0)},
        },
      },
    );

    final plot = await tapHour(tester, 9);

    expect(plot.outside, {9, 10});
    expect(find.text('09:00–10:00 · avg 92 % · 68–99 · 4 readings · Below normal'), findsOneWidget);
    // Lighter than the light theme's amber, so it is not taken for the red of the missing hours.
    final tokens = Theme.of(tester.element(find.byKey(HistoryDayChart.plotKey)))
        .extension<AppTokens>()!;
    expect(
      HSLColor.fromColor(plot.colours.outside).lightness,
      greaterThan(HSLColor.fromColor(tokens.warn).lightness),
    );
  });
}
