import '../../domain/services/live_readings.dart';

/// Connection and problem text on a device's dashboard. The dashboard's views use `app_en.arb`.
abstract final class DeviceStrings {
  static const fallbackTitle = 'Device';
  static const connecting = 'Connecting…';
  static const starting = 'Starting the device…';
  static const streaming = 'Live';
  static const reconnecting = 'Connection lost. Reconnecting…';
  static const syncing = 'Getting stored readings…';
  static const waiting = 'Device not found. Trying again…';
  static const tryAgain = 'Try again';
  static const offlineNeverHeard = 'Offline · no data from the device yet.';
  static const placeFinger = 'Place your finger on the sensor';
  static const measuring = 'Measuring… hold still';

  /// What to tell the user about the sensor, or null while readings are coming.
  static String? contact(SensorContact? contact) => switch (contact) {
    SensorContact.none => placeFinger,
    SensorContact.settling => measuring,
    SensorContact.ok || null => null,
  };

  static String status(LiveStatus status) => switch (status) {
    LiveStatus.connecting => connecting,
    LiveStatus.starting => starting,
    LiveStatus.streaming => streaming,
    LiveStatus.reconnecting => reconnecting,
    LiveStatus.syncing => syncing,
    LiveStatus.waiting => waiting,
  };

  /// "Offline · last heartbeat 5 min ago." Text, not only the colour, says it is offline.
  static String offline(Duration? sinceLast) {
    if (sinceLast == null) return offlineNeverHeard;
    final s = sinceLast.isNegative ? 0 : sinceLast.inSeconds;
    final ago = s < 60
        ? '$s s'
        : s < 3600
        ? '${s ~/ 60} min'
        : '${s ~/ 3600} h';
    return 'Offline · last heartbeat $ago ago.';
  }

  /// "72 bpm", "1.25 %".
  static String value(double value, int decimals, String unit) {
    final text = value.toStringAsFixed(decimals);
    return unit.isEmpty ? text : '$text $unit';
  }

  static String failure(LiveFailure failure) => switch (failure.problem) {
    DeviceProblem.lowBattery => 'The device battery is low. Charge it, then try again.',
    DeviceProblem.charging => 'The device is on its charger. Take it off, then try again.',
    DeviceProblem.sensorError => 'The device sensor is not responding. Restart the device.',
    DeviceProblem.transferError => 'The device stopped sending. Try again.',
    null => switch (failure.reason) {
      LiveFailureReason.unknownDevice => 'This device is no longer in your list.',
      LiveFailureReason.notSupported => 'Live readings are not available for this device yet.',
      LiveFailureReason.connectFailed =>
        'Could not connect. Keep the device close and switched on.',
      LiveFailureReason.startFailed => 'The device did not start. Try again.',
      LiveFailureReason.deviceProblem => 'The device reported a problem. Try again.',
    },
  };
}
