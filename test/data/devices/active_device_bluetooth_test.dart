import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/devices/active_device.dart';
import 'package:generic_flutter_app/data/devices/heartbeat_recorder.dart';
import 'package:generic_flutter_app/data/devices/reading_writer.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/permissions/permission_problem.dart';
import 'package:generic_flutter_app/domain/services/heartbeat_repository.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';
import 'package:generic_flutter_app/domain/services/reading_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/ppg_motion_link.dart';
import '../../fixtures/ppg_motion_profile.dart';
import '../../fixtures/test_db.dart';

class _MockReadingRepository extends Mock implements ReadingRepository {}

class _MockHeartbeatRepository extends Mock implements HeartbeatRepository {}

const _address = 'AA:BB:CC:00:00:09';

/// A BLE device is only connected when Bluetooth can be used; [ActiveDevice.close] for
/// Disconnect device. Fake devices only.
void main() {
  late AppDatabase db;
  late int deviceId;
  late ScriptedLink link;
  late List<String> opened;
  late List<bool> asks;
  late List<PermissionProblem?> answers;
  late ActiveDevice active;

  setUpAll(() {
    registerFallbackValue(<Sample>[]);
    registerFallbackValue(DateTime.utc(2026));
  });

  setUp(() async {
    db = memoryDatabase();
    final userId = await db.usersDao.insertUser(fakeUser());
    deviceId = await db.devicesDao.addDevice(
      fakeDevice(userId, address: _address).copyWith(profileId: const Value('ppg_motion_v1')),
    );
    link = ScriptedLink();
    opened = [];
    asks = [];
    answers = [];
    final readings = _MockReadingRepository();
    when(() => readings.addAll(any(), any())).thenAnswer((_) async {});
    final heartbeats = _MockHeartbeatRepository();
    when(() => heartbeats.add(any(), any(), batteryPercent: any(named: 'batteryPercent')))
        .thenAnswer((_) async {});
    active = ActiveDevice(
      db,
      (id) => id == 'ppg_motion_v1' ? ppgMotionProfile() : null,
      (profile, transport, address, {lastAddress}) {
        opened.add(address);
        return link;
      },
      (id, _) => ReadingWriter(id, readings, (_, _) async {}),
      (id, settings) =>
          HeartbeatRecorder(id, heartbeats, (_, _) async {}, interval: settings.interval),
      delay: (_) async {},
      bluetoothReady: ({required ask}) async {
        asks.add(ask);
        return answers.isEmpty ? null : answers.removeAt(0);
      },
    );
    await active.start(userId);
  });
  tearDown(() => active.stop());

  // what the phone says first -> the failure shown (it connects once Bluetooth can be used)
  final problems = {
    'permission refused': const PermissionProblem.refused(AppPermission.bluetooth),
    'permission refused for good': const PermissionProblem.refused(
      AppPermission.bluetooth,
      blocked: true,
    ),
    'Bluetooth off': const PermissionProblem.bluetoothOff(),
  };
  for (final MapEntry(key: name, value: problem) in problems.entries) {
    test('$name: says so, does not open the link, then connects when it can', () async {
      answers = [problem, problem];
      final updates = <LiveUpdate>[];
      final sub = active.watch(deviceId).listen(updates.add);
      await pumpEventQueue();

      final failure = updates.whereType<LiveFailure>().first;
      expect((failure.reason, failure.permission), (LiveFailureReason.bluetooth, problem));
      // The prompt only on the first try; background retries only check.
      expect(asks, [true, false, false]);
      expect(opened, [_address]); // only once it could
      expect(updates.whereType<LiveStatusChanged>().last.status, LiveStatus.streaming);
      await sub.cancel();
    });
  }

  test('close disconnects the connected device, without Offline', () async {
    final updates = <LiveUpdate>[];
    final sub = active.watch(deviceId).listen(updates.add);
    await pumpEventQueue();

    await active.close(deviceId);

    expect(link.disconnected, isTrue);
    expect(active.activeId, isNull);
    expect(updates.whereType<LiveHeartbeat>().where((h) => !h.online), isEmpty);
    await sub.cancel();
  });

  test('close of another device leaves the connected one alone', () async {
    final sub = active.watch(deviceId).listen((_) {});
    await pumpEventQueue();

    await active.close(deviceId + 1);

    expect(link.disconnected, isFalse);
    expect(active.activeId, deviceId);
    await sub.cancel();
  });
}
