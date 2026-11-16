import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/history/local_daily_summary_repository.dart';
import 'package:generic_flutter_app/data/readings/local_reading_repository.dart';
import 'package:generic_flutter_app/domain/history/local_day.dart';
import 'package:generic_flutter_app/domain/services/reading_repository.dart';

import '../../fixtures/test_db.dart';

/// Daily summaries over a real (in-memory) database, in local time. Made-up readings only.
void main() {
  late AppDatabase db;
  late LocalReadingRepository readings;
  late LocalDailySummaryRepository summaries;
  late int band;
  late int patch;
  final now = DateTime(2026, 11, 13, 9, 30);
  final today = DateTime(2026, 11, 13);
  final weekAgo = addDays(today, -6);
  DateTime on(int day, int hour, [int minute = 0]) => DateTime(2026, 11, day, hour, minute);

  setUp(() async {
    db = memoryDatabase();
    readings = LocalReadingRepository(db);
    summaries = LocalDailySummaryRepository(db, now: () => now);
    final userId = await db.usersDao.insertUser(fakeUser());
    band = await db.devicesDao.addDevice(fakeDevice(userId));
    patch = await db.devicesDao.addDevice(fakeDevice(userId, address: 'AA:BB:CC:00:00:02'));
  });

  Future<List<(String, int, double, double, double, int)>> stored(int deviceId, String key) async =>
      [
        for (final s in await summaries.watch(deviceId, key, weekAgo).first)
          (s.key, dayNumber(s.day), s.min, s.avg, s.max, s.count),
      ];

  test('sums up each finished day per device and key; today is not stored', () async {
    await readings.addAll(band, [
      Sample('hr', 60, on(11, 8)),
      Sample('hr', 80, on(11, 8, 30)),
      Sample('hr', 100, on(11, 20)),
      Sample('hr', 70, on(12, 23, 59)),
      Sample('spo2', 97, on(12, 1)),
      Sample('hr', 75, on(13, 7)), // today
    ]);
    await readings.addAll(patch, [Sample('current', 12, on(12, 10))]);

    final days = await summaries.refresh(from: weekAgo, to: nextDay(today));

    expect(days, 2);
    expect(await stored(band, 'hr'), [
      ('hr', 20261111, 60, 80, 100, 3),
      ('hr', 20261112, 70, 70, 70, 1),
    ]);
    expect(await stored(band, 'spo2'), [('spo2', 20261112, 97, 97, 97, 1)]);
    expect(await stored(patch, 'current'), [('current', 20261112, 12, 12, 12, 1)]);
  });

  test('the hours with readings are kept', () async {
    await readings.addAll(band, [
      Sample('hr', 60, on(11, 0, 5)),
      Sample('hr', 61, on(11, 6, 59)),
      Sample('hr', 62, on(11, 23)),
    ]);
    await summaries.refresh(from: weekAgo, to: today);

    final day = (await summaries.watch(band, 'hr', weekAgo).first).single;
    expect(
      [
        for (var h = 0; h < 24; h++)
          if (day.hasHour(h)) h,
      ],
      [0, 6, 23],
    );
  });

  test(
    'running it again gives the same rows, and a day with no readings left loses its own',
    () async {
      await readings.addAll(band, [Sample('hr', 60, on(10, 8)), Sample('hr', 70, on(11, 8))]);
      await summaries.refresh(from: weekAgo, to: today);
      await summaries.refresh(from: weekAgo, to: today);
      expect(await stored(band, 'hr'), hasLength(2));

      await readings.deleteOlderThan(on(11, 0));
      await summaries.refresh(from: weekAgo, to: today);

      expect(await stored(band, 'hr'), [('hr', 20261111, 70, 70, 70, 1)]);
    },
  );

  test('one device refreshed leaves the others as they were', () async {
    await readings.addAll(band, [Sample('hr', 60, on(11, 8))]);
    await readings.addAll(patch, [Sample('current', 12, on(11, 8))]);
    await summaries.refresh(from: weekAgo, to: today);
    await db.customStatement('DELETE FROM readings');

    await summaries.refresh(from: weekAgo, to: today, deviceId: band);

    expect(await stored(band, 'hr'), isEmpty);
    expect(await stored(patch, 'current'), hasLength(1));
  });

  test('late readings from an earlier day have that day worked out again', () async {
    final late = LocalReadingRepository(db, summaries: summaries);
    await late.addAll(band, [Sample('hr', 60, on(11, 8)), Sample('hr', 70, on(13, 8))]);
    expect(await stored(band, 'hr'), [('hr', 20261111, 60, 60, 60, 1)]);

    await late.addAll(band, [Sample('hr', 90, on(11, 9))]);
    expect(await stored(band, 'hr'), [('hr', 20261111, 60, 75, 90, 2)]);
  });

  test("today's readings are summed up when asked, not stored", () async {
    await readings.addAll(band, [
      Sample('hr', 60, on(13, 1)),
      Sample('hr', 80, on(13, 9)),
      Sample('hr', 99, on(12, 9)),
    ]);

    final now = await summaries.today(band);

    expect(now.map((s) => (s.key, dayNumber(s.day), s.min, s.avg, s.max)), [
      ('hr', 20261113, 60, 70, 80),
    ]);
    expect(await stored(band, 'hr'), isEmpty);
  });

  test('deletes summaries of days before the one given', () async {
    await readings.addAll(band, [Sample('hr', 60, on(10, 8)), Sample('hr', 70, on(12, 8))]);
    await summaries.refresh(from: weekAgo, to: today);

    expect(await summaries.deleteBefore(DateTime(2026, 11, 11)), 1);
    expect(await stored(band, 'hr'), [('hr', 20261112, 70, 70, 70, 1)]);
  });

  test('summaries go when their device is removed', () async {
    await readings.addAll(band, [Sample('hr', 60, on(11, 8))]);
    await summaries.refresh(from: weekAgo, to: today);

    await db.devicesDao.deleteDevice(band);

    expect(await db.select(db.dailySummaries).get(), isEmpty);
  });
}
