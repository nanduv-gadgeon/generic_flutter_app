import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/history/day_summary.dart';
import 'package:generic_flutter_app/domain/history/history_days.dart';
import 'package:generic_flutter_app/domain/history/summary_chart.dart';
import 'package:generic_flutter_app/domain/models/reading.dart';

const _hr = Reading(
  key: 'hr',
  label: 'Heart rate',
  unit: 'bpm',
  icon: ReadingIcon.pulse,
  normal: NormalRange(low: 60, high: 100),
);
const _steps = Reading(
  key: 'steps',
  label: 'Steps',
  unit: 'today',
  historyUnit: 'steps',
  icon: ReadingIcon.trend,
  goal: 10000,
);
const _plain = Reading(key: 'press', label: 'Pressure', unit: 'hPa', icon: ReadingIcon.gauge);

/// Every hour of the day.
const _allDay = 0xFFFFFF;

/// The 7-day summary of one reading, from made-up daily summaries. Now is Mon 26 Oct 2026 10:42;
/// the days are 20–26 Oct.
void main() {
  final now = DateTime(2026, 10, 26, 10, 42);
  final days = historyDays(now, 7);

  /// Summaries of [reading] for 20–26 Oct: (avg, max, hour mask) per day, null for no data.
  Map<DateTime, Map<String, DaySummary>> summaries(
    Reading reading,
    List<(double, double, int)?> perDay,
  ) => {
    for (final (i, figures) in perDay.indexed)
      if (figures case (final avg, final max, final hours))
        days[i].start: {
          reading.key: DaySummary(
            deviceId: 1,
            key: reading.key,
            day: days[i].start,
            min: avg - 5,
            avg: avg,
            max: max,
            count: 10,
            hours: hours,
          ),
        },
  };

  /// Today's hours so far (00:00–10:59) with data.
  const todaySoFar = (1 << 11) - 1;

  group('the days and their values', () {
    test('averages of screen 24: Min 70, Average 72, Max 74; Thursday has no data', () {
      final perDay = [74.0, 71.0, null, 73.0, 70.0, 72.0, 72.0];
      final chart = summaryChart(
        _hr,
        days,
        summaries(_hr, [
          for (final (i, v) in perDay.indexed)
            if (v == null) null else (v, v + 10, i == 6 ? todaySoFar : _allDay),
        ]),
        now,
      );

      expect(chart.dailyValue, DailyValue.average);
      expect([for (final d in chart.days) d.value], perDay);
      expect((chart.min, chart.avg, chart.max), (70, 72, 74));
      expect(chart.hasData, isTrue);
      expect([for (final d in chart.days) d.isToday], [...List.filled(6, false), true]);
      expect(chart.days[2].status, DayStatus.noData);
    });

    test('a reading with a goal shows the day total (its highest value), never flagged', () {
      final chart = summaryChart(
        _steps,
        days,
        summaries(_steps, [(3000, 8210, _allDay), (4000, 25000, _allDay), ...List.filled(5, null)]),
        now,
      );

      expect(chart.dailyValue, DailyValue.total);
      expect(chart.days.take(2).map((d) => (d.value, d.flag)), [
        (8210, SummaryFlag.none),
        (25000, SummaryFlag.none),
      ]);
      expect(chart.max, 25000);
    });

    test('no data on any day: no figures', () {
      final chart = summaryChart(_hr, days, const {}, now);

      expect(chart.hasData, isFalse);
      expect((chart.min, chart.avg, chart.max), (null, null, null));
      expect(chart.days, hasLength(7));
      expect(chart.days.every((d) => d.value == null && d.status == DayStatus.noData), isTrue);
    });

    test("another reading's summaries are not used", () {
      final chart = summaryChart(_steps, days, summaries(_hr, [(70, 80, _allDay)]), now);
      expect(chart.hasData, isFalse);
    });
  });

  // (value, flag) against hr's normal range 60–100.
  final flags = <String, (Reading, double, SummaryFlag)>{
    'inside the range': (_hr, 72, SummaryFlag.none),
    'on its top end': (_hr, 100, SummaryFlag.none),
    'above it': (_hr, 105, SummaryFlag.high),
    'below it': (_hr, 55, SummaryFlag.low),
    'a reading without a range': (_plain, 2000, SummaryFlag.none),
    'a reading with a goal': (_steps, 20000, SummaryFlag.none),
  };
  for (final MapEntry(key: name, value: (reading, value, flag)) in flags.entries) {
    test('flag: $name', () => expect(flagOf(reading, value), flag));
  }

  // (day index, hour mask, status): past days check every hour, today the hours begun so far.
  final statuses = <String, (int, int, DayStatus)>{
    'a past day with every hour': (0, _allDay, DayStatus.complete),
    'a past day with a gap': (0, _allDay & ~(0xF << 2), DayStatus.partial),
    'today with every hour so far': (6, todaySoFar, DayStatus.complete),
    'today with a gap this morning': (6, todaySoFar & ~(1 << 3), DayStatus.partial),
    'a value outside the hours checked still counts as data': (6, 1 << 20, DayStatus.partial),
  };
  for (final MapEntry(key: name, value: (index, hours, status)) in statuses.entries) {
    test('status: $name', () {
      final perDay = List<(double, double, int)?>.filled(7, null)..[index] = (72, 80, hours);
      expect(summaryChart(_hr, days, summaries(_hr, perDay), now).days[index].status, status);
    });
  }

  // (value, flag, status, row status): no data first, then out of range, then gaps.
  final rows = <String, (double?, SummaryFlag, DayStatus, SummaryRowStatus)>{
    'no data': (null, SummaryFlag.none, DayStatus.noData, SummaryRowStatus.missing),
    'high beats partial': (105, SummaryFlag.high, DayStatus.partial, SummaryRowStatus.high),
    'low': (55, SummaryFlag.low, DayStatus.complete, SummaryRowStatus.low),
    'partial': (72, SummaryFlag.none, DayStatus.partial, SummaryRowStatus.partial),
    'normal': (72, SummaryFlag.none, DayStatus.complete, SummaryRowStatus.normal),
  };
  for (final MapEntry(key: name, value: (value, flag, status, row)) in rows.entries) {
    test('row: $name', () {
      final day = SummaryDay(day: days.first, value: value, status: status, flag: flag);
      expect(rowStatus(day), row);
    });
  }

  SummaryChart chartOf(double? min, double? max, {DailyValue daily = DailyValue.average}) =>
      SummaryChart(days: const [], dailyValue: daily, min: min, avg: min, max: max);

  // (min, max, daily, floor)
  final floors = <String, (double?, double?, DailyValue, double)>{
    'a spread of values: 0.8 of it under the lowest': (70, 74, DailyValue.average, 66.8),
    'every day the same: 10 % of it, 0.8 under': (50, 50, DailyValue.average, 46),
    'totals start at 0': (4310, 12030, DailyValue.total, 0),
    'never below 0 for positive values': (1, 100, DailyValue.average, 0),
    'negative values go below 0': (-10, -2, DailyValue.average, -16.4),
    'no data': (null, null, DailyValue.average, 0),
  };
  for (final MapEntry(key: name, value: (min, max, daily, floor)) in floors.entries) {
    test('bar floor: $name', () {
      expect(barFloor(chartOf(min, max, daily: daily)), closeTo(floor, 1e-9));
    });
  }

  test('bar fraction: the highest is full, the floor empty, in between in proportion', () {
    final chart = chartOf(70, 74);
    expect(barFraction(chart, 74), 1);
    expect(barFraction(chart, 66.8), closeTo(0, 1e-9));
    expect(barFraction(chart, 70.4), closeTo(0.5, 1e-9));
    expect(barFraction(chartOf(null, null), 10), 0);
  });

  group('the reading shown', () {
    test('the picked one', () => expect(summaryReading([_hr, _steps], 'steps'), _steps));
    test('the first when none is picked', () => expect(summaryReading([_hr, _steps], null), _hr));
    test('the first when the device has no such reading', () {
      expect(summaryReading([_steps, _hr], 'co2'), _steps);
    });
    test('none without readings', () => expect(summaryReading(const [], 'hr'), isNull));
  });

  test('a goal means a daily total, otherwise a daily average', () {
    expect(dailyValueOf(_steps), DailyValue.total);
    expect(dailyValueOf(_hr), DailyValue.average);
  });
}
