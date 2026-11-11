import '../../application/add_device/add_device_state.dart';
import '../../domain/models/device_profile.dart';

/// Text for the Add device flow (requirements §4, screens 10–12).
abstract final class AddDeviceStrings {
  static const title = 'Add device';
  static String stepOf(int step) => 'Step $step of 4';
  static const continueLabel = 'Continue';
  static const tryAgain = 'Try again';

  // Step 1
  static const typeHeading = 'What are you adding?';
  static const typeBody = 'Device types available for your organisation.';
  static const comingSoon = 'Coming soon';
  static const loadingTypes = 'Loading device types';

  /// The type card badge, e.g. "Wi‑Fi · BLE", then the type's tier when it has one: "BLE · Medium".
  static String transports(List<Transport> transports, [DeviceTier? tier]) => [
    if (transports.contains(Transport.wifi)) 'Wi‑Fi',
    if (transports.contains(Transport.ble)) 'BLE',
    if (tier != null) _tiers[tier]!,
  ].join(' · ');

  static const _tiers = {
    DeviceTier.minimum: 'Minimum',
    DeviceTier.medium: 'Medium',
    DeviceTier.huge: 'Huge',
  };

  // Step 2
  static const connectionHeading = 'How does it connect?';
  static const connectionBody = 'Options come from the device type settings.';
  static const bluetooth = 'Bluetooth (BLE)';
  static const bluetoothBody = 'Pair a nearby device. Keep it within 1 m.';
  static const wifi = 'Wi‑Fi';
  static const wifiBody = 'Device joins your Wi‑Fi and sends data.';
  static const notSupported = 'Not supported by this device';

  // Step 3, Bluetooth
  static const searching = 'Searching nearby…';
  static const searchingBody = 'Keep the device close and switched on.';
  static const searchingSetup = 'Looking for the device in setup mode…';
  static const scanStopped = 'Search stopped';
  static const scanStoppedBody =
      'Not in the list? Check the device is on and close, then scan again.';
  static const noneFound = 'No devices found. Check the device is on and close, then scan again.';
  static const scanAgain = 'Scan again';
  static String found(int count) => 'Found $count ${count == 1 ? 'device' : 'devices'}';
  static const unknownDevice = 'Unknown device';
  static const connect = 'Connect';
  static const disconnect = 'Disconnect';

  /// "…:7B:21 · -52 dBm": the end of the address and the signal strength.
  static String deviceDetail(String id, int? rssi) {
    final tail = id.length <= 6 ? id : '…${id.substring(id.length - 6)}';
    return rssi == null ? tail : '$tail · $rssi dBm';
  }

  static String connectTo(String name) => 'Connect to $name';
  static String disconnectFrom(String name) => 'Disconnect $name';

  // Step 3, removing a device already added
  static String removeTitle(String name) => 'Remove $name?';
  static const removeBody =
      'It is removed from this phone with its alert settings. You can add it again.';
  static const remove = 'Remove';

  // Step 3, Wi‑Fi
  static const wifiHeading = 'Connect device to Wi‑Fi';
  static const wifiFormBody = 'The device will send data over your network.';
  static const wifiInstructions =
      'Put the device in setup mode as its manual describes, then enter your Wi‑Fi details.';
  static const setupOverBluetooth = 'Over Bluetooth';
  static const setupOverHotspot = 'Device hotspot';
  static const setupMethod = 'Set up';
  static const network = 'Wi‑Fi network';
  static const networkHint = 'Network name (2.4 GHz)';
  static const wifiPassword = 'Wi‑Fi password';
  static const connectDevice = 'Connect device';
  static const enterNetwork = 'Enter the network name (up to 32 characters).';
  static const wifiPasswordLength = 'Wi‑Fi passwords have 8–63 characters, or none.';

