import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/readings/local_reading_repository.dart';
import 'package:generic_flutter_app/domain/services/reading_repository.dart';

import '../../fixtures/test_db.dart';

void main() {
  late AppDatabase db;
  late LocalReadingRepository repo;
  late int deviceId;
  late int otherId;
  final t = DateTime.utc(2026, 11, 3, 9);
  DateTime at(int ms) => t.add(Duration(milliseconds: ms));

  setUp(() async {
    db = memoryDatabase();
    repo = LocalReadingRepository(db);
    final userId = await db.usersDao.insertUser(fakeUser());
    deviceId = await db.devicesDao.addDevice(fakeDevice(userId));
    otherId = await db.devicesDao.addDevice(fakeDevice(userId, address: 'AA:BB:CC:00:00:02'));
  });

  test('keeps readings milliseconds apart, and skips one stored twice', () async {
    await repo.addAll(deviceId, [Sample('spo2', 97, at(0)), Sample('spo2', 98, at(10))]);
    await repo.addAll(deviceId, [Sample('spo2', 99, at(10))]); // same key and time: skipped

    expect(await repo.watchRange(deviceId, 'spo2', t).first, [
      Sample('spo2', 97, at(0)),
      Sample('spo2', 98, at(10)),
    ]);
  });

  test('a range starts at its time and holds only that device and key, oldest first', () async {
    await repo.addAll(deviceId, [
      Sample('spo2', 98, at(2000)),
      Sample('spo2', 95, at(-1)),
      Sample('spo2', 97, at(1000)),
      Sample('heart_rate', 70, at(1000)),
    ]);
    await repo.addAll(otherId, [Sample('spo2', 90, at(1000))]);

    expect(await repo.watchRange(deviceId, 'spo2', t).first, [
      Sample('spo2', 97, at(1000)),
      Sample('spo2', 98, at(2000)),
    ]);
  });

  test('latest gives the newest reading of each key and updates', () async {
    await repo.addAll(deviceId, [
      Sample('spo2', 97, at(0)),
      Sample('spo2', 98, at(1000)),
      Sample('heart_rate', 70, at(500)),
    ]);
    final latest = repo.watchLatest(deviceId);

    expect(await latest.first, {
      'spo2': Sample('spo2', 98, at(1000)),
      'heart_rate': Sample('heart_rate', 70, at(500)),
    });
    await repo.addAll(deviceId, [Sample('heart_rate', 72, at(2000))]);
    expect((await latest.first)['heart_rate'], Sample('heart_rate', 72, at(2000)));
  });

  test('removing a device deletes its readings', () async {
    await repo.addAll(deviceId, [Sample('spo2', 97, at(0))]);

    await db.devicesDao.deleteDevice(deviceId);

    expect(await db.select(db.readings).get(), isEmpty);
  });

  test('times come back in UTC', () async {
    await repo.addAll(deviceId, [Sample('spo2', 97, at(0).toLocal())]);

    expect((await repo.watchLatest(deviceId).first)['spo2']!.at.isUtc, isTrue);
  });
}
