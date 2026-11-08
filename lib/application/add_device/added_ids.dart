import '../../domain/services/device_service.dart';
import '../../domain/transport/ble_scanner.dart';

/// The ids in [found] that [userId] has already added, for "Disconnect" on the scan list.
Future<Set<String>> addedIds(DeviceService devices, int userId, List<FoundDevice> found) async => {
  for (final d in found)
    if (await devices.isAdded(userId, d.id)) d.id,
};
