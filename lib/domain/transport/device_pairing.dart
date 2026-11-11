/// The phone's own pairing with a device (Bluetooth bonding), kept by the operating system.
abstract interface class DevicePairing {
  /// Forgets the pairing with the BLE device at [address], so a removed device does not stay in
  /// the phone's paired list (a stale pairing can stop it sending data when it is added again).
  /// Does nothing when it is not paired, or where the platform has no way to unpair (iOS).
  Future<void> unpair(String address);
}
