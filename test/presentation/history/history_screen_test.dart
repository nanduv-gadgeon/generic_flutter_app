import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/history_harness.dart';

const _band = UserDevice(id: 1, name: 'Test band', profileId: 'test_device_v1');
const _sensor = UserDevice(id: 2, name: 'Test sensor', profileId: 'test_device_v1');

final _allDay = List.generate(24, (h) => h);

/// Test band: 20 Oct full, 21 Oct gap 02:00–06:00, 22 Oct nothing, the rest full, today partial.
final _bandSlots = {
  ...slotsAt(DateTime(2026, 10, 20), _allDay),
  ...slotsAt(DateTime(2026, 10, 21), _allDay.where((h) => h < 2 || h >= 6)),
  for (var d = 23; d <= 25; d++) ...slotsAt(DateTime(2026, 10, d), _allDay),
  ...slotsAt(DateTime(2026, 10, 26), [9, 10]),
};

/// Test sensor: only 22 Oct, all day.
final _sensorSlots = slotsAt(DateTime(2026, 10, 22), _allDay);

Finder _label(String text) => find.bySemanticsLabel(text);

void main() {
  testWidgets('with no devices asks for one (TC-1.4-009)', (tester) async {
    await pumpHistory(tester);

    expect(find.text('History'), findsOneWidget);
    expect(find.text('Add a device to see its history here.'), findsOneWidget);
    expect(find.text('By day'), findsNothing);
  });

  testWidgets('the subtitle shows the last 7 days up to today (TC-1.4-002)', (tester) async {
    await pumpHistory(tester, devices: const [_band]);

    expect(find.text('Last 7 days · 20–26 Oct'), findsOneWidget);
    for (final day in ['Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Today']) {
      expect(find.text(day), findsOneWidget);
    }
    for (var d = 20; d <= 26; d++) {
      expect(find.text('$d'), findsOneWidget);
    }
    expect(find.text('19'), findsNothing);
  });

  testWidgets('the dates come from the clock, across a month', (tester) async {
    await pumpHistory(tester, devices: const [_band], now: DateTime(2026, 11, 3, 8));

    expect(find.text('Last 7 days · 28 Oct – 3 Nov'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('the config sets how many days are shown', (tester) async {
    await pumpHistory(tester, devices: const [_band], daysOnPhone: 5);

    expect(find.text('Last 5 days · 22–26 Oct'), findsOneWidget);
    expect(find.text('5-day summary'), findsOneWidget);
    expect(find.text('21'), findsNothing);
  });

  testWidgets('each day says its status in words (TC-1.4-004, TC-1.4-010)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHistory(tester, devices: const [_band], slots: {1: _bandSlots});

    expect(_label('Tuesday, October 20, Complete'), findsOneWidget);
    expect(_label('Wednesday, October 21, Partial'), findsOneWidget);
    expect(_label('Thursday, October 22, No data'), findsOneWidget);
    expect(_label('Today, Monday, October 26, Partial'), findsOneWidget);
    for (final word in ['Complete', 'Partial', 'No data']) {
      expect(find.text(word), findsOneWidget); // the legend
    }
    semantics.dispose();
  });

  testWidgets('while the statuses load the days say so', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHistory(tester, devices: const [_band], pending: true);

    expect(_label('Today, Monday, October 26, checking data'), findsOneWidget);
    expect(_label('Tuesday, October 20, checking data'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the first device is picked; picking another updates the strip (TC-1.4-003)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repo = await pumpHistory(
      tester,
      devices: const [_band, _sensor],
      slots: {1: _bandSlots, 2: _sensorSlots},
    );
    expect(tester.getSemantics(_label('Test band')), isSemantics(isSelected: true));
    expect(tester.getSemantics(_label('Test sensor')), isSemantics(isSelected: false));

    await tester.tap(find.text('Test sensor'));
    await tester.pumpAndSettle();

    expect(tester.getSemantics(_label('Test sensor')), isSemantics(isSelected: true));
    expect(_label('Thursday, October 22, Complete'), findsOneWidget);
    expect(_label('Tuesday, October 20, No data'), findsOneWidget);
    verify(() => repo.dataSlots(2, DateTime(2026, 10, 20), DateTime(2026, 10, 27))).called(1);
    semantics.dispose();
  });

  testWidgets('today is picked first; tapping a day picks it', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHistory(tester, devices: const [_band], slots: {1: _bandSlots});
    final today = _label('Today, Monday, October 26, Partial');
    final thursday = _label('Thursday, October 22, No data');
    expect(tester.getSemantics(today), isSemantics(isSelected: true, isButton: true));

    await tester.tap(find.text('22'));
    await tester.pumpAndSettle();

    expect(tester.getSemantics(thursday), isSemantics(isSelected: true));
    expect(tester.getSemantics(today), isSemantics(isSelected: false));
    semantics.dispose();
  });

  testWidgets('7-day summary hides the day picker; By day brings it back', (tester) async {
    await pumpHistory(tester, devices: const [_band]);

    await tester.tap(find.text('7-day summary'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsNothing);
    expect(find.text('Complete'), findsNothing);

    await tester.tap(find.text('By day'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
  });

  group('at midnight', () {
    Future<StreamController<DateTime>> pumpWithClock(WidgetTester tester) async {
      final clock = StreamController<DateTime>();
      addTearDown(clock.close);
      clock.add(DateTime(2026, 10, 26, 23, 59));
      await pumpHistory(tester, devices: const [_band], clock: clock.stream);
      return clock;
    }

    testWidgets('the strip moves on and today stays picked', (tester) async {
      final semantics = tester.ensureSemantics();
      final clock = await pumpWithClock(tester);

      clock.add(DateTime(2026, 10, 27, 0, 0, 30));
      await tester.pumpAndSettle();

      expect(find.text('Last 7 days · 21–27 Oct'), findsOneWidget);
      expect(find.text('20'), findsNothing);
      final today = _label('Today, Tuesday, October 27, No data');
      expect(tester.getSemantics(today), isSemantics(isSelected: true));
      semantics.dispose();
    });

    testWidgets('a picked day that leaves the strip falls back to the oldest', (tester) async {
      final semantics = tester.ensureSemantics();
      final clock = await pumpWithClock(tester);
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      clock.add(DateTime(2026, 10, 27, 0, 0, 30));
      await tester.pumpAndSettle();

      final oldest = _label('Wednesday, October 21, No data');
      expect(tester.getSemantics(oldest), isSemantics(isSelected: true));
      semantics.dispose();
    });
  });

  testWidgets('works in dark mode', (tester) async {
    await pumpHistory(tester, devices: const [_band], brightness: Brightness.dark);

    expect(tester.takeException(), isNull);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('works on a small phone with double text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpHistory(
      tester,
      devices: const [_band, _sensor],
      slots: {1: _bandSlots},
      size: const Size(320, 568),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Today'), findsOneWidget);
  });
}
