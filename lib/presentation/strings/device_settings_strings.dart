import '../../domain/models/device_profile.dart';

/// Text for Device settings and its Remove device sheet (task 1.2.9).
abstract final class DeviceSettingsStrings {
  static const title = 'Device settings';

  /// The button that opens this screen (device dashboard header).
  static const open = 'Device settings';
  static const notFound = 'This device is no longer on this phone.';

  /// Shown for a value the app does not have yet.
  static const none = '—';

  // Sections
  static const connection = 'Connection';
  static const heartbeat = 'Heartbeat';
  static const sampling = 'Sampling interval';
  static const alerts = 'Alerts';

  // Connection
  static const type = 'Type';
  static const connectionRow = 'Connection';
  static const macAddress = 'MAC address';
  static const ipAddress = 'IP address';
  static const signal = 'Signal (RSSI)';
  static const firmwareRow = 'Firmware';
  static const batteryRow = 'Battery';
  static String transport(Transport t) => switch (t) {
    Transport.ble => 'Bluetooth LE',
    Transport.wifi => 'Wi‑Fi',
  };
  static String addressLabel(Transport t) => t == Transport.ble ? macAddress : ipAddress;
  static String firmware(String version) => 'v$version';
  static String battery(int percent) => '$percent%';

  // Heartbeat
  static const heartbeatInterval = 'Heartbeat interval';
  static const lastHeartbeat = 'Last heartbeat';
  static const offlineAfter = 'Offline after';
  static const deviceStatus = 'Device status';

  /// "12 s ago", "5 min ago", "2 h ago", "3 days ago"; a time in the future counts as now.
  static String ago(Duration elapsed) {
    final s = elapsed.isNegative ? 0 : elapsed.inSeconds;
    if (s < 60) return '$s s ago';
    if (s < 3600) return '${s ~/ 60} min ago';
    if (s < 86400) return '${s ~/ 3600} h ago';
    final days = s ~/ 86400;
    return days == 1 ? '1 day ago' : '$days days ago';
  }

  // Sampling interval (not changeable yet)
  static const samplingOptions = ['1 s', '5 s', '30 s', '1 min'];
  static const samplingLater = 'Set by the device for now.';

  // Alerts
  /// The battery limit is not one of a profile's readings.
  static const batteryAlert = 'Battery';
  static const batteryUnit = '%';

  // Remove: the sheet and its messages are shared with home (RemoveDeviceStrings).
  static const removing = 'Removing device';
}
