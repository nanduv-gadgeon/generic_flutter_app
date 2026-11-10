import '../../domain/services/live_readings.dart';

/// Text for a device's live readings screen (stands in for the dashboard, task 1.3.4).
abstract final class DeviceStrings {
  static const fallbackTitle = 'Device';
  static const connecting = 'Connecting…';
  static const starting = 'Starting the device…';
  static const streaming = 'Live';
  static const reconnecting = 'Connection lost. Reconnecting…';
  static const syncing = 'Getting stored readings…';
  static const waiting = 'Device not found. Trying again…';
  static const battery = 'Battery';
  static const tryAgain = 'Try again';
  static const noValue = '–';
  static const noValueSpoken = 'no reading yet';
  static const note =
      'Readings are saved on this phone. The device stays connected until you open another one.';
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

  /// "72 bpm", "1.25 %".
  static String value(double value, int decimals, String unit) {
    final text = value.toStringAsFixed(decimals);
    return unit.isEmpty ? text : '$text $unit';
  }

  /// "Heart rate, 72 bpm" for screen readers.
  static String reading(String label, String? value) => '$label, ${value ?? noValueSpoken}';

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
