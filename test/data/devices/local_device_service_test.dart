import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/devices/local_device_service.dart';
import 'package:generic_flutter_app/data/devices/no_device_registration.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/services/device_registration.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';

import 'package:mocktail/mocktail.dart';

import '../../fixtures/test_db.dart';

class MockDeviceRegistration extends Mock implements DeviceRegistration {}

const _defaults = [AlertRule(key: 'current', above: 120), AlertRule(key: 'battery', below: 15)];

void main() {
  late AppDatabase db;
  late LocalDeviceService service;
  late int userId;

  setUp(() async {
    db = memoryDatabase();
    service = LocalDeviceService(db, const NoDeviceRegistration());
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

  group('addDevice', () {
    NewDevice newDevice({String address = 'AA:BB:CC:00:00:09', String? ip}) => NewDevice(
      userId: userId,
      profileId: 'test_device_v1',
      transport: ip == null ? Transport.ble : Transport.wifi,
      address: address,
      ipAddress: ip,
      name: 'Test band 0009',
    );

    test('Phase 1 saves the device with the config default alerts and no key', () async {
      final added = await service.addDevice(newDevice(), _defaults);

      expect(added, AddedDevice(id: added.id, name: 'Test band 0009', alerts: _defaults));
      final row = (await db.select(db.devices).get()).single;
      expect(row.transport, DeviceTransport.ble);
      expect(row.deviceKey, isNull);
      final alerts = await db.devicesDao.alertsFor(added.id);
      expect(
        [for (final a in alerts) (a.readingKey, a.above, a.below, a.enabled)],
        [('battery', null, 15.0, true), ('current', 120.0, null, true)],
      );
    });

    test('saves a Wi‑Fi device with its mDNS id as address and its IP', () async {
      await service.addDevice(newDevice(address: 'tst-0001', ip: '192.168.1.20'), _defaults);

      final row = (await db.select(db.devices).get()).single;
      expect(
        (row.transport, row.address, row.ipAddress),
        (DeviceTransport.wifi, 'tst-0001', '192.168.1.20'),
      );
    });

    test('refuses a device the user already has', () async {
      await service.addDevice(newDevice(), _defaults);

      expect(await service.isAdded(userId, 'AA:BB:CC:00:00:09'), isTrue);
      await expectLater(
        service.addDevice(newDevice(), _defaults),
        throwsA(isA<DeviceAlreadyAddedException>()),
      );
    });

    test('stores the cloud key and suggested alerts when the cloud answers', () async {
      final registration = MockDeviceRegistration();
      const suggested = [AlertRule(key: 'current', above: 100)];
      when(() => registration.register(newDevice())).thenAnswer(
        (_) async => const CloudRegistration(deviceKey: 'DK-TEST-0000', alerts: suggested),
      );
      service = LocalDeviceService(db, registration);

      final added = await service.addDevice(newDevice(), _defaults);

      expect(added.deviceKey, 'DK-TEST-0000');
      expect(added.alerts, suggested);
      expect(added.suggestedAlerts, isTrue);
      expect((await db.select(db.devices).get()).single.deviceKey, 'DK-TEST-0000');
      expect([for (final a in await db.devicesDao.alertsFor(added.id)) a.readingKey], ['current']);
    });

    test('keeps the defaults when the cloud sends a key but no alerts', () async {
      final registration = MockDeviceRegistration();
      when(() => registration.register(newDevice()))
          .thenAnswer((_) async => const CloudRegistration(deviceKey: 'DK-TEST-0000'));
      service = LocalDeviceService(db, registration);

      final added = await service.addDevice(newDevice(), _defaults);

      expect(added.alerts, _defaults);
      expect(added.suggestedAlerts, isFalse);
      expect(await db.devicesDao.alertsFor(added.id), hasLength(2));
    });

    test('removeDevice deletes it and tells the registration', () async {
      final registration = MockDeviceRegistration();
      when(() => registration.register(newDevice())).thenAnswer((_) async => null);
      when(() => registration.unregister(any())).thenAnswer((_) async {});
      service = LocalDeviceService(db, registration);
      await service.addDevice(newDevice(), _defaults);

      await service.removeDevice(userId, 'AA:BB:CC:00:00:09');
      await service.removeDevice(userId, 'AA:BB:CC:00:00:09'); // already gone

      expect(await service.isAdded(userId, 'AA:BB:CC:00:00:09'), isFalse);
      expect(await db.select(db.deviceAlerts).get(), isEmpty);
      verify(() => registration.unregister('AA:BB:CC:00:00:09')).called(1);
    });

    test('rename changes the name', () async {
      final added = await service.addDevice(newDevice(), _defaults);
      await service.rename(added.id, 'Bedroom');

      expect((await service.watchDevices(userId).first).single.name, 'Bedroom');
    });
  });
}
