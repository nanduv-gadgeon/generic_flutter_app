export '../alerts/alert.dart';

/// Raises alerts from each device's alert limits (the config's conditions) and missed heartbeats,
/// for the device that is connected: stores them and passes them to the notifier. The same in
/// both phases.
abstract interface class AlertEngine {
  /// Starts watching [userId]'s devices. Connects nothing.
  Future<void> start(int userId);

  /// Stops (logged out).
  Future<void> stop();
}

/// Raises nothing: alerts are turned off in the config (`features.alerts`).
class NoAlertEngine implements AlertEngine {
  const NoAlertEngine();

  @override
  Future<void> start(int userId) async {}

  @override
  Future<void> stop() async {}
}
