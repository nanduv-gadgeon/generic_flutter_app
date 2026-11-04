import '../models/user_device.dart';

export '../models/user_device.dart';

/// The user's devices. Both phases keep them in the local DB; Phase 2 also registers new ones
/// with the cloud. Add device (task 1.2.7) adds its methods here.
abstract interface class DeviceService {
  /// The user's devices in their chosen order; emits again whenever they change.
  Stream<List<UserDevice>> watchDevices(int userId);
}
