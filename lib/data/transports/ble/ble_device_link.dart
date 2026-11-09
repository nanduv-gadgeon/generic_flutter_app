import 'dart:async';
import 'dart:typed_data';

import '../../../domain/decoder/time_encoding.dart';
import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/device_link.dart';
import '../../../domain/transport/reconnect_backoff.dart';
import '../link_support.dart';
import 'ble_adapter.dart';

export '../link_support.dart' show Delay;

/// [DeviceLink] over BLE, set up from a profile's `ble` block.
///
/// Packets and battery values are passed on, never logged.
class BleDeviceLink implements DeviceLink {
  BleDeviceLink(
    this._adapter,
    this.deviceId,
    this._settings, {
    this._backoff = const ReconnectBackoff(),
    this._delay = realDelay,
    this._now = DateTime.now,
  });

  /// Wait before the one retry of a failed write (as in the IEF protocol).
  static const writeRetryDelay = Duration(milliseconds: 100);

  /// Asked for after connecting, so a whole data frame fits in one notification. 517 is the
  /// Android maximum; the device may agree to less. iOS negotiates by itself.
  static const preferredMtu = 517;

  final BleAdapter _adapter;
  final String deviceId;
  final BleSettings _settings;
  final ReconnectBackoff _backoff;
  final Delay _delay;

  /// The time written to the device's clock on connect.
  final DateTime Function() _now;

  final _states = LinkStates();
  final _packets = StreamController<DevicePacket>.broadcast();
  final _battery = StreamController<int>.broadcast();
  final _valueSubs = <StreamSubscription<Uint8List>>[];
  StreamSubscription<bool>? _connectionSub;
  Timer? _batteryPoll;

  /// False once [disconnect] is called; stops the reconnect loop.
  bool _wanted = false;

  String get _service => fullUuid(_settings.serviceUuid);

  @override
  Stream<LinkState> get state => _states.stream;

  @override
  Stream<DevicePacket> get packets => _packets.stream;

  @override
  Stream<int> get battery => _battery.stream;

  @override
  Future<void> connect() async {
    _wanted = true;
    _setState(LinkState.connecting);
    try {
      await _open();
    } catch (_) {
      _wanted = false;
      _setState(LinkState.disconnected);
      rethrow;
    }
    _connectionSub ??= _adapter.connection(deviceId).listen(_onConnection);
  }

