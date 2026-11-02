import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';

import '../../fixtures/test_db.dart';

void main() {
  late AppDatabase db;
  late int userId;

  setUp(() async {
    db = memoryDatabase();
    userId = await db.usersDao.insertUser(fakeUser());
  });

  Future<List<String>> addressesFor(int user) async => [
    for (final d in await db.devicesDao.watchForUser(user).first) d.address,
  ];

  test('adds devices at the end of the list', () async {
    await db.devicesDao.addDevice(fakeDevice(userId, address: 'A'));
    await db.devicesDao.addDevice(fakeDevice(userId, address: 'B'));

    final list = await db.devicesDao.watchForUser(userId).first;
    expect([for (final d in list) (d.address, d.sortOrder)], [('A', 0), ('B', 1)]);
  });

  test('only returns the given user\'s devices', () async {
    final other = await db.usersDao.insertUser(fakeUser(email: 'other@example.com'));
    await db.devicesDao.addDevice(fakeDevice(userId, address: 'A'));
    await db.devicesDao.addDevice(fakeDevice(other, address: 'B'));

    expect(await addressesFor(userId), ['A']);
    expect(await addressesFor(other), ['B']);
  });

  test('the same address can be added by two users but not twice by one', () async {
    final other = await db.usersDao.insertUser(fakeUser(email: 'other@example.com'));
    await db.devicesDao.addDevice(fakeDevice(userId));
    await db.devicesDao.addDevice(fakeDevice(other));

    await expectLater(db.devicesDao.addDevice(fakeDevice(userId)), throwsA(isA<Exception>()));
  });

  test('reorder saves the new order', () async {
    final a = await db.devicesDao.addDevice(fakeDevice(userId, address: 'A'));
    final b = await db.devicesDao.addDevice(fakeDevice(userId, address: 'B'));
    final c = await db.devicesDao.addDevice(fakeDevice(userId, address: 'C'));

    await db.devicesDao.reorder(userId, [c, a, b]);

    expect(await addressesFor(userId), ['C', 'A', 'B']);
  });

  test('rename and updateStatus change only what is given', () async {
    final id = await db.devicesDao.addDevice(fakeDevice(userId));
    final seen = DateTime(2026, 1, 1, 9);

    await db.devicesDao.rename(id, 'Kitchen sensor');
    await db.devicesDao.updateStatus(id, batteryPercent: 42, lastHeartbeatAt: seen);
    await db.devicesDao.updateStatus(id, firmware: '1.0.0');

    final device = (await db.devicesDao.watchForUser(userId).first).single;
    expect(device.name, 'Kitchen sensor');
    expect(device.batteryPercent, 42);
    expect(device.lastHeartbeatAt, seen);
    expect(device.firmware, '1.0.0');
    expect(device.transport, DeviceTransport.ble);
  });

  final batteryCases = {-1: false, 0: true, 100: true, 101: false};
  for (final MapEntry(key: battery, value: allowed) in batteryCases.entries) {
    test('battery $battery% is ${allowed ? 'allowed' : 'rejected'}', () async {
      final id = await db.devicesDao.addDevice(fakeDevice(userId));
      final update = db.devicesDao.updateStatus(id, batteryPercent: battery);

      if (allowed) {
        await update;
      } else {
        await expectLater(update, throwsA(isA<Exception>()));
      }
    });
  }

  test('deleteDevice removes it', () async {
    final id = await db.devicesDao.addDevice(fakeDevice(userId));

    await db.devicesDao.deleteDevice(id);

    expect(await addressesFor(userId), isEmpty);
  });

  test('a device with the default sortOrder value still goes last', () async {
    await db.devicesDao.addDevice(fakeDevice(userId, address: 'A'));
    final id = await db.devicesDao.addDevice(
      fakeDevice(userId, address: 'B').copyWith(sortOrder: const Value(0)),
    );

    final device = (await db.devicesDao.watchForUser(userId).first).firstWhere((d) => d.id == id);
    expect(device.sortOrder, 1);
  });
}
