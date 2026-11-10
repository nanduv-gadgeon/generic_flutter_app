import 'dart:typed_data';

import 'decoded_packet.dart';

/// Reads one device's data and builds its commands. Get one with `codecFor(profile)`; each link
/// gets its own instance.
abstract interface class DeviceCodec {
  /// Reading keys the device's data holds; a profile may only list these (and `battery`).
  Set<String> get readingKeys;

  /// Decodes data received from the device, e.g. one BLE notification, from [source] (see
  /// `FrameSource`).
  List<DecodedPacket> feed(Uint8List bytes, {String source});

  /// Bytes to send for the profile command [commandId], with [value] added for commands that take
  /// one. Throws [UnsupportedCommandException], also when [value] is missing or not expected.
  Uint8List encode(String commandId, {int? value});
}

/// The device has no command with this id.
class UnsupportedCommandException implements Exception {
  const UnsupportedCommandException(this.commandId);

  final String commandId;

  @override
  String toString() => 'UnsupportedCommandException: $commandId';
}
