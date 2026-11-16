import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/history/history_days.dart';
import 'package:generic_flutter_app/domain/history/summary_chart.dart';
import 'package:generic_flutter_app/domain/models/reading.dart';
import 'package:generic_flutter_app/presentation/strings/history_strings.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../fixtures/l10n.dart';

const _hr = Reading(key: 'hr', label: 'Heart rate', unit: 'bpm', icon: ReadingIcon.pulse);
const _steps = Reading(
  key: 'steps',
  label: 'Steps',
  unit: 'today',
  historyUnit: 'steps',
  icon: ReadingIcon.trend,
  goal: 10000,
);
const _sleep = Reading(
  key: 'sleep',
  label: 'Sleep',
  unit: 'last night',
  icon: ReadingIcon.moon,
  decimals: 1,
  goal: 8,
  format: ReadingFormat.hoursMinutes,
);
const _pi = Reading(key: 'pi', label: 'PI (IR)', unit: '', icon: ReadingIcon.trend, decimals: 3);

/// The 7-day summary's text: titles, units, values, statuses and screen reader labels.
void main() {
  // Widget tests get dates in English from the app's localizations; plain tests load them here.
  setUpAll(() => initializeDateFormatting('en'));

  test('Reading.historyUnit is read from the config and optional', () {
    final json = {'key': 'steps', 'label': 'Steps', 'unit': 'today', 'icon': 'trend'};
    expect(Reading.fromJson({...json, 'historyUnit': 'steps'}).historyUnit, 'steps');
    expect(Reading.fromJson(json).historyUnit, isNull);
  });

  // reading: (title for its daily value, unit, "avg" suffix, a value written out)
  final cases = <String, (Reading, String, String, String, double, String)>{
    'an average with a unit': (_hr, 'Heart rate · daily average', 'bpm', 'bpm avg', 72, '72 bpm'),
    'a total in its history unit': (
      _steps,
      'Steps · daily total',
      'steps',
      'steps avg',
      8210,
      '8,210 steps',
    ),
    'hours and minutes carry their own unit': (
      _sleep,
      'Sleep · daily total',
      '',
      'avg',
      7.2,
      '7h 12m',
    ),
    'no unit': (_pi, 'PI (IR) · daily average', '', 'avg', 0.222, '0.222'),
  };
  for (final MapEntry(key: name, value: (reading, title, unit, suffix, value, text))
      in cases.entries) {
    test(name, () {
      expect(en.historySummaryTitle(reading, dailyValueOf(reading)), title);
      expect(en.historyUnitOf(reading), unit);
      expect(en.historyAvgSuffix(reading), suffix);
      expect(en.historyValueText(reading, value), text);
    });
  }

  test('row statuses in words', () {
    expect(SummaryRowStatus.values.map(en.historyRowStatus), [
      'Missing',
      'High',
      'Low',
      'Partial',
      'Normal',
    ]);
  });

  group('screen reader labels', () {
    final day = HistoryDay(DateTime(2026, 10, 20));
    test('a day with a value', () {
      final d = SummaryDay(day: day, value: 74, status: DayStatus.complete);
      expect(en.historySummaryDayLabel(_hr, d), 'Tuesday, October 20, 74 bpm, Normal');
    });
    test('today', () {
      final d = SummaryDay(day: day, value: 74, status: DayStatus.partial, isToday: true);
      expect(en.historySummaryDayLabel(_hr, d), 'Today, Tuesday, October 20, 74 bpm, Partial');
    });
    test('a day without data', () {
      final d = SummaryDay(day: day, status: DayStatus.noData);
      expect(en.historySummaryDayLabel(_hr, d), 'Tuesday, October 20, No data');
    });
    test('the chart', () {
      expect(
        en.historySummaryChartSpoken('Heart rate · daily average', 7),
        'Heart rate · daily average, last 7 days',
      );
      expect(
        en.historySummaryChartSpoken('Heart rate · daily average', 1),
        'Heart rate · daily average, today',
      );
    });
  });
}
