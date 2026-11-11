import '../decoder/decoded_packet.dart';

/// Device events kept on the phone: sessions started and stopped, and errors. The same in both
/// phases. TODO(phase2): uploaded with the readings.
abstract interface class DeviceEventRepository {
  /// Stores [events]; one already stored (same device, time and kind) is kept once.
  Future<void> addAll(int deviceId, List<DeviceEvent> events);

  /// The device's events from [from] on, oldest first; emits again when one is added.
  Stream<List<DeviceEvent>> watchSince(int deviceId, DateTime from);

  /// Deletes events from before [cutoff]; returns how many.
  Future<int> deleteOlderThan(DateTime cutoff);
}
