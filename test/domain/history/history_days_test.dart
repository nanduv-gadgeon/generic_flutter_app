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

  group('hoursToCover', () {
    final day = HistoryDay(DateTime(2026, 10, 26), DateTime(2026, 10, 27));
    final cases = <({String name, DateTime now, int hours})>[
      (name: 'a past day: all 24', now: DateTime(2026, 10, 28), hours: 24),
      (name: 'today at 10:42: hours 0–10', now: DateTime(2026, 10, 26, 10, 42), hours: 11),
      (name: 'today at midnight: the first hour', now: DateTime(2026, 10, 26), hours: 1),
      (name: 'today at 23:59: all 24', now: DateTime(2026, 10, 26, 23, 59), hours: 24),
      (name: 'a day not begun: none', now: DateTime(2026, 10, 25, 12), hours: 0),
    ];
    for (final c in cases) {
      test(c.name, () => expect(hoursToCover(day, c.now), c.hours));
    }

    test('a 23-hour and a 25-hour day (clock change)', () {
      final start = DateTime.utc(2026, 3, 29);
      expect(HistoryDay(start, start.add(const Duration(hours: 23))).hours, 23);
      expect(HistoryDay(start, start.add(const Duration(hours: 25))).hours, 25);
      expect(HistoryDay(start, start.add(const Duration(hours: 23, minutes: 30))).hours, 24);
    });
  });

  group('dayStatus', () {
    final all = {for (var h = 0; h < 24; h++) h};
    final cases = <({String name, Set<int> hours, int cover, DayStatus status})>[
      (name: 'every hour', hours: all, cover: 24, status: DayStatus.complete),
      (
        name: 'gap 02:00–06:00',
        hours: all.difference({2, 3, 4, 5}),
        cover: 24,
        status: DayStatus.partial,
      ),
      (name: 'one hour', hours: {10}, cover: 24, status: DayStatus.partial),
      (name: 'nothing', hours: {}, cover: 24, status: DayStatus.noData),
      (name: 'today, every hour so far', hours: {0, 1, 2}, cover: 3, status: DayStatus.complete),
      (name: 'hours after now do not count', hours: {5}, cover: 3, status: DayStatus.noData),
      (name: 'nothing to cover', hours: {}, cover: 0, status: DayStatus.noData),
    ];
    for (final c in cases) {
      test(c.name, () => expect(dayStatus(c.hours, c.cover), c.status));
    }
  });

  group('dayStatuses', () {
    final now = DateTime(2026, 10, 26, 10, 42);
    final days = historyDays(now, 7);

    /// The 15-minute slots of [day] at the given hours, every quarter.
    Iterable<DateTime> slots(HistoryDay day, Iterable<int> hours) => [
      for (final h in hours)
        for (final q in [0, 15, 30, 45]) day.start.add(Duration(hours: h, minutes: q)),
    ];

    test('day 1 full, day 2 gap 02:00–06:00, day 3 empty (TC-1.4-004)', () {
      final allDay = List.generate(24, (h) => h);
      final data = [
        ...slots(days[0], allDay),
        ...slots(days[1], allDay.where((h) => h < 2 || h >= 6)),
      ];

      final statuses = dayStatuses(days, data, now);

      expect(statuses.take(3), [DayStatus.complete, DayStatus.partial, DayStatus.noData]);
    });

    test('a device added an hour ago: today Partial, the 6 days before No data (TC-1.4-010)', () {
      final statuses = dayStatuses(days, slots(days.last, [9, 10]), now);

      expect(statuses, [...List.filled(6, DayStatus.noData), DayStatus.partial]);
    });

    test('one slot in an hour is enough for that hour; slots outside the window are ignored', () {
      final data = [
        for (var h = 0; h <= 10; h++) days.last.start.add(Duration(hours: h, minutes: 45)),
        days.first.start.subtract(const Duration(minutes: 15)),
      ];

      final statuses = dayStatuses(days, data, now);

      expect(statuses.last, DayStatus.complete);
      expect(statuses.first, DayStatus.noData);
    });

    test('UTC slot times fall on their local day', () {
      final data = slots(days[3], List.generate(24, (h) => h)).map((s) => s.toUtc());

      expect(dayStatuses(days, data, now)[3], DayStatus.complete);
    });
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