  // Step 3, hotspot
  static const hotspotHeading = "Join the device's Wi‑Fi";
  static const hotspotBody = 'Your phone sends the network details to the device over its hotspot.';
  static const hotspotStep1 = 'Open Settings, then Wi‑Fi, on this phone.';
  static String hotspotStep2(String prefix) => 'Join the network whose name starts with "$prefix".';
  static const hotspotStep3 = 'Come back to this app.';
  static const localNetworkNote =
      'If your phone asks to find devices on your local network, allow it so the app can reach '
      'the device.';
  static const hotspotJoined = "I've joined, continue";

  // Step 4, registering
  static const registeringHeading = 'Registering your device';
  static const registeringBody = 'Saving the device on this phone…';
  static const registeringBodyCloud = 'Sharing the device details with the cloud…';
  static const stageConnected = 'Connected to device';
  static const stageSaved = 'Saved on this phone';
  static const stageSentToCloud = 'Device details sent to cloud';
  static const stageKey = 'Device key received';
  static const stageAlerts = 'Alert settings received';
  static const stageDone = 'done';
  static const stageActive = 'in progress';
  static const stageWaiting = 'waiting';
  static String stageStatus(String label, String status) => '$label, $status';

  // Step 4, done
  static const doneHeading = 'Device registered';
  static String doneBody(String type, Transport transport, {required bool cloud}) {
    final link = transport == Transport.wifi ? 'Wi‑Fi' : 'Bluetooth';
    return cloud
        ? '$type paired over $link and registered with the cloud.'
        : '$type paired over $link and saved on this phone.';
  }

  static const deviceKey = 'Device key';
  static const deviceKeyNote =
      'Unique to this device. The app passes it to the cloud library with every reading.';
  static const waitingForCloud = 'Waiting for the cloud';
  static const alertSettings = 'Alert settings';
  static const suggestedByCloud = 'Suggested by cloud AI';
  static const defaultSettings = 'Default settings';
  static const changeLater = 'You can change these later in Device settings.';
  static const deviceName = 'Device name';
  static const enterDeviceName = 'Enter a name of up to 40 characters.';
  static const goToDashboard = 'Go to dashboard';
  static const saving = 'Saving';
  static const deviceAdded = 'Device added';

  /// "Heart rate above" / "Battery below".
  static String alertLabel(String reading, AlertRule rule) =>
      '$reading ${rule.above != null ? 'above' : 'below'}';

  /// "110 bpm", "37.8 °C", "15 %".
  static String alertValue(AlertRule rule, String unit) {
    final value = rule.above ?? rule.below ?? 0;
    final text = value == value.roundToDouble() ? value.toInt().toString() : value.toString();
    return unit.isEmpty ? text : '$text $unit';
  }

  /// Hides the middle of a device key: `DK-7F3A-9C2E-4B18-0D51` gives `DK-7F3A-••••-••••-0D51`.
  static String maskedKey(String key) {
    if (key.length <= 11) return key;
    return '${key.substring(0, 7)}-••••-••••-${key.substring(key.length - 4)}';
  }

  /// Device dashboard until its task builds it.
  static const dashboardPlaceholder = 'Device dashboard (later task)';

  static String error(AddDeviceError error) => switch (error) {
    AddDeviceError.bluetoothPermission =>
      'Bluetooth permission is needed to find devices. Allow it in Settings, then try again.',
    AddDeviceError.scanFailed => 'Could not search for devices. Check Bluetooth is on.',
    AddDeviceError.connectFailed => 'Could not connect. Keep the device close and try again.',
    AddDeviceError.alreadyAdded => 'This device is already in your list.',
    AddDeviceError.deviceNotReachable =>
      "Could not reach the device. Check your phone is on the device's Wi‑Fi.",
    AddDeviceError.deviceNoAnswer => 'The device did not answer. Check it is in setup mode.',
    AddDeviceError.setupFailed =>
      'The device could not join the network. Check the name and password.',
    AddDeviceError.saveFailed => 'Could not save the device. Please try again.',
    AddDeviceError.removeFailed => 'Could not remove the device. Try again.',
  };
}
