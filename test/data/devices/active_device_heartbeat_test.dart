import 'package:drift/drift.dart' show Value;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Heartbeats of the connected device: every 10 s, Offline after 2 missed (20 s of silence).
void main() {
  final t0 = DateTime.utc(2026, 11, 11, 9);
  const heartbeat = HeartbeatSettings(intervalSeconds: 10, offlineAfterMissed: 2);

  setUpAll(() {
    registerFallbackValue(<Sample>[]);
    registerFallbackValue(t0);
  });

  /// Runs [body] on fake time with the sensor and the patch saved, and the sensor watched.
  void withSensor(
    void Function(
      FakeAsync async,
      ActiveDevice active,
      ScriptedLink sensor,
      List<LiveUpdate> updates,
      List<ActiveLink?> links,
      ({int sensor, int patch}) ids,
    )
    body,
  ) {
    fakeAsync((async) {
      final db = memoryDatabase();
      late int sensorId;
      late int patchId;
      () async {
        final userId = await db.usersDao.insertUser(fakeUser());
        sensorId = await db.devicesDao.addDevice(
          fakeDevice(
            userId,
            address: _sensorAddress,
          ).copyWith(profileId: const Value('ppg_motion_v1')),
        );
        patchId = await db.devicesDao.addDevice(
          fakeDevice(
            userId,
            address: _patchAddress,
          ).copyWith(profileId: const Value('ief_device_v1')),
        );
      }();
      async.flushMicrotasks();

      final readings = MockReadingRepository();
      when(() => readings.addAll(any(), any())).thenAnswer((_) async {});
      final heartbeats = MockHeartbeatRepository();
      when(() => heartbeats.add(any(), any(), batteryPercent: any(named: 'batteryPercent')))
          .thenAnswer((_) async {});
      final sensor = ScriptedLink();
      final links = {_sensorAddress: sensor, _patchAddress: ScriptedLink()..answer = (_) => null};
      final profiles = {
        'ppg_motion_v1': ppgMotionProfile().copyWith(heartbeat: heartbeat),
        'ief_device_v1': iefProfile().copyWith(heartbeat: heartbeat),
      };
      final active = ActiveDevice(
        db,
        (id) => profiles[id],
        (profile, transport, address, {lastAddress}) => links[address]!,
        (id, _) => ReadingWriter(id, readings, (_, _) async {}),
        (id, settings) => HeartbeatRecorder(
          id,
          heartbeats,
          (_, _) async {},
          interval: settings.interval,
          now: () => t0.add(async.elapsed),
        ),
        now: () => t0.add(async.elapsed),
      );
      final updates = <LiveUpdate>[];
      final activeLinks = <ActiveLink?>[];
      active.watchActive().listen(activeLinks.add);
      active.watch(sensorId).listen(updates.add);
      async.flushMicrotasks();

      body(async, active, sensor, updates, activeLinks, (sensor: sensorId, patch: patchId));
      active.stop();
      async.flushMicrotasks();
      db.close();
      async.flushMicrotasks();
    });
  }

  List<bool> online(List<LiveUpdate> updates) => [
    for (final u in updates)
      if (u is LiveHeartbeat) u.online,
  ];

  test('silence for the offline window turns the device Offline', () {
    withSensor((async, active, sensor, updates, links, _) {
      expect(updates.whereType<LiveStatusChanged>().last.status, LiveStatus.streaming);
      async.elapse(const Duration(seconds: 19));
      expect(online(updates), [true]); // The replay's state only.

      async.elapse(const Duration(seconds: 2));
      expect(online(updates), [true, false]);
      expect(links.last?.online, isFalse);
      expect(sensor.disconnected, isFalse); // No automatic reconnect.
    });
  });

  final beats = <String, void Function(ScriptedLink)>{
    'a battery level': (s) => s.sendBattery(70),
    'a data packet': (s) => s.data(ppgFrame((_) => 1000, (_) => 1000)),
    'a command reply': (s) => s.reply(const [0x5A, 0x5A, 0x02, 0x20, 0x02]),
  };
  for (final MapEntry(key: name, value: send) in beats.entries) {
    test('$name counts as a heartbeat and brings the device back Online', () {
      withSensor((async, active, sensor, updates, links, _) {
        for (var i = 0; i < 3; i++) {
          async.elapse(const Duration(seconds: 9));
          send(sensor);
        }
        expect(online(updates), [true]);

        async.elapse(const Duration(seconds: 30));
        send(sensor);
        async.flushMicrotasks();

        expect(online(updates), [true, false, true]);
        expect(links.last?.online, isTrue);
      });
    });
  }

  test('a screen opened later sees that the device is Offline, and since when', () {
    withSensor((async, active, sensor, updates, links, ids) {
      sensor.sendBattery(70);
      final heardAt = t0.add(async.elapsed);
      async.elapse(const Duration(seconds: 40));

      final later = <LiveUpdate>[];
      active.watch(ids.sensor).listen(later.add);
      async.flushMicrotasks();

      final replayed = later.whereType<LiveHeartbeat>().single;
      expect(replayed.online, isFalse);
      expect(replayed.lastAt, heardAt);
    });
  });

  test('opening another device stops watching the first one', () {
    withSensor((async, active, sensor, updates, links, ids) {
      active.watch(ids.patch).listen((_) {});
      async.flushMicrotasks();
      final before = online(updates).length;

      async.elapse(const Duration(minutes: 5));

      expect(online(updates).length, before); // The sensor is no longer monitored.
    });
  });
}
