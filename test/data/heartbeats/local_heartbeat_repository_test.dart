import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/heartbeats/local_heartbeat_repository.dart';

import '../../fixtures/test_db.dart';

void main() {
  late AppDatabase db;
  late LocalHeartbeatRepository repo;
  late int deviceId;
  late int otherId;
  final t = DateTime.utc(2026, 11, 11, 9);

  setUp(() async {
    db = memoryDatabase();
    repo = LocalHeartbeatRepository(db);
    final userId = await db.usersDao.insertUser(fakeUser());
    deviceId = await db.devicesDao.addDevice(fakeDevice(userId));
    otherId = await db.devicesDao.addDevice(fakeDevice(userId, address: 'AA:BB:CC:00:00:02'));
  });
  tearDown(() => db.close());

  Future<List<(DateTime, int?)>> rows(int id) async => [
    for (final h in await db.heartbeatsDao.forDevice(id))
      (DateTime.fromMillisecondsSinceEpoch(h.atMs, isUtc: true), h.batteryPercent),
  ];

  test('stores each heartbeat in UTC with its battery level, per device', () async {
    await repo.add(deviceId, t.add(const Duration(minutes: 1)), batteryPercent: 79);
    await repo.add(deviceId, t.toLocal(), batteryPercent: 80);
    await repo.add(otherId, t);

    expect(await rows(deviceId), [(t, 80), (t.add(const Duration(minutes: 1)), 79)]);
    expect(await rows(otherId), [(t, null)]);
  });

  test('deletes heartbeats from before the cutoff and says how many', () async {
    for (final hours in [0, 23, 25, 48]) {
      await repo.add(deviceId, t.subtract(Duration(hours: hours)));
    }

    final deleted = await repo.deleteOlderThan(t.subtract(const Duration(hours: 24)));

    expect(deleted, 2);
    expect((await rows(deviceId)).map((r) => r.$1), [t.subtract(const Duration(hours: 23)), t]);
  });

  test('removing a device removes its heartbeats', () async {
    await repo.add(deviceId, t);
    await db.devicesDao.deleteDevice(deviceId);

    expect(await db.select(db.heartbeats).get(), isEmpty);
  });
}
