import '../models/new_device.dart';

/// Registers a newly added device with the cloud (Phase 2). Phase 1 registers nothing.
abstract interface class DeviceRegistration {
  /// The device key and suggested alerts, or null when there is no cloud or it did not answer.
  /// Never throws: the device is already saved on the phone.
  Future<CloudRegistration?> register(NewDevice device);

  /// Tells the cloud the device at [address] was removed. Never throws: it is already gone from
  /// the phone.
  Future<void> unregister(String address);
}
