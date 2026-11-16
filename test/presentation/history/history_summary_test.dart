import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/theme/app_tokens.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';

import '../../fixtures/history_harness.dart';

const _band = UserDevice(id: 2, name: 'Test band', profileId: 'smart_band_v1');
const _sensor = UserDevice(id: 4, name: 'Test sensor', profileId: 'env_sensor_v1');

final _allDay = List.generate(24, (h) => h);
DateTime _oct(int day) => DateTime(2026, 10, day);

/// Made-up figures with the same average every day it is given.
Figures _avg(double avg) => (min: avg - 5, avg: avg, max: avg + 5);

/// Screen 24's heart rate: daily averages 74, 71, none, 73, 70 (a gap that day), 72, 72 (today,
/// every hour so far). Now is Mon 26 Oct 10:42.
Map<int, Map<String, Set<DateTime>>> _screen24Readings() => {
  2: {
    'hr': {
      for (final day in [20, 21, 23, 25]) ...slotsAt(_oct(day), _allDay),
      ...slotsAt(_oct(24), _allDay.where((h) => h < 2 || h >= 6)),
      ...slotsAt(_oct(26), List.generate(11, (h) => h)),
    },
    'steps': slotsAt(_oct(25), [20]),
  },
};

final _screen24Figures = {
  2: {
    'hr': {
      _oct(20): _avg(74),
      _oct(21): _avg(71),
      _oct(23): _avg(73),
      _oct(24): _avg(70),
      _oct(25): _avg(72),
      _oct(26): _avg(72),
    },
    'steps': {_oct(25): (min: 0.0, avg: 3000.0, max: 8210.0)},
  },
};

/// The 7-day summary tab of History (requirement 6.5, mockup 24).
void main() {
  Future<void> openSummary(WidgetTester tester) async {
    await tester.tap(find.text('7-day summary'));
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen24(WidgetTester tester, {Brightness brightness = Brightness.light}) =>
      pumpHistory(
        tester,
        devices: const [_band],
        readings: _screen24Readings(),
        dayFigures: _screen24Figures,
        brightness: brightness,
      );

  testWidgets('screen 24: chart, Min / Average / Max and the day list', (tester) async {
    await pumpScreen24(tester);
    await openSummary(tester);

    expect(find.text('Heart rate · daily average'), findsOneWidget);
    expect(find.text('bpm avg'), findsOneWidget);
    for (final day in ['Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Today']) {
      expect(find.text(day), findsOneWidget, reason: day);
    }
    for (final label in ['Min', 'Average', 'Max']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // The bar label, the Max tile and Tuesday's row.
    expect(find.text('74'), findsNWidgets(2));
    expect(find.text('74 bpm'), findsOneWidget);
    expect(find.text('No data'), findsNWidgets(2)); // the bar and the row
    expect(find.text('Missing'), findsOneWidget);
    expect(find.text('Partial'), findsOneWidget); // Sat 24 Oct has a gap
    expect(find.text('Normal'), findsNWidgets(5));
    expect(find.text('Today · Mon 26 Oct'), findsOneWidget);
    expect(find.text('Thu 22 Oct'), findsOneWidget);
  });

  testWidgets('the day list is newest first', (tester) async {
    await pumpScreen24(tester);
    await openSummary(tester);

    final today = tester.getTopLeft(find.text('Today · Mon 26 Oct')).dy;
    final tuesday = tester.getTopLeft(find.text('Tue 20 Oct')).dy;
    expect(today, lessThan(tuesday));
  });

  testWidgets("today's bar is in the primary colour, the others in the soft one", (tester) async {
    await pumpScreen24(tester);
    await openSummary(tester);

    final context = tester.element(find.text('Today').first);
    final primary = Theme.of(context).colorScheme.primary;
    final soft = Theme.of(context).extension<AppTokens>()!.barSoft;
    Iterable<Color?> colours() => tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => (c.decoration as BoxDecoration?)?.color);

    expect(colours().where((c) => c == primary), hasLength(1));
    expect(colours().where((c) => c == soft), hasLength(5));
  });

  testWidgets('screen readers hear every day with its value and status', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpScreen24(tester);
    await openSummary(tester);

    for (final label in [
      'Heart rate · daily average, last 7 days',
      'Tuesday, October 20, 74 bpm, Normal',
      'Saturday, October 24, 70 bpm, Partial',
      'Today, Monday, October 26, 72 bpm, Normal',
    ]) {
      expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
    }
    // The bar and the row.
    expect(find.bySemanticsLabel('Thursday, October 22, No data'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Reading'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a chip picks another reading: steps show their daily total', (tester) async {
    await pumpScreen24(tester);
    await openSummary(tester);

    await tester.ensureVisible(find.text('Steps'));
    await tester.tap(find.text('Steps'));
    await tester.pumpAndSettle();

    expect(find.text('Steps · daily total'), findsOneWidget);
    expect(find.text('steps avg'), findsOneWidget);
    expect(find.text('8,210 steps'), findsOneWidget);
    expect(find.text('Missing'), findsNWidgets(6));
  });

  testWidgets('a day out of the normal range says High', (tester) async {
    await pumpHistory(
      tester,
      devices: const [_band],
      readings: {
        2: {'hr': slotsAt(_oct(25), _allDay)},
      },
      figures: {
        2: {'hr': _avg(115)},
      },
    );
    await openSummary(tester);

    expect(find.text('High'), findsOneWidget);
    final context = tester.element(find.text('High'));
    final warn = Theme.of(context).extension<AppTokens>()!.warn;
    expect(tester.widget<Text>(find.text('High')).style?.color, warn);
  });

  testWidgets('another device falls back to its first reading', (tester) async {
    await pumpHistory(
      tester,
      devices: const [_band, _sensor],
      readings: {
        2: {
          'steps': slotsAt(_oct(25), [8]),
        },
        4: {
          'temp': slotsAt(_oct(25), [8]),
        },
      },
    );
    await openSummary(tester);
    await tester.ensureVisible(find.text('Steps'));
    await tester.tap(find.text('Steps'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test sensor'));
    await tester.pumpAndSettle();

    expect(find.text('Temperature · daily average'), findsOneWidget);
  });

  testWidgets('no readings in the last 7 days', (tester) async {
    await pumpHistory(tester, devices: const [_band]);
    await openSummary(tester);

    expect(find.text('No readings in the last 7 days'), findsOneWidget);
    expect(find.text('Heart rate'), findsOneWidget); // the chips stay, to pick another
  });

  testWidgets('a spinner with a label while the summaries load', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHistory(tester, devices: const [_band], pending: true);
    await tester.tap(find.text('7-day summary'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading the summary'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('fits a small phone at twice the text size, in dark mode', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpHistory(
      tester,
      devices: const [_band],
      readings: _screen24Readings(),
      dayFigures: _screen24Figures,
      brightness: Brightness.dark,
      size: const Size(320, 568),
    );
    await openSummary(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Heart rate · daily average'), findsOneWidget);
  });
}
