import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/history/local_day.dart';

/// Local calendar days: History, the daily summaries and "today" on the dashboard.
void main() {
  test('startOfDay is local midnight', () {
    expect(startOfDay(DateTime(2026, 11, 13, 23, 59, 59)), DateTime(2026, 11, 13));
    expect(startOfDay(DateTime(2026, 11, 13)), DateTime(2026, 11, 13));
  });

  // (from, next midnight, 3 days later, 7 days earlier)
  final days = <String, (DateTime, DateTime, DateTime, DateTime)>{
    'a normal day': (
      DateTime(2026, 11, 13),
      DateTime(2026, 11, 14),
      DateTime(2026, 11, 16),
      DateTime(2026, 11, 6),
    ),
    'the end of a month': (
      DateTime(2026, 11, 30),
      DateTime(2026, 12, 1),
      DateTime(2026, 12, 3),
      DateTime(2026, 11, 23),
    ),
    'the end of a year': (
      DateTime(2026, 12, 31),
      DateTime(2027, 1, 1),
      DateTime(2027, 1, 3),
      DateTime(2026, 12, 24),
    ),
    'a leap day': (
      DateTime(2028, 2, 28),
      DateTime(2028, 2, 29),
      DateTime(2028, 3, 2),
      DateTime(2028, 2, 21),
    ),
  };
  for (final MapEntry(key: name, value: (day, next, later, earlier)) in days.entries) {
    test('nextDay and addDays count calendar days: $name', () {
      expect(nextDay(day), next);
      expect(addDays(day, 3), later);
      expect(addDays(day, -7), earlier);
    });
  }

  test('nextDay keeps UTC', () {
    expect(nextDay(DateTime.utc(2026, 11, 13)), DateTime.utc(2026, 11, 14));
  });

  final numbers = {
    DateTime(2026, 11, 13): 20261113,
    DateTime(2026, 1, 1): 20260101,
    DateTime(2026, 12, 31): 20261231,
  };
  for (final MapEntry(key: day, value: number) in numbers.entries) {
    test('the day $number as a number and back', () {
      expect(dayNumber(day), number);
      expect(dayFromNumber(number), day);
    });
  }

  test('day numbers sort like the days', () {
    expect(dayNumber(DateTime(2026, 12, 31)) < dayNumber(DateTime(2027, 1, 1)), isTrue);
  });
}
