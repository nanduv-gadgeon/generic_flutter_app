import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';

import '../../fixtures/test_db.dart';

/// The DAO parts Device settings uses (task 1.2.9). Fake data only.
void main() {
  late AppDatabase db;
  late int userId;

  setUp(() async {
    db = memoryDatabase();
    userId = await db.usersDao.insertUser(fakeUser());
  });

  DeviceAlertsCompanion alert(String key, {double? above, double? below}) =>
      DeviceAlertsCompanion.insert(
        deviceId: 0, // set by the DAO
        readingKey: key,
        above: Value(above),
        below: Value(below),
      );

  Future<int> addBandWithAlerts() => db.devicesDao.addDeviceWithAlerts(fakeDevice(userId), [
    alert('heart_rate', above: 110),
    alert('battery', below: 15),
  ]);

  test('watchDevice gives the device and its alerts in reading-key order', () async {
    final id = await addBandWithAlerts();

    final (device, alerts) = (await db.devicesDao.watchDevice(userId, id).first)!;

    expect(device.name, 'Test band');
    expect(
      [for (final a in alerts) (a.readingKey, a.enabled)],
      [('battery', true), ('heart_rate', true)],
    );
  });

  test('watchDevice works for a device without alerts', () async {
    final id = await db.devicesDao.addDevice(fakeDevice(userId));

    final (device, alerts) = (await db.devicesDao.watchDevice(userId, id).first)!;

    expect(device.id, id);
    expect(alerts, isEmpty);
  });

  test('watchDevice gives null for another user\'s device or an unknown id', () async {
    final id = await addBandWithAlerts();
    final other = await db.usersDao.insertUser(fakeUser(email: 'other@example.com'));

    expect(await db.devicesDao.watchDevice(other, id).first, isNull);
    expect(await db.devicesDao.watchDevice(userId, id + 99).first, isNull);
  });

  test('watchDevice emits again after a rename, a toggle and a delete', () async {
    final id = await addBandWithAlerts();
    final seen = <String>[];
    final sub = db.devicesDao.watchDevice(userId, id).listen((found) {
      if (found == null) return seen.add('gone');
      final (device, alerts) = found;
      final on = alerts.where((a) => a.enabled).length;
      seen.add('${device.name}/$on');
    });
    addTearDown(sub.cancel);

    Future<void> settle() => pumpEventQueue();
    await settle();
    await db.devicesDao.rename(id, 'Kitchen band');
    await settle();
    await db.devicesDao.setAlertEnabled(id, 'battery', enabled: false);
    await settle();
    await db.devicesDao.deleteDevice(id);
    await settle();

    expect(seen, ['Test band/2', 'Kitchen band/2', 'Kitchen band/1', 'gone']);
  });

  test('setAlertEnabled changes only that alert, and keeps its limit', () async {
    final id = await addBandWithAlerts();

    await db.devicesDao.setAlertEnabled(id, 'heart_rate', enabled: false);

    final alerts = await db.devicesDao.alertsFor(id);
    expect(
      [for (final a in alerts) (a.readingKey, a.enabled, a.above, a.below)],
      [('battery', true, null, 15.0), ('heart_rate', false, 110.0, null)],
    );
  });

  test('watchAlertLimitsForUser: each of the user\'s devices with its limits, live', () async {
    final band = await addBandWithAlerts();
    final bare = await db.devicesDao.addDevice(fakeDevice(userId, address: 'AA:BB:CC:00:00:02'));
    final other = await db.usersDao.insertUser(fakeUser(email: 'other@example.com'));
    await db.devicesDao.addDevice(fakeDevice(other, address: 'AA:BB:CC:00:00:03'));
    final seen = <Map<int, List<(String, bool)>>>[];
    final sub = db.devicesDao
        .watchAlertLimitsForUser(userId)
        .map(
          (byDevice) => {
            for (final MapEntry(:key, :value) in byDevice.entries)
              key: [for (final a in value) (a.readingKey, a.enabled)]
                ..sort((a, b) => a.$1.compareTo(b.$1)),
          },
        )
        .listen(seen.add);
    await pumpEventQueue();

    await db.devicesDao.setAlertEnabled(band, 'heart_rate', enabled: false);
    await pumpEventQueue();
    await sub.cancel();

    expect(seen.first, {
      band: [('battery', true), ('heart_rate', true)],
      bare: <(String, bool)>[],
    });
    expect(seen.last[band], [('battery', true), ('heart_rate', false)]);
  });
}
