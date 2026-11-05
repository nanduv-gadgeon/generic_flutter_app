import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../domain/transport/wifi_device_finder.dart';
import 'wifi_channel.dart';

/// [WifiChannel] over a WebSocket: binary messages are frames; text messages are ignored.
class WsChannel implements WifiChannel {
  WsChannel._(this._channel);

  /// Connects to `ws://<endpoint><path>`; throws when the device does not answer within [timeout].
  static Future<WsChannel> open(
    WifiEndpoint endpoint,
    String path, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final channel = WebSocketChannel.connect(
      Uri(scheme: 'ws', host: endpoint.host, port: endpoint.port, path: path),
    );
    try {
      await channel.ready.timeout(timeout);
    } catch (_) {
      unawaited(channel.sink.close());
      rethrow;
    }
    return WsChannel._(channel);
  }

  final WebSocketChannel _channel;

  @override
  Stream<Uint8List> get frames => _channel.stream
      .where((message) => message is List<int>)
      .map((message) => message is Uint8List ? message : Uint8List.fromList(message as List<int>));

  @override
  bool get canSend => true;

  @override
  Future<void> send(Uint8List bytes) async => _channel.sink.add(bytes);

  @override
  Future<void> close() => _channel.sink.close();
}
