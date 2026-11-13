import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/history/local_history_repository.dart';
import 'package:generic_flutter_app/data/readings/local_reading_repository.dart';
import 'package:generic_flutter_app/domain/services/reading_repository.dart';

import '../../fixtures/test_db.dart';

void main() {
  late AppDatabase db;
  late LocalHistoryRepository repo;
  late LocalReadingRepository readings;
  late int deviceId;
  late int otherId;
  final from = DateTime.utc(2026, 10, 20);
  final to = DateTime.utc(2026, 10, 27);
  DateTime at(int hours, int minutes, [int seconds = 0]) =>
      from.add(Duration(hours: hours, minutes: minutes, seconds: seconds));

  setUp(() async {
    db = memoryDatabase();
    repo = LocalHistoryRepository(db);
    readings = LocalReadingRepository(db);
    final userId = await db.usersDao.insertUser(fakeUser());
    deviceId = await db.devicesDao.addDevice(fakeDevice(userId));
    otherId = await db.devicesDao.addDevice(fakeDevice(userId, address: 'AA:BB:CC:00:00:02'));
  });

  test('gives each 15-minute slot with a reading once, of any key', () async {
    await readings.addAll(deviceId, [
      Sample('heart_rate', 70, at(2, 0)),
      Sample('heart_rate', 71, at(2, 14, 59)),
      Sample('spo2', 98, at(2, 5)),
      Sample('heart_rate', 72, at(2, 15)),
      Sample('heart_rate', 73, at(30, 59)),
    ]);

    expect(await repo.dataSlots(deviceId, from, to), {at(2, 0), at(2, 15), at(30, 45)});
  });

  test('only that device, from [from] up to but not including [to]', () async {
    await readings.addAll(deviceId, [
      Sample('heart_rate', 70, from.subtract(const Duration(milliseconds: 1))),
      Sample('heart_rate', 70, from),
      Sample('heart_rate', 70, to),
    ]);
    await readings.addAll(otherId, [Sample('heart_rate', 70, at(5, 0))]);

    expect(await repo.dataSlots(deviceId, from, to), {from});
    expect(await repo.dataSlots(otherId, from, to), {at(5, 0)});
  });

  test('no readings: no slots', () async {
    expect(await repo.dataSlots(deviceId, from, to), isEmpty);
  });

  test('slot times are UTC', () async {
    await readings.addAll(deviceId, [Sample('heart_rate', 70, at(1, 0))]);

    expect((await repo.dataSlots(deviceId, from, to)).single.isUtc, isTrue);
  });
}
