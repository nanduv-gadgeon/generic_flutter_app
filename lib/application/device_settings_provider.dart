import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/services/device_service.dart';
import '../domain/validation/device_rules.dart';
import 'auth_controller.dart';

part 'device_settings_provider.g.dart';

/// One of the logged-in user's devices for Device settings (task 1.2.9). Null when there is no such
/// device, it is another user's, or nobody is logged in.
@riverpod
Stream<DeviceDetails?> deviceDetails(Ref ref, int deviceId) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(deviceServiceProvider).watchDevice(user.id, deviceId);
}

/// What Device settings can change. Screens call this, never the database.
@riverpod
class DeviceSettingsController extends _$DeviceSettingsController {
  @override
  void build() {}

  DeviceService get _service => ref.read(deviceServiceProvider);

  /// Saves [name] trimmed. False (nothing saved) when it is not a valid device name.
  Future<bool> rename(int deviceId, String name) async {
    if (!isValidDeviceName(name)) return false;
    await _service.rename(deviceId, name.trim());
    return true;
  }

  Future<void> setAlert(int deviceId, String readingKey, {required bool enabled}) =>
      _service.setAlertEnabled(deviceId, readingKey, enabled: enabled);

  /// Removes the device and its alert limits from the phone (and the cloud in Phase 2).
  Future<void> remove(DeviceDetails device) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;
    await _service.removeDevice(user.id, device.address);
  }
}
