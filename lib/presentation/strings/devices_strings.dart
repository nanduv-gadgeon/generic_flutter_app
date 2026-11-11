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

  // Device cards (mockup 06_home).
  static const addADevice = 'Add a device';
  static const noReadings = 'No readings yet';
  static const offline = 'Offline';
  static const bluetooth = 'BLE';
  static const wifi = 'Wi‑Fi';
  static const connected = 'Connected';
  static const connecting = 'Connecting…';
  static const notSeen = 'Not seen yet';

  /// "Bluetooth · Connected".
  static String link(String transport, String state) => '$transport · $state';

  /// "SpO₂ 97 % · Heart rate 72 bpm".
  static String quickReading(List<String> parts) => parts.join(' · ');

  /// "78%".
  static String battery(int percent) => '$percent%';

  /// "Battery 78%" for screen readers.
  static String batterySpoken(int percent) => 'Battery $percent%';

  /// "Seen 12 s ago", "Seen 5 min ago", "Seen 3 h ago", "Seen 2 d ago".
  static String seen(Duration ago) {
    final d = ago.isNegative ? Duration.zero : ago;
    if (d.inMinutes < 1) return 'Seen ${d.inSeconds} s ago';
    if (d.inHours < 1) return 'Seen ${d.inMinutes} min ago';
    if (d.inDays < 1) return 'Seen ${d.inHours} h ago';
    return 'Seen ${d.inDays} d ago';
  }

  /// One phrase for a whole card, then what tapping does.
  static String card(List<String> parts) => '${parts.join(', ')}. Opens the device';

  // Reorder (mockup 09_home_reorder)
  static const reorder = 'Reorder';
  static const reorderLabel = 'Reorder devices';
  static const done = 'Done';
  static const doneLabel = 'Done reordering';
  static const reorderHint = 'Press and drag ≡ to change the order of your devices.';

  /// What a screen reader says for a device's drag handle; arrow keys move it too.
  static String reorderHandle(String name) => 'Reorder $name. Use the arrow keys to move it';

  /// One row of the reorder list, e.g. "Smart Band S2, Smart band".
  static String reorderRow(String name, String type) => '$name, $type';

  // Debug builds only: dummy devices for testing the list (long-press "My devices").
  static String dummyName(String typeLabel) => '$typeLabel (test)';

  static String dummyChanged(int change) => change > 0
      ? 'Added $change test devices.'
      : change < 0
      ? 'Removed ${-change} test devices.'
      : 'No device types to add.';

  static const dummyFailed = 'Could not change the test devices.';
}
