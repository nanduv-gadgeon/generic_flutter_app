import 'dart:async';
import 'dart:typed_data';

import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/device_link.dart';
import '../../../domain/transport/lan_address.dart';
import '../../../domain/transport/reconnect_backoff.dart';
import '../../../domain/transport/wifi_device_finder.dart';
import '../link_support.dart';
import 'wifi_channel.dart';

/// [DeviceLink] to a set-up Wi‑Fi device on the local network, from a profile's `wifi` block.
///
/// Finds the device by mDNS on every (re)connect, falling back to its last known IP. Only local
/// hosts are used. Packets are passed on, never logged.
class WifiDeviceLink implements DeviceLink {
  /// Throws [NotConnectableException] when [profile] has no `wifi` block.
  WifiDeviceLink(
    this._finder,
    this._open,
    this._profile,
    this.deviceId, {
    this._lastAddress,
    this._backoff = const ReconnectBackoff(),
    this._delay = realDelay,
  }) : _stream = (_profile.wifi ?? (throw NotConnectableException(_profile.id))).stream;

  final WifiDeviceFinder _finder;
  final WifiChannelOpener _open;
  final DeviceProfile _profile;
  final String deviceId;
  final WifiStream _stream;
  final ReconnectBackoff _backoff;
  final Delay _delay;

  final _states = LinkStates();
  final _packets = StreamController<Uint8List>.broadcast();
  WifiChannel? _channel;
  StreamSubscription<Uint8List>? _frames;
  String? _lastAddress;

  /// False once [disconnect] is called; stops the reconnect loop.
  bool _wanted = false;

  /// The IP the device was last reached at, for the caller to save with the device.
  String? get lastAddress => _lastAddress;

  @override
  Stream<LinkState> get state => _states.stream;

  @override
  Stream<Uint8List> get packets => _packets.stream;

  /// The Wi‑Fi setup contract has no battery level.
  @override
  Stream<int> get battery => const Stream.empty();

  @override
  Future<void> connect() async {
    _wanted = true;
    _states.value = LinkState.connecting;
    try {
      await _openChannel();
    } catch (_) {
      _wanted = false;
      _states.value = LinkState.disconnected;
      rethrow;
    }
  }

  @override
  Future<void> send(List<int> bytes) async {
    final channel = _channel;
    if (channel == null || _states.value != LinkState.connected) {
      throw const LinkException('not connected');
    }
    if (!channel.canSend) throw const LinkException('device takes no commands');
    try {
      await channel.send(Uint8List.fromList(bytes));
    } catch (e) {
      throw LinkException('write failed: ${e.runtimeType}');
    }
  }

  @override
  Future<void> disconnect() async {
    _wanted = false;
    await _closeChannel();
    _states.value = LinkState.disconnected;
  }

  /// Finds and opens the device; throws [LinkException] and leaves nothing open.
  Future<void> _openChannel() async {
    final endpoint = await _endpoint();
    if (!isLanHost(endpoint.host)) throw const LinkException('not a local network address');
    final WifiChannel channel;
    try {
      channel = await _open(endpoint, _stream);
    } catch (e) {
      throw LinkException('connect failed: ${e.runtimeType}');
    }
    _channel = channel;
    _lastAddress = endpoint.host;
    _frames = channel.frames.listen(_packets.add, onDone: _onDropped, onError: (Object _) {});
    _states.value = LinkState.connected;
  }

  Future<WifiEndpoint> _endpoint() async {
    WifiEndpoint? found;
    try {
      found = await _finder.resolve(_profile, deviceId);
    } catch (_) {
      // Treated as not found.
    }
    if (found != null) return found;
    final last = _lastAddress;
    if (last != null) return WifiEndpoint(last);
    throw const LinkException('device not found on the local network');
  }

  void _onDropped() {
    if (_wanted && _states.value == LinkState.connected) unawaited(_reconnect());
  }

  Future<void> _reconnect() async {
    _states.value = LinkState.reconnecting;
    await _closeChannel();
    for (var attempt = 0; _wanted; attempt++) {
      await _delay(_backoff.delayFor(attempt));
      if (!_wanted) return;
      try {
        await _openChannel();
        return;
      } on LinkException {
        // Try again after the next, longer wait.
      }
    }
  }

  Future<void> _closeChannel() async {
    final frames = _frames;
    final channel = _channel;
    _frames = null;
    _channel = null;
    await frames?.cancel();
    try {
      await channel?.close();
    } catch (_) {
      // Already gone.
    }
  }
}
