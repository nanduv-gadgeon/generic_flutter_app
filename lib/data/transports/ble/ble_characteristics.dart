import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/device_link.dart';

/// Throws [LinkException] unless the device's [services] (service UUID -> its characteristic
/// UUIDs, as discovered) have the data service and every characteristic [settings] names.
void checkCharacteristics(Map<String, Set<String>> services, BleSettings settings) {
  final characteristics = services[fullUuid(settings.serviceUuid)];
  if (characteristics == null) throw const LinkException('device has no data service');
  bool has(String uuid) => characteristics.contains(fullUuid(uuid));
  if (!has(settings.notifyUuid)) throw const LinkException('device has no data characteristic');
  if (settings.writeUuid case final write? when !has(write)) {
    throw const LinkException('device has no command characteristic');
  }
  if (settings.replyUuid case final reply? when !has(reply)) {
    throw const LinkException('device has no reply characteristic');
  }
  if (settings.timeSync case final clock? when !has(clock.uuid)) {
    throw const LinkException('device has no clock characteristic');
  }
}
