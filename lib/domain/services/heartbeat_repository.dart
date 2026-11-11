/// Heartbeats kept on the phone: when each device was heard from, with its battery level then.
/// The same in both phases. TODO(phase2): uploaded with the readings.
abstract interface class HeartbeatRepository {
  Future<void> add(int deviceId, DateTime at, {int? batteryPercent});

  /// Deletes heartbeats from before [cutoff]; returns how many.
  Future<int> deleteOlderThan(DateTime cutoff);
}
