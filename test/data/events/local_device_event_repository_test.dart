import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/events/local_device_event_repository.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';

import '../../fixtures/test_db.dart';

void main() {
  late AppDatabase db;
  late LocalDeviceEventRepository repo;
  late int deviceId;
  late int otherId;
  final t = DateTime.utc(2026, 11, 11, 9);
  DateTime at(int minutes) => t.add(Duration(minutes: minutes));

  setUp(() async {
    db = memoryDatabase();
    repo = LocalDeviceEventRepository(db);
    final userId = await db.usersDao.insertUser(fakeUser());
    deviceId = await db.devicesDao.addDevice(fakeDevice(userId));
    otherId = await db.devicesDao.addDevice(fakeDevice(userId, address: 'AA:BB:CC:00:00:02'));
  });
  tearDown(() => db.close());

  test('stores events per device and reads them back oldest first, in UTC', () async {
    await repo.addAll(deviceId, [
      DeviceEvent(DeviceEventKind.stop, at(30), code: 0),
      DeviceEvent(DeviceEventKind.start, at(0).toLocal(), code: 0),
      DeviceEvent(DeviceEventKind.error, at(10), code: 0x21),
    ]);
    await repo.addAll(otherId, [DeviceEvent(DeviceEventKind.start, at(5), code: 0)]);

    expect(await repo.watchSince(deviceId, t).first, [
      DeviceEvent(DeviceEventKind.start, at(0), code: 0),
      DeviceEvent(DeviceEventKind.error, at(10), code: 0x21),
      DeviceEvent(DeviceEventKind.stop, at(30), code: 0),
    ]);
  });

  test('an event synced twice is stored once, and unknown events are not stored', () async {
    final start = DeviceEvent(DeviceEventKind.start, at(0), code: 0);
    await repo.addAll(deviceId, [start, DeviceEvent(DeviceEventKind.unknown, at(1), code: 9)]);
    await repo.addAll(deviceId, [start]);

    expect(await repo.watchSince(deviceId, t).first, [start]);
  });

  test('watching gives only events from the start time on, and emits again on new ones', () async {
    await repo.addAll(deviceId, [DeviceEvent(DeviceEventKind.start, at(-60), code: 0)]);
    final seen = <int>[];
    final sub = repo.watchSince(deviceId, t).listen((events) => seen.add(events.length));
    await pumpEventQueue();
    await repo.addAll(deviceId, [DeviceEvent(DeviceEventKind.stop, at(1), code: 0)]);
    await pumpEventQueue();
    await sub.cancel();

    expect(seen, [0, 1]);
  });

  test('deletes events from before the cutoff and says how many', () async {
    await repo.addAll(deviceId, [
      for (final days in [0, 6, 8, 30])
        DeviceEvent(DeviceEventKind.error, at(-days * 1440), code: 1),
    ]);

    expect(await repo.deleteOlderThan(t.subtract(const Duration(days: 7))), 2);
    expect(await repo.watchSince(deviceId, DateTime.utc(2000)).first, hasLength(2));
  });

  test('removing a device removes its events', () async {
    await repo.addAll(deviceId, [DeviceEvent(DeviceEventKind.start, t, code: 0)]);
    await db.devicesDao.deleteDevice(deviceId);

    expect(await db.select(db.deviceEvents).get(), isEmpty);
  });
}
