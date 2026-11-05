import 'dart:typed_data';

import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/wifi_device_finder.dart';

/// One open connection to a Wi‑Fi device's data stream (WebSocket or HTTP poll).
abstract interface class WifiChannel {
  /// Frames from the device, one per message or poll. Ends when the connection drops.
  Stream<Uint8List> get frames;

  /// Whether the device takes commands on this channel.
  bool get canSend;

  /// Throws when sending fails.
  Future<void> send(Uint8List bytes);

  Future<void> close();
}

/// Opens a channel to [endpoint] as [stream] describes; throws when the device does not answer.
typedef WifiChannelOpener = Future<WifiChannel> Function(WifiEndpoint endpoint, WifiStream stream);
