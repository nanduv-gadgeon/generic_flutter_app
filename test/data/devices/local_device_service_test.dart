import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/devices/local_device_service.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';

import '../../fixtures/test_db.dart';

void main() {
  late AppDatabase db;
  late LocalDeviceService service;
  late int userId;

  setUp(() async {
    db = memoryDatabase();
    service = LocalDeviceService(db);
    userId = await db.usersDao.insertUser(fakeUser());
  });

  test('a user with no devices gets an empty list', () async {
    expect(await service.watchDevices(userId).first, isEmpty);
  });

  test('maps each stored device', () async {
    final id = await db.devicesDao.addDevice(fakeDevice(userId));
    await db.devicesDao.updateStatus(
      id,
      batteryPercent: 64,
      lastHeartbeatAt: DateTime(2026, 1, 1, 9),
    );

    expect(await service.watchDevices(userId).first, [
      UserDevice(
        id: id,
        name: 'Test band',
        profileId: 'test_device_v1',
        batteryPercent: 64,
        lastHeartbeatAt: DateTime(2026, 1, 1, 9),
      ),
    ]);
  });

  test('keeps the user\'s order', () async {
    final a = await db.devicesDao.addDevice(fakeDevice(userId, address: 'A'));
    final b = await db.devicesDao.addDevice(fakeDevice(userId, address: 'B'));
    await db.devicesDao.reorder(userId, [b, a]);

    expect([for (final d in await service.watchDevices(userId).first) d.id], [b, a]);
  });

  test('only lists the given user\'s devices', () async {
    final other = await db.usersDao.insertUser(fakeUser(email: 'other@example.com'));
    await db.devicesDao.addDevice(fakeDevice(other));

    expect(await service.watchDevices(userId).first, isEmpty);
    expect(await service.watchDevices(other).first, hasLength(1));
  });

  test('emits again when a device is added', () async {
    final counts = service.watchDevices(userId).map((list) => list.length);
    final expectation = expectLater(counts, emitsInOrder([0, 1]));

    await pumpEventQueue();
    await db.devicesDao.addDevice(fakeDevice(userId));
    await expectation;
  });
}
