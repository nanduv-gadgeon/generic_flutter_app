import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/devices/local_device_service.dart';
import 'package:generic_flutter_app/data/devices/no_device_registration.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:generic_flutter_app/domain/transport/device_pairing.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/test_db.dart';

class _MockDevicePairing extends Mock implements DevicePairing {}

/// LocalDeviceService for Device settings (task 1.2.9). Fake data only.
void main() {
  late AppDatabase db;
  late LocalDeviceService service;
  late int userId;

  setUp(() async {
    db = memoryDatabase();
    final pairing = _MockDevicePairing();
    when(() => pairing.unpair(any())).thenAnswer((_) async {});
    service = LocalDeviceService(db, const NoDeviceRegistration(), pairing);
    userId = await db.usersDao.insertUser(fakeUser());
  });

  NewDevice newDevice(Transport transport, {String? ip}) => NewDevice(
    userId: userId,
    profileId: 'test_device_v1',
    transport: transport,
    address: transport == Transport.ble ? 'AA:BB:CC:00:00:01' : 'test-device-01',
    ipAddress: ip,
    name: 'Test band',
  );

  const defaults = [AlertRule(key: 'heart_rate', above: 110), AlertRule(key: 'battery', below: 15)];

  test('watchDevice maps a BLE device with its status and alerts', () async {
    final added = await service.addDevice(newDevice(Transport.ble), defaults);
    await db.devicesDao.updateStatus(
      added.id,
      batteryPercent: 78,
      firmware: '1.4.2',
      lastHeartbeatAt: DateTime(2026, 1, 1, 9),
    );

    expect(
      await service.watchDevice(userId, added.id).first,
      DeviceDetails(
        id: added.id,
        name: 'Test band',
        profileId: 'test_device_v1',
        transport: Transport.ble,
        address: 'AA:BB:CC:00:00:01',
        firmware: '1.4.2',
        batteryPercent: 78,
        lastHeartbeatAt: DateTime(2026, 1, 1, 9),
        alerts: const [
          AlertSetting(rule: AlertRule(key: 'battery', below: 15), enabled: true),
          AlertSetting(rule: AlertRule(key: 'heart_rate', above: 110), enabled: true),
        ],
      ),
    );
  });

  test('watchDevice maps a Wi‑Fi device with its IP address', () async {
    final added = await service.addDevice(newDevice(Transport.wifi, ip: '192.168.0.10'), []);

    final details = (await service.watchDevice(userId, added.id).first)!;

    expect(
      (details.transport, details.address, details.ipAddress),
      (Transport.wifi, 'test-device-01', '192.168.0.10'),
    );
  });

  test('watchDevice gives null for another user', () async {
    final added = await service.addDevice(newDevice(Transport.ble), defaults);
    final other = await db.usersDao.insertUser(fakeUser(email: 'other@example.com'));

    expect(await service.watchDevice(other, added.id).first, isNull);
  });

  test('setAlertEnabled turns one alert off', () async {
    final added = await service.addDevice(newDevice(Transport.ble), defaults);

    await service.setAlertEnabled(added.id, 'heart_rate', enabled: false);

    final details = (await service.watchDevice(userId, added.id).first)!;
    expect(
      {for (final a in details.alerts) a.rule.key: a.enabled},
      {'battery': true, 'heart_rate': false},
    );
  });
}
