import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/devices/live_readings_service.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';

import '../../fixtures/ppg_motion_link.dart';
import '../../fixtures/ppg_motion_profile.dart';
import '../../fixtures/test_db.dart';

void main() {
  late AppDatabase db;
  late int deviceId;
  late ScriptedLink link;
  late List<(String, Transport, String, String?)> opened;
  late Map<String, DeviceProfile> profiles;

  setUp(() async {
    db = memoryDatabase();
    final userId = await db.usersDao.insertUser(fakeUser());
    deviceId = await db.devicesDao.addDevice(
      fakeDevice(
        userId,
        address: 'AA:BB:CC:00:00:09',
      ).copyWith(profileId: const Value('ppg_motion_v1')),
    );
    link = ScriptedLink();
    opened = [];
    profiles = {'ppg_motion_v1': ppgMotionProfile()};
  });

  LiveReadingsService service() =>
      LiveReadingsService(db, (id) => profiles[id], (profile, transport, id, {lastAddress}) {
        opened.add((profile.id, transport, id, lastAddress));
        return link;
      });

  test('listening connects to the saved device and starts it', () async {
    final updates = <LiveUpdate>[];
    final sub = service().watch(deviceId).listen(updates.add);
    await pumpEventQueue();

    expect(opened.single, ('ppg_motion_v1', Transport.ble, 'AA:BB:CC:00:00:09', null));
    expect(link.sent, [stopCommand, channelsCommand, startCommand]);
    expect(updates.whereType<LiveStatusChanged>().last.status, LiveStatus.streaming);
    await sub.cancel();
  });

  test('cancelling stops the device and disconnects', () async {
    final sub = service().watch(deviceId).listen((_) {});
    await pumpEventQueue();
    link.sent.clear();

    await sub.cancel();

    expect(link.sent, [stopCommand]);
    expect(link.disconnected, isTrue);
  });

  test('a removed device is reported', () async {
    final updates = <LiveUpdate>[];
    final sub = service().watch(deviceId + 1).listen(updates.add);
    await pumpEventQueue();

    expect((updates.single as LiveFailure).reason, LiveFailureReason.unknownDevice);
    expect(opened, isEmpty);
    await sub.cancel();
  });

  test('a device whose type left the config is reported', () async {
    profiles.clear();
    final updates = <LiveUpdate>[];
    final sub = service().watch(deviceId).listen(updates.add);
    await pumpEventQueue();

    expect((updates.single as LiveFailure).reason, LiveFailureReason.unknownDevice);
    await sub.cancel();
  });

  test('a type that cannot connect yet is reported', () async {
    profiles['ppg_motion_v1'] = ppgMotionProfile().copyWith(packet: null);
    final updates = <LiveUpdate>[];
    final sub = service().watch(deviceId).listen(updates.add);
    await pumpEventQueue();

    expect((updates.single as LiveFailure).reason, LiveFailureReason.notSupported);
    await sub.cancel();
  });

  test('cancelling while connecting leaves the device disconnected', () async {
    final slow = _SlowLink();
    link = slow;
    final sub = service().watch(deviceId).listen((_) {});
    await pumpEventQueue();
    await sub.cancel();
    slow.gate.complete();
    await pumpEventQueue();

    expect(slow.sent, isEmpty);
    expect(slow.disconnected, isTrue);
  });
}

/// Connects only when [gate] completes.
class _SlowLink extends ScriptedLink {
  final gate = Completer<void>();

  @override
  Future<void> connect() async {
    await gate.future;
    await super.connect();
  }
}
