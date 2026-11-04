import 'dart:typed_data';

enum LinkState { disconnected, connecting, connected, reconnecting }

/// One connected device, over BLE now and local Wi‑Fi from task 1.2.6.
///
/// Screens never use this directly; device services (1.2.7, 1.3.3) do.
abstract interface class DeviceLink {
  /// Starts with the current state.
  Stream<LinkState> get state;

  /// Raw data from the device, for the decoder (1.2.5). Never logged: it holds health readings.
  Stream<Uint8List> get packets;

  /// Battery level in %, when the device reports it.
  Stream<int> get battery;

  /// Connects, pairs if the profile asks, and starts [packets] and [battery].
  ///
  /// After an unexpected drop the link reconnects by itself until [disconnect] is called.
  /// Throws [LinkException].
  Future<void> connect();

  /// Writes a command. Throws [LinkException] when not connected or the write fails.
  Future<void> send(List<int> bytes);

  /// Disconnects and stops reconnecting.
  Future<void> disconnect();
}

/// Connecting to or talking to a device failed.
class LinkException implements Exception {
  const LinkException(this.message);

  /// What failed, without any device data.
  final String message;

  @override
  String toString() => 'LinkException: $message';
}

/// The profile has no connection details for this transport yet (protocol not known).
class NotConnectableException implements Exception {
  const NotConnectableException(this.profileId);

  final String profileId;

  @override
  String toString() => 'NotConnectableException: $profileId';
}
