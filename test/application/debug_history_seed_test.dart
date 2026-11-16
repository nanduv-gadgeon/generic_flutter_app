import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/debug_history_seed.dart';
import 'package:generic_flutter_app/domain/devices/demo_history.dart';
import 'package:generic_flutter_app/domain/services/reading_repository.dart';

import '../fixtures/add_device_fakes.dart';
import '../fixtures/fake_auth.dart';
import '../fixtures/ppg_motion_profile.dart';

/// Stores what it is given, batch by batch.
class _Readings implements ReadingRepository {
  final batches = <(int, List<Sample>)>[];

  @override
  Future<void> addAll(int deviceId, List<Sample> samples) async => batches.add((deviceId, samples));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The debug-only History demo device (long-press "History").
void main() {
  final now = DateTime(2026, 10, 26, 10, 42);
  final ppg = ppgMotionProfile();
  late FakeDeviceService devices;
  late _Readings readings;
  late DemoHistorySeed seed;

  setUp(() {
    devices = FakeDeviceService();
    readings = _Readings();
    seed = DemoHistorySeed(devices, readings, () async => ppg, (l) => '$l (demo)', now: () => now);
  });

  test('adds one PPG with a made-up address and stores its week of history', () async {
    final id = await seed.toggle(fakeUser.id);

    expect(id, isNotNull);
    final (device, alerts) = devices.added.single;
    expect(device.address, 'AA:BB:CC:DD:00:50');
    expect(device.profileId, 'ppg_motion_v1');
    expect(device.name, 'PPG + motion sensor (demo)');
    expect(alerts, ppg.alerts);
    final stored = [for (final (_, batch) in readings.batches) ...batch];
    expect(readings.batches.map((b) => b.$1), everyElement(id));
    expect(readings.batches.map((b) => b.$2.length), everyElement(lessThanOrEqualTo(5000)));
    expect(stored.length, demoHistory(now, ppg.readings).length);
  });

  test('a second long-press removes it again, storing nothing', () async {
    await seed.toggle(fakeUser.id);
    readings.batches.clear();

    expect(await seed.toggle(fakeUser.id), isNull);
    expect(devices.devices, isEmpty);
    expect(readings.batches, isEmpty);
  });

  test('its address is outside the range of home\'s test devices', () {
    expect(DemoHistorySeed.address, isNot(startsWith('AA:BB:CC:DD:00:0')));
  });
}
