import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/devices/demo_devices.dart';
import '../domain/models/device_profile.dart';
import '../domain/services/device_service.dart';
import 'device_profiles_provider.dart';

part 'debug_dummy_devices.g.dart';

/// Debug builds only (home's hidden long-press): one fake device per offered type, for trying the
/// device list and every dashboard without hardware. They are saved like real devices, through
/// [DeviceService], with made-up addresses, so they can never connect; a demo feed plays made-up
/// readings for them instead. Release builds never offer this.
class DummyDevices {
  DummyDevices(this._devices, this._offered, this._name);

  final DeviceService _devices;

  /// The device types the config offers, in order.
  final Future<List<DeviceProfile>> Function() _offered;

  /// The name a dummy of a device type gets, from its type label.
  final String Function(String typeLabel) _name;

  /// Made-up addresses; nothing real uses the `AA:BB:CC:DD` range.
  static String address(int n) => demoAddress(n);

  /// Adds one dummy per offered type, or removes them when they are there. Returns how many were
  /// added (> 0) or removed (< 0).
  Future<int> toggle(int userId) async {
    if (await _devices.isAdded(userId, address(1))) {
      var removed = 0;
      for (var n = 1; await _devices.isAdded(userId, address(n)); n++) {
        await _devices.removeDevice(userId, address(n));
        removed++;
      }
      return -removed;
    }
    final types = await _offered();
    for (final (i, type) in types.indexed) {
      final n = i + 1;
      await _devices.addDevice(
        NewDevice(
          userId: userId,
          profileId: type.id,
          transport: Transport.ble,
          address: address(n),
          name: _name(type.label),
        ),
        type.alerts,
      );
    }
    return types.length;
  }
}

/// [DummyDevices] for the app's device service and config. [name] comes from the screen's strings.
@riverpod
DummyDevices Function(String Function(String typeLabel) name) dummyDevices(Ref ref) {
  final service = ref.watch(deviceServiceProvider);
  // Taken now: home reads this provider once without listening, so it is disposed while toggle
  // runs, and its ref can no longer be used then.
  final registry = ref.watch(deviceProfileRegistryProvider.future);
  return (name) => DummyDevices(service, () async => (await registry).offered, name);
}
