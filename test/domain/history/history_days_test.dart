import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/history/history_days.dart';

void main() {
  group('historyDays', () {
    final cases = <({String name, DateTime now, int count, DateTime first, DateTime last})>[
      (
        name: '7 days up to today (TC-1.4-002)',
        now: DateTime(2026, 10, 26, 10, 42),
        count: 7,
        first: DateTime(2026, 10, 20),
        last: DateTime(2026, 10, 26),
      ),
      (
        name: 'across a month',
        now: DateTime(2026, 11, 3, 8),
        count: 7,
        first: DateTime(2026, 10, 28),
        last: DateTime(2026, 11, 3),
      ),
      (
        name: 'across a year',
        now: DateTime(2027, 1, 2),
        count: 7,
        first: DateTime(2026, 12, 27),
        last: DateTime(2027, 1, 2),
      ),
      (
        name: 'a shorter config window',
        now: DateTime(2026, 10, 26, 23, 59),
        count: 5,
        first: DateTime(2026, 10, 22),
        last: DateTime(2026, 10, 26),
      ),
      (
        name: 'just after midnight is the new day',
        now: DateTime(2026, 10, 27, 0, 0, 1),
        count: 7,
        first: DateTime(2026, 10, 21),
        last: DateTime(2026, 10, 27),
      ),
    ];
    for (final c in cases) {
      test(c.name, () {
        final days = historyDays(c.now, c.count);

        expect(days, hasLength(c.count));
        expect(days.first.start, c.first);
        expect(days.last.start, c.last);
        for (final (i, day) in days.indexed) {
          final d = c.first;
          expect(day.start, DateTime(d.year, d.month, d.day + i));
          expect(day.end, DateTime(d.year, d.month, d.day + i + 1));
        }
      });
    }
  });

  group('HistoryDay.clockHours', () {
    test('a normal day has the wall-clock hours 0–23', () {
      expect(HistoryDay(DateTime(2026, 10, 21)).clockHours, List.generate(24, (h) => h));
    });

    test('days are equal by their start', () {
      expect(HistoryDay(DateTime(2026, 10, 21)), HistoryDay(DateTime(2026, 10, 21)));
    });
  });

  group('hoursToCheck', () {
    final day = HistoryDay(DateTime(2026, 10, 26));
    final all = {for (var h = 0; h < 24; h++) h};
    final cases = <({String name, DateTime now, Set<int> hours})>[
      (name: 'a past day: all 24', now: DateTime(2026, 10, 28), hours: all),
      (
        name: 'today at 10:42: hours 0–10',
        now: DateTime(2026, 10, 26, 10, 42),
        hours: {for (var h = 0; h <= 10; h++) h},
      ),
      (name: 'today at midnight: the first hour', now: DateTime(2026, 10, 26), hours: {0}),
      (name: 'today at 23:59: all 24', now: DateTime(2026, 10, 26, 23, 59), hours: all),
      (name: 'a day not begun: none', now: DateTime(2026, 10, 25, 12), hours: {}),
    ];
    for (final c in cases) {
      test(c.name, () => expect(hoursToCheck(day, c.now), c.hours));
    }
  });

  group('dayStatus', () {
    final all = {for (var h = 0; h < 24; h++) h};
    final cases = <({String name, Set<int> data, Set<int> check, DayStatus status})>[
      (name: 'every hour', data: all, check: all, status: DayStatus.complete),
      (
        name: 'gap 02:00–06:00 (TC-1.4-004)',
        data: all.difference({2, 3, 4, 5}),
        check: all,
        status: DayStatus.partial,
      ),
      (name: 'one hour', data: {10}, check: all, status: DayStatus.partial),
      (name: 'nothing', data: {}, check: all, status: DayStatus.noData),
      (
        name: 'today, every hour so far',
        data: {0, 1, 2},
        check: {0, 1, 2},
        status: DayStatus.complete,
      ),
      (
        name: 'a device added an hour ago (TC-1.4-010)',
        data: {9, 10},
        check: {for (var h = 0; h <= 10; h++) h},
        status: DayStatus.partial,
      ),
      (name: 'hours after now do not count', data: {5}, check: {0, 1, 2}, status: DayStatus.noData),
      (name: 'nothing to check', data: {}, check: {}, status: DayStatus.noData),
    ];
    for (final c in cases) {
      test(c.name, () => expect(dayStatus(c.data, c.check), c.status));
    }
  });

  group('pickedDayIndex', () {
    final days = historyDays(DateTime(2026, 10, 26, 9), 7);
    final cases = <({String name, DateTime? picked, int index})>[
      (name: 'not set: today', picked: null, index: 6),
      (name: 'a day in the window', picked: DateTime(2026, 10, 22), index: 2),
      (name: 'a day that left the window: the oldest', picked: DateTime(2026, 10, 19), index: 0),
    ];
    for (final c in cases) {
      test(c.name, () => expect(pickedDayIndex(days, c.picked), c.index));
    }

    test('no days', () => expect(pickedDayIndex(const [], null), -1));
  });
}
