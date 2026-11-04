/// Text for the devices (home) screens.
abstract final class DevicesStrings {
  /// "Good morning," before 12:00, "Good afternoon," before 17:00, else "Good evening,".
  static String greeting(DateTime now) => switch (now.hour) {
    < 12 => 'Good morning,',
    < 17 => 'Good afternoon,',
    _ => 'Good evening,',
  };

  /// The first word of [fullName], or the whole name if it has one word.
  static String firstName(String fullName) {
    final name = fullName.trim();
    final space = name.indexOf(' ');
    return space < 0 ? name : name.substring(0, space);
  }

  static const addDevice = 'Add device';

  static const totalDevices = 'Devices';
  static const totalConnected = 'Connected';
  static const totalAlerts = 'Alerts';

  /// One screen reader phrase per total, e.g. "0 Devices".
  static String total(int count, String label) => '$count $label';

  static const myDevices = 'My devices';
  static const noDevices = 'No devices yet';
  static const noDevicesBody = 'Add your first device to start monitoring.';
}
