import '../models/device_profile.dart';

/// The home network a device should join. Never logged or stored: [toString] hides the password.
class WifiCredentials {
  const WifiCredentials({required this.ssid, required this.password});

  final String ssid;
  final String password;

  /// The body of the "Wi‑Fi setup contract" (docs/protocols/README.md).
  Map<String, String> toJson() => {'ssid': ssid, 'password': password};

  @override
  String toString() => 'WifiCredentials(ssid: $ssid, password: ***)';
}

/// What the device replied after it accepted the credentials.
class ProvisionResult {
  const ProvisionResult({required this.deviceId, required this.address});

  /// The device's own id; it announces itself under this name by mDNS.
  final String deviceId;

  /// Its IP on the home network; used when mDNS finds nothing.
  final String address;

  @override
  bool operator ==(Object other) =>
      other is ProvisionResult && other.deviceId == deviceId && other.address == address;

  @override
  int get hashCode => Object.hash(deviceId, address);

  @override
  String toString() => 'ProvisionResult($deviceId, $address)';
}

/// Setting up the device's Wi‑Fi failed.
class ProvisioningException implements Exception {
  const ProvisioningException(this.reason);

  /// What failed, never the credentials.
  final String reason;

  @override
  String toString() => 'ProvisioningException: $reason';
}

/// Gives a Wi‑Fi device the home network's name and password (Add device step 2).
abstract interface class WifiProvisioner {
  /// Sends [credentials] by [method] and waits for the device's reply.
  ///
  /// [bleDeviceId] is the device found by [BleScanner.scanForSetup]; needed for [WifiSetupMethod.ble].
  /// For [WifiSetupMethod.softap] the phone must already be on the device's hotspot.
  /// Throws [ProvisioningException], or [NotConnectableException] without a `wifi` block.
  Future<ProvisionResult> provision(
    DeviceProfile profile,
    WifiSetupMethod method,
    WifiCredentials credentials, {
    String? bleDeviceId,
  });
}