  @override
  Future<void> send(List<int> bytes) async {
    final write = _settings.writeUuid;
    if (write == null) throw const LinkException('device takes no commands');
    if (_states.value != LinkState.connected) throw const LinkException('not connected');

    final data = Uint8List.fromList(bytes);
    try {
      await _adapter.write(
        deviceId,
        _service,
        fullUuid(write),
        data,
        withoutResponse: _settings.writeWithoutResponse,
      );
    } catch (_) {
      await _delay(writeRetryDelay);
      try {
        await _adapter.write(
          deviceId,
          _service,
          fullUuid(write),
          data,
          withoutResponse: _settings.writeWithoutResponse,
        );
      } catch (e) {
        throw LinkException('write failed: ${describeError(e)}');
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _wanted = false;
    _stopBatteryPoll();
    await _connectionSub?.cancel();
    _connectionSub = null;
    await _cancelValueSubs();
    try {
      await _adapter.disconnect(deviceId);
    } catch (_) {
      // Already gone; nothing to do.
    }
    _setState(LinkState.disconnected);
  }

  /// Connects and sets everything up; throws [LinkException] and leaves the device disconnected.
  Future<void> _open() async {
    try {
      await _adapter.connect(deviceId);
      if (_settings.bond) await _adapter.pair(deviceId);
      final services = await _adapter.discover(deviceId);
      await _requestMtu();
      await _subscribe(services);
    } catch (e) {
      try {
        await _adapter.disconnect(deviceId);
      } catch (_) {
        // Best effort.
      }
      throw e is LinkException ? e : LinkException('connect failed: ${describeError(e)}');
    }
    _setState(LinkState.connected);
  }

  Future<void> _requestMtu() async {
    try {
      await _adapter.requestMtu(deviceId, preferredMtu);
    } catch (_) {
      // Best effort: the default size still works for short frames.
    }
  }

  Future<void> _subscribe(Map<String, Set<String>> services) async {
    final characteristics = services[_service];
    if (characteristics == null) throw const LinkException('device has no data service');
    final notify = fullUuid(_settings.notifyUuid);
    if (!characteristics.contains(notify)) {
      throw const LinkException('device has no data characteristic');
    }
    final write = _settings.writeUuid;
    if (write != null && !characteristics.contains(fullUuid(write))) {
      throw const LinkException('device has no command characteristic');
    }
    final reply = _settings.replyUuid;
    if (reply != null && !characteristics.contains(fullUuid(reply))) {
      throw const LinkException('device has no reply characteristic');
    }
    final clock = _settings.timeSync;
    if (clock != null && !characteristics.contains(fullUuid(clock.uuid))) {
      throw const LinkException('device has no clock characteristic');
    }

    await _cancelValueSubs();
    await _listen(notify, FrameSource.data);
    if (reply != null) await _listen(fullUuid(reply), FrameSource.reply);
    if (clock != null) {
      final time = Uint8List.fromList(encodeTime(clock.fields, _now()));
      await _adapter.write(
        deviceId,
        _service,
        fullUuid(clock.uuid),
        time,
        withoutResponse: _settings.writeWithoutResponse,
      );
    }
    await _subscribeBattery(services);
  }

  /// Passes on what [characteristic] notifies as packets from [source].
  Future<void> _listen(String characteristic, String source) async {
    // Listen before subscribing so the first value is not missed.
    _valueSubs.add(
      _adapter
          .values(deviceId, characteristic)
          .listen((bytes) => _packets.add((bytes: bytes, source: source))),
    );
    await _adapter.subscribe(deviceId, _service, characteristic);
  }

  Future<void> _subscribeBattery(Map<String, Set<String>> services) async {
    final battery = fullUuid(batteryServiceUuid);
    final level = fullUuid(batteryLevelUuid);
    if (!_settings.batteryService || !(services[battery]?.contains(level) ?? false)) return;
    _valueSubs.add(_adapter.values(deviceId, level).listen(_addBattery));
    _addBattery(await _adapter.read(deviceId, battery, level));
    try {
      await _adapter.subscribe(deviceId, battery, level);
    } catch (_) {
      // Some devices only allow reading the level; the value read above still counts.
    }
    final poll = _settings.batteryPollSeconds;
    if (poll == null) return;
    _batteryPoll = Timer.periodic(Duration(seconds: poll), (_) async {
      try {
        _addBattery(await _adapter.read(deviceId, battery, level));
      } catch (_) {
        // Try again at the next tick; a lost link is handled by the connection stream.
      }
    });
  }

  void _addBattery(Uint8List value) {
    if (value.isNotEmpty) _battery.add(value.first.clamp(0, 100));
  }

  void _onConnection(bool connected) {
    if (!connected && _wanted && _states.value == LinkState.connected) unawaited(_reconnect());
  }

  Future<void> _reconnect() async {
    _setState(LinkState.reconnecting);
    for (var attempt = 0; _wanted; attempt++) {
      await _delay(_backoff.delayFor(attempt));
      if (!_wanted) return;
      try {
        await _open();
        return;
      } on LinkException {
        // Try again after the next, longer wait.
      }
    }
  }

  void _stopBatteryPoll() {
    _batteryPoll?.cancel();
    _batteryPoll = null;
  }

  Future<void> _cancelValueSubs() async {
    _stopBatteryPoll();
    for (final sub in _valueSubs) {
      await sub.cancel();
    }
    _valueSubs.clear();
  }

  void _setState(LinkState state) => _states.value = state;
}
