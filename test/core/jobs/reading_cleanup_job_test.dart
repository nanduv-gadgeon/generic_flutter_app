import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/jobs/reading_cleanup_job.dart';
import 'package:generic_flutter_app/data/readings/local_reading_repository.dart';
import 'package:generic_flutter_app/domain/services/heartbeat_repository.dart';
import 'package:generic_flutter_app/domain/services/reading_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/test_db.dart';

class MockReadingRepository extends Mock implements ReadingRepository {}

class MockHeartbeatRepository extends Mock implements HeartbeatRepository {}

void main() {
  final now = DateTime.utc(2026, 11, 10, 9);

  test('keeps the last 7 days and deletes what is older', () async {
    final db = memoryDatabase();
    final repo = LocalReadingRepository(db);
    final userId = await db.usersDao.insertUser(fakeUser());
    final deviceId = await db.devicesDao.addDevice(fakeDevice(userId));
    final ages = {
      'just now': Duration.zero,
      'day 7': const Duration(days: 7) - const Duration(milliseconds: 1),
      'day 8': const Duration(days: 7, milliseconds: 1),
      'a month': const Duration(days: 30),
    };
    await repo.addAll(deviceId, [
      for (final (i, age) in ages.values.indexed) Sample('spo2', 90.0 + i, now.subtract(age)),
    ]);

    await ReadingCleanupJob(repo, 7, now: () => now).runOnce();

    final left = await repo.watchRange(deviceId, 'spo2', DateTime.utc(2000)).first;
    expect(left.map((s) => s.value), [91, 90]); // day 7, then just now
  });

  final days = {1: DateTime.utc(2026, 11, 9, 9), 7: DateTime.utc(2026, 11, 3, 9)};
  for (final MapEntry(key: daysOnPhone, value: cutoff) in days.entries) {
    test('the days kept come from the config ($daysOnPhone)', () {
      expect(
        ReadingCleanupJob(MockReadingRepository(), daysOnPhone, now: () => now).cutoff,
        cutoff,
      );
    });
  }

  test('runs at start, then once a day until stopped', () {
    fakeAsync((async) {
      final repo = MockReadingRepository();
      when(() => repo.deleteOlderThan(any())).thenAnswer((_) async => 0);
      final job = ReadingCleanupJob(repo, 7, now: () => now)..start();
      async.flushMicrotasks();
      verify(() => repo.deleteOlderThan(any())).called(1);

      async.elapse(const Duration(days: 2));
      verify(() => repo.deleteOlderThan(any())).called(2);

      job.stop();
      async.elapse(const Duration(days: 2));
      verifyNever(() => repo.deleteOlderThan(any()));
    });
  });

  test('a failed clean-up is tried again the next day', () {
    fakeAsync((async) {
      final repo = MockReadingRepository();
      when(() => repo.deleteOlderThan(any())).thenThrow(StateError('locked'));
      final job = ReadingCleanupJob(repo, 7, now: () => now)..start();
      async.elapse(const Duration(days: 1));

      verify(() => repo.deleteOlderThan(any())).called(2);
      job.stop();
    });
  });

  test('also deletes heartbeats older than 24 hours, on the same runs', () {
    fakeAsync((async) {
      final readings = MockReadingRepository();
      when(() => readings.deleteOlderThan(any())).thenAnswer((_) async => 0);
      final heartbeats = MockHeartbeatRepository();
      when(() => heartbeats.deleteOlderThan(any())).thenAnswer((_) async => 0);
      final job = ReadingCleanupJob(readings, 7, heartbeats: heartbeats, now: () => now)..start();
      async.elapse(const Duration(days: 1));

      final cutoffs = verify(() => heartbeats.deleteOlderThan(captureAny())).captured;
      expect(cutoffs, [DateTime.utc(2026, 11, 9, 9), DateTime.utc(2026, 11, 9, 9)]);
      verify(() => readings.deleteOlderThan(DateTime.utc(2026, 11, 3, 9))).called(2);
      job.stop();
    });
  });

  test('a failed heartbeat clean-up does not stop the readings one', () {
    fakeAsync((async) {
      final readings = MockReadingRepository();
      when(() => readings.deleteOlderThan(any())).thenAnswer((_) async => 0);
      final heartbeats = MockHeartbeatRepository();
      when(() => heartbeats.deleteOlderThan(any())).thenThrow(StateError('locked'));
      ReadingCleanupJob(readings, 7, heartbeats: heartbeats, now: () => now).runOnce();
      async.flushMicrotasks();

      verify(() => readings.deleteOlderThan(any())).called(1);
      verify(() => heartbeats.deleteOlderThan(any())).called(1);
    });
  });
}
