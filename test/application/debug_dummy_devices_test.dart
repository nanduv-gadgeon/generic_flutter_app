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

  test('adds four devices with made-up addresses, cycling through the types', () async {
    expect(await dummies([band, patch]).toggle(fakeUser.id), DummyDevices.count);

    expect(
      [for (final d in devices.devices) d.name],
      ['Band (test)', 'Patch (test)', 'Band (test)', 'Patch (test)'],
    );
    expect(
      [for (final (d, _) in devices.added) d.address],
      [for (var n = 1; n <= DummyDevices.count; n++) DummyDevices.address(n)],
    );
  });

  test('a second toggle removes them again', () async {
    final toggle = dummies([band]);
    await toggle.toggle(fakeUser.id);

    expect(await toggle.toggle(fakeUser.id), -DummyDevices.count);
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

    expect(await toggle.toggle(fakeUser.id), DummyDevices.count);
    expect(slow.devices, hasLength(DummyDevices.count));
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
