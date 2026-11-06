import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/wifi_device_finder.dart';
import '../link_support.dart';
import 'wifi_channel.dart';

/// [WifiChannel] that polls `GET <stream.path>` every `stream.pollSeconds`; each non-empty body is
/// one frame. A failed poll ends [frames], so the link reconnects.
class HttpPollChannel implements WifiChannel {
  HttpPollChannel._(this._dio, this._endpoint, this._stream, this._delay);

  /// Polls once to check the device answers (throws if not), then keeps polling.
  static Future<HttpPollChannel> open(
    Dio dio,
    WifiEndpoint endpoint,
    WifiStream stream, {
    Delay delay = realDelay,
  }) async {
    final channel = HttpPollChannel._(dio, endpoint, stream, delay);
    channel._emit(await channel._poll());
    unawaited(channel._loop());
    return channel;
  }

  final Dio _dio;
  final WifiEndpoint _endpoint;
  final WifiStream _stream;
  final Delay _delay;

  /// Holds frames until the link listens.
  final _frames = StreamController<Uint8List>();
  bool _closed = false;

  @override
  Stream<Uint8List> get frames => _frames.stream;

  @override
  bool get canSend => _stream.commandPath != null;

  @override
  Future<void> send(Uint8List bytes) async {
    final path = _stream.commandPath;
    if (path == null) throw StateError('no command path');
    await _dio.postUri<void>(
      _uri(path),
      data: bytes,
      options: Options(contentType: 'application/octet-stream'),
    );
  }

  @override
  Future<void> close() async {
    _closed = true;
    // Not awaited: with no listener the done event is never delivered.
    if (!_frames.isClosed) unawaited(_frames.close());
  }

  Future<void> _loop() async {
    final interval = Duration(seconds: _stream.pollSeconds ?? 1);
    while (!_closed) {
      await _delay(interval);
      if (_closed) return;
      try {
        _emit(await _poll());
      } catch (_) {
        break; // The device stopped answering.
      }
    }
    await close();
  }

  Future<Uint8List> _poll() async {
    final response = await _dio.getUri<List<int>>(
      _uri(_stream.path),
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  void _emit(Uint8List frame) {
    if (frame.isNotEmpty && !_frames.isClosed) _frames.add(frame);
  }

  Uri _uri(String path) =>
      Uri(scheme: 'http', host: _endpoint.host, port: _endpoint.port, path: path);
}
