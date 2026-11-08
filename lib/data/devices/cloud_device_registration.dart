import '../../core/config/config_sections.dart';
import '../../domain/models/new_device.dart';
import '../../domain/services/device_registration.dart';

/// Phase 2 device registration. Empty hook until the cloud API exists.
class CloudDeviceRegistration implements DeviceRegistration {
  const CloudDeviceRegistration(this.config);

  final CloudConfig config;

  @override
  Future<CloudRegistration?> register(NewDevice device) async {
    // TODO(phase2): POST /devices with the profile id, transport and address; return the device
    // key and suggested alert settings. Return null on any failure, the device is already saved.
    return null;
  }

  @override
  Future<void> unregister(String address) async {
    // TODO(phase2): DELETE /devices/{key} and stop its upload. Ignore failures, the device is
    // already removed from the phone.
  }
}
