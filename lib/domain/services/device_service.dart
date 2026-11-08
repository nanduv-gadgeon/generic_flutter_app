import '../models/device_profile.dart';
import '../models/new_device.dart';
import '../models/user_device.dart';

export '../models/new_device.dart';
export '../models/user_device.dart';

/// The user's devices. Both phases keep them in the local DB; Phase 2 also registers new ones
/// with the cloud.
abstract interface class DeviceService {
  /// The user's devices in their chosen order; emits again whenever they change.
  Stream<List<UserDevice>> watchDevices(int userId);

  /// Saves [device] at the end of the user's list with the alert limits [defaults] (its type's
  /// defaults from the config file), then registers it with the cloud when there is one.
  ///
  /// Throws [DeviceAlreadyAddedException] when the user already has a device at that address.
  Future<AddedDevice> addDevice(NewDevice device, List<AlertRule> defaults);

  Future<void> rename(int deviceId, String name);

  /// Whether the user already has a device at [address].
  Future<bool> isAdded(int userId, String address);

  /// Deletes the user's device at [address] and its alert limits from the phone, then tells the
  /// cloud when there is one. Does nothing when there is no such device.
  Future<void> removeDevice(int userId, String address);
}

class DeviceAlreadyAddedException implements Exception {
  const DeviceAlreadyAddedException();

  @override
  String toString() => 'DeviceAlreadyAddedException';
}
