import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/devices/local_device_service.dart';
import 'package:generic_flutter_app/domain/services/device_registration.dart';
import 'package:generic_flutter_app/domain/transport/device_pairing.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/test_db.dart';

class MockDeviceRegistration extends Mock implements DeviceRegistration {}

class MockDevicePairing extends Mock implements DevicePairing {}

/// Removing a device (Swipe to delete on home, Remove device in settings): its data goes, it is
/// unpaired and the cloud is told.
void main() {
  late AppDatabase db;
  late MockDeviceRegistration registration;
  late MockDevicePairing pairing;
  late LocalDeviceService service;
  late int userId;

  setUp(() async {
    db = memoryDatabase();
    addTearDown(db.close);
    registration = MockDeviceRegistration();
    pairing = MockDevicePairing();
    when(() => registration.unregister(any())).thenAnswer((_) async {});
    when(() => pairing.unpair(any())).thenAnswer((_) async {});
    service = LocalDeviceService(db, registration, pairing);
    userId = await db.usersDao.insertUser(fakeUser());
  });

  /// A device with one alert limit and one stored reading.
  Future<int> deviceWithData(
    int owner, {
    String address = 'AA:BB:CC:00:00:01',
    DeviceTransport transport = DeviceTransport.ble,
  }) async {
    final id = await db.devicesDao.addDevice(
      fakeDevice(owner, address: address).copyWith(transport: Value(transport)),
    );
    await db
        .into(db.deviceAlerts)
        .insert(DeviceAlertsCompanion.insert(deviceId: id, readingKey: 'battery'));
    await db
        .into(db.readings)
        .insert(ReadingsCompanion.insert(deviceId: id, key: 'battery', value: 50, atMs: 1));
    return id;
  }

  test('removeById deletes the device, its alert limits and readings, then unpairs it', () async {
    final id = await deviceWithData(userId);

    await service.removeById(userId, id);

    expect(await db.devicesDao.byId(id), isNull);
    expect(await db.select(db.deviceAlerts).get(), isEmpty);
    expect(await db.select(db.readings).get(), isEmpty);
    verifyInOrder([
      () => pairing.unpair('AA:BB:CC:00:00:01'),
      () => registration.unregister('AA:BB:CC:00:00:01'),
    ]);
  });

  test("removeById leaves another user's device alone", () async {
    final other = await db.usersDao.insertUser(fakeUser(email: 'other@example.com'));
    final theirs = await deviceWithData(other);

    await service.removeById(userId, theirs);

    expect(await db.devicesDao.byId(theirs), isNotNull);
    expect(await db.select(db.readings).get(), hasLength(1));
    verifyNever(() => pairing.unpair(any()));
    verifyNever(() => registration.unregister(any()));
  });

  test('removeById does nothing for a device that is already gone', () async {
    await service.removeById(userId, 999);

    verifyNever(() => pairing.unpair(any()));
    verifyNever(() => registration.unregister(any()));
  });

  test('a Wi‑Fi device is not unpaired', () async {
    final id = await deviceWithData(
      userId,
      address: 'test-device-01',
      transport: DeviceTransport.wifi,
    );

    await service.removeById(userId, id);

    expect(await db.devicesDao.byId(id), isNull);
    verifyNever(() => pairing.unpair(any()));
    verify(() => registration.unregister('test-device-01')).called(1);
  });

  test('a failed unpair still removes the device and tells the cloud', () async {
    when(() => pairing.unpair(any())).thenThrow(StateError('unpair failed'));
    final id = await deviceWithData(userId);

    await service.removeById(userId, id);

    expect(await db.devicesDao.byId(id), isNull);
    verify(() => registration.unregister('AA:BB:CC:00:00:01')).called(1);
  });

  test('removeDevice by address unpairs too', () async {
    await deviceWithData(userId);

    await service.removeDevice(userId, 'AA:BB:CC:00:00:01');

    expect(await service.isAdded(userId, 'AA:BB:CC:00:00:01'), isFalse);
    verify(() => pairing.unpair('AA:BB:CC:00:00:01')).called(1);
  });
}
