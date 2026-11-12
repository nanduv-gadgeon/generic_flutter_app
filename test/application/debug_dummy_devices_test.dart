import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/debug_dummy_devices.dart';
import 'package:generic_flutter_app/application/device_profiles_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/device_profile_registry.dart';
import 'package:generic_flutter_app/core/di/services.dart';

import '../fixtures/add_device_fakes.dart';
import '../fixtures/fake_auth.dart';
import '../fixtures/test_config.dart';

DeviceProfile _profile(String id, String label) =>
    DeviceProfile.fromJson(validProfileJson(id: id)..['label'] = label);

/// The debug-only dummy devices (long-press "My devices" on home).
void main() {
  final band = _profile('band_v1', 'Band');
  final patch = _profile('patch_v1', 'Patch');
  late FakeDeviceService devices;

  setUp(() => devices = FakeDeviceService());

  DummyDevices dummies(List<DeviceProfile> types) =>
      DummyDevices(devices, () async => types, (label) => '$label (test)');

  test('adds one device per offered type, with made-up addresses', () async {
    expect(await dummies([band, patch]).toggle(fakeUser.id), 2);

    expect([for (final d in devices.devices) d.name], ['Band (test)', 'Patch (test)']);
    expect(
      [for (final (d, _) in devices.added) d.address],
      ['AA:BB:CC:DD:00:01', 'AA:BB:CC:DD:00:02'],
    );
  });

  test('ten or more types still get distinct addresses', () {
    expect(DummyDevices.address(9), 'AA:BB:CC:DD:00:09');
    expect(DummyDevices.address(12), 'AA:BB:CC:DD:00:12');
  });

  test('a second toggle removes them all again', () async {
    final toggle = dummies([band, patch, band]);
    await toggle.toggle(fakeUser.id);

    expect(await toggle.toggle(fakeUser.id), -3);
    expect(devices.devices, isEmpty);
  });

  test('adds nothing when the config offers no types', () async {
    expect(await dummies(const []).toggle(fakeUser.id), 0);
    expect(devices.devices, isEmpty);
  });

  // Regression: home reads the provider once without listening, so it is disposed while toggle
  // waits on the (slow, encrypted) database; it then failed with UnmountedRefException.
  test('the provider still works after it is disposed mid-toggle, as on home', () async {
    final slow = _SlowDeviceService();
    final registry = DeviceProfileRegistry(AppConfig.fromJson(validConfigJson()));
    final container = ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWithValue(slow),
        deviceProfileRegistryProvider.overrideWith((ref) async => registry),
      ],
    );
    addTearDown(container.dispose);

    final toggle = container.read(dummyDevicesProvider)((label) => '$label (test)');

    expect(await toggle.toggle(fakeUser.id), 1);
    expect(slow.devices, hasLength(1));
  });
}

/// Like the real database: answers after a moment, not straight away.
class _SlowDeviceService extends FakeDeviceService {
  @override
  Future<bool> isAdded(int userId, String address) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return super.isAdded(userId, address);
  }
}
