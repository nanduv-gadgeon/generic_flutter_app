import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/devices/active_device.dart';
import 'package:generic_flutter_app/data/devices/heartbeat_recorder.dart';
import 'package:generic_flutter_app/data/devices/reading_writer.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/services/heartbeat_repository.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';
import 'package:generic_flutter_app/domain/services/reading_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/ief_profile.dart';
import '../../fixtures/ppg_motion_link.dart';
import '../../fixtures/ppg_motion_profile.dart';
import '../../fixtures/test_db.dart';

class MockReadingRepository extends Mock implements ReadingRepository {}

class MockHeartbeatRepository extends Mock implements HeartbeatRepository {}

const _sensorAddress = 'AA:BB:CC:00:00:09';
const _patchAddress = 'AA:BB:CC:00:00:0A';

void main() {
  late AppDatabase db;
  late int userId;
  late int sensorId;
  late int patchId;
  late Map<String, ScriptedLink> links;
  late List<String> opened;
  late Map<String, DeviceProfile> profiles;
  late MockReadingRepository readings;
  late MockHeartbeatRepository heartbeats;
  late List<Duration> waits;
  late ActiveDevice active;

  HeartbeatRecorder recorderFor(int deviceId, HeartbeatSettings settings) => HeartbeatRecorder(
    deviceId,
    heartbeats,
    (id, seenAt) => db.devicesDao.updateStatus(id, lastHeartbeatAt: seenAt),
    interval: settings.interval,
  );

  setUpAll(() {
    registerFallbackValue(<Sample>[]);
    registerFallbackValue(DateTime.utc(2026));
  });

  setUp(() async {
    db = memoryDatabase();
    userId = await db.usersDao.insertUser(fakeUser());
    sensorId = await db.devicesDao.addDevice(
      fakeDevice(userId, address: _sensorAddress).copyWith(profileId: const Value('ppg_motion_v1')),
    );
    patchId = await db.devicesDao.addDevice(
      fakeDevice(userId, address: _patchAddress).copyWith(profileId: const Value('ief_device_v1')),
    );
    links = {_sensorAddress: ScriptedLink(), _patchAddress: ScriptedLink()..answer = (_) => null};
    opened = [];
    profiles = {'ppg_motion_v1': ppgMotionProfile(), 'ief_device_v1': iefProfile()};
    readings = MockReadingRepository();
    when(() => readings.addAll(any(), any())).thenAnswer((_) async {});
    heartbeats = MockHeartbeatRepository();
    when(() => heartbeats.add(any(), any(), batteryPercent: any(named: 'batteryPercent')))
        .thenAnswer((_) async {});
    waits = [];
    active = ActiveDevice(
      db,
      (id) => profiles[id],
      (profile, transport, address, {lastAddress}) {
        opened.add(address);
        return links[address]!;
      },
      (deviceId, _) => ReadingWriter(
        deviceId,
        readings,
        (id, percent) => db.devicesDao.updateStatus(id, batteryPercent: percent),
      ),
      recorderFor,
      delay: (d) async => waits.add(d),
    );
    await active.start(userId);
  });
  tearDown(() => active.stop());

  ScriptedLink sensor() => links[_sensorAddress]!;
  ScriptedLink patch() => links[_patchAddress]!;

  test('watching connects the saved device and starts it', () async {
    final updates = <LiveUpdate>[];
    final sub = active.watch(sensorId).listen(updates.add);
    await pumpEventQueue();

    expect(opened, [_sensorAddress]);
    expect(sensor().sent, [stopCommand, channelsCommand, startCommand]);
    expect(updates.whereType<LiveStatusChanged>().last.status, LiveStatus.streaming);
    await sub.cancel();
  });

  test('two screens watching the same device share one connection', () async {
    final a = active.watch(sensorId).listen((_) {});
    await pumpEventQueue();
    final b = active.watch(sensorId).listen((_) {});
    await pumpEventQueue();

    expect(opened, [_sensorAddress]);
    await a.cancel();
    await b.cancel();
  });

  test(
    'leaving the screen keeps the device connected, and a new screen sees the last state',
    () async {
      final first = active.watch(sensorId).listen((_) {});
      await pumpEventQueue();
      sensor().sendBattery(77);
      await first.cancel();
      await pumpEventQueue();

      expect(sensor().disconnected, isFalse);
      final updates = <LiveUpdate>[];
      final again = active.watch(sensorId).listen(updates.add);
      await pumpEventQueue();

      expect(opened, [_sensorAddress]);
      expect((updates.first as LiveStatusChanged).status, LiveStatus.streaming);
      expect(updates.whereType<LiveValue>().map((v) => (v.sample.key, v.sample.value)), [
        ('battery', 77.0),
      ]);
      await again.cancel();
    },
  );

  test('watching another device stops and disconnects the first, then connects it', () async {
    final sub = active.watch(sensorId).listen((_) {});
    await pumpEventQueue();
    sensor().sent.clear();

    final other = active.watch(patchId).listen((_) {});
    await pumpEventQueue();

    expect(sensor().sent, [stopCommand]);
    expect(sensor().disconnected, isTrue);
    expect(opened, [_sensorAddress, _patchAddress]);
    expect(active.activeId, patchId);
    await sub.cancel();
    await other.cancel();
  });

  test('readings are stored; the battery and "Seen" are saved on the device row', () async {
    final sub = active.watch(patchId).listen((_) {});
    await pumpEventQueue();
    patch()
      ..data(iefLogFrame)
      ..data(iefSyncDone)
      ..sendBattery(64);
    await pumpEventQueue();
    await active.stop(); // flushes

    final stored = verify(() => readings.addAll(patchId, captureAny())).captured.single;
    expect(stored, [Sample('current', 30.07, iefT0)]);
    final row = (await db.devicesDao.byId(patchId))!;
    expect(row.batteryPercent, 64);
    expect(row.lastHeartbeatAt, isNotNull);
    verify(() => heartbeats.add(patchId, any(), batteryPercent: any(named: 'batteryPercent')));
    await sub.cancel();
  });

  test('removing the connected device disconnects it', () async {
    final sub = active.watch(sensorId).listen((_) {});
    await pumpEventQueue();

    await db.devicesDao.deleteDevice(sensorId);
    await pumpEventQueue();

    expect(sensor().disconnected, isTrue);
    expect(active.activeId, isNull);
    await sub.cancel();
  });

  test('logging out disconnects the device', () async {
    final sub = active.watch(sensorId).listen((_) {});
    await pumpEventQueue();

    await active.stop();

    expect(sensor().disconnected, isTrue);
    expect(active.activeId, isNull);
    await sub.cancel();
  });

  test('a device out of reach is tried again after 5, 15, 30, then every 60 s', () async {
    sensor().failConnect = true;
    final updates = <LiveUpdate>[];
    final gate = Completer<void>();
    var attempts = 0;
    active = ActiveDevice(
      db,
      (id) => profiles[id],
      (profile, transport, address, {lastAddress}) => links[address]!,
      (deviceId, _) => ReadingWriter(deviceId, readings, (_, _) async {}),
      recorderFor,
      delay: (d) async {
        waits.add(d);
        if (++attempts == 5) {
          sensor().failConnect = false;
          gate.complete();
        }
      },
    );
    final sub = active.watch(sensorId).listen(updates.add);
    await gate.future;
    await pumpEventQueue();

    expect(waits, const [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(seconds: 60),
      Duration(seconds: 60),
    ]);
    expect(
      updates.whereType<LiveStatusChanged>().map((u) => u.status),
      contains(LiveStatus.waiting),
    );
    expect(updates.whereType<LiveStatusChanged>().last.status, LiveStatus.streaming);
    await sub.cancel();
  });

  test('Try again connects the device from the start', () async {
    final sub = active.watch(sensorId).listen((_) {});
    await pumpEventQueue();

    await active.retry(sensorId);
    await pumpEventQueue();

    expect(opened, [_sensorAddress, _sensorAddress]);
    await sub.cancel();
  });

  final failures =
      <String, (void Function(Map<String, DeviceProfile>), int Function(), LiveFailureReason)>{
        'a removed device': ((_) {}, () => 999, LiveFailureReason.unknownDevice),
        'a type no longer in the config': (
          (p) => p.clear(),
          () => sensorId,
          LiveFailureReason.unknownDevice,
        ),
        'a type that cannot connect yet': (
          (p) => p['ppg_motion_v1'] = ppgMotionProfile().copyWith(packet: null),
          () => sensorId,
          LiveFailureReason.notSupported,
        ),
      };
  for (final MapEntry(key: name, value: (change, id, reason)) in failures.entries) {
    test('$name is reported', () async {
      change(profiles);
      final updates = <LiveUpdate>[];
      final sub = active.watch(id()).listen(updates.add);
      await pumpEventQueue();

      expect((updates.single as LiveFailure).reason, reason);
      expect(opened, isEmpty);
      await sub.cancel();
    });
  }

  test('tells which device is connected, switching when another is opened', () async {
    final links = <ActiveLink?>[];
    final watching = active.watchActive().listen(links.add);
    await pumpEventQueue();
    final a = active.watch(sensorId).listen((_) {});
    await pumpEventQueue();
    final b = active.watch(patchId).listen((_) {});
    await pumpEventQueue();
    await active.stop();

    expect(links.first, isNull);
    expect(links, contains((deviceId: sensorId, status: LiveStatus.streaming, online: true)));
    expect(links.indexOf(null, 1), lessThan(links.indexWhere((l) => l?.deviceId == patchId)));
    expect(links, contains((deviceId: patchId, status: LiveStatus.syncing, online: true)));
    expect(links.last, isNull);
    await watching.cancel();
    await a.cancel();
    await b.cancel();
  });
}
