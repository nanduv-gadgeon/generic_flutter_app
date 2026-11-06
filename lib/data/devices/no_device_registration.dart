import '../../domain/models/new_device.dart';
import '../../domain/services/device_registration.dart';

/// Phase 1: devices live only on the phone, so there is nothing to register.
class NoDeviceRegistration implements DeviceRegistration {
  const NoDeviceRegistration();

  @override
  Future<CloudRegistration?> register(NewDevice device) async => null;

  @override
  Future<void> unregister(String address) async {}
}
