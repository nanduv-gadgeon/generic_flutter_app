import 'dart:async';
import 'dart:typed_data';

import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/device_link.dart';
import '../../../domain/transport/reconnect_backoff.dart';
import 'ble_adapter.dart';

/// Waits for [duration]; replaced in tests so they run without real timers.
typedef Delay = Future<void> Function(Duration duration);

Future<void> _wait(Duration duration) => Future<void>.delayed(duration);

/// [DeviceLink] over BLE, set up from a profile's `ble` block.
///
/// Packets and battery values are passed on, never logged.
class BleDeviceLink implements DeviceLink {
  BleDeviceLink(
    this._adapter,
    this.deviceId,
    this._settings, {
    this._backoff = const ReconnectBackoff(),
    this._delay = _wait,
  });

  /// Wait before the one retry of a failed write (as in the IEF protocol).
  static const writeRetryDelay = Duration(milliseconds: 100);

  final BleAdapter _adapter;
  final String deviceId;
  final BleSettings _settings;
  final ReconnectBackoff _backoff;
  final Delay _delay;

  final _states = StreamController<LinkState>.broadcast();
  final _packets = StreamController<Uint8List>.broadcast();
  final _battery = StreamController<int>.broadcast();
  final _valueSubs = <StreamSubscription<Uint8List>>[];
  StreamSubscription<bool>? _connectionSub;

  LinkState _state = LinkState.disconnected;

  /// False once [disconnect] is called; stops the reconnect loop.
  bool _wanted = false;

  String get _service => fullUuid(_settings.serviceUuid);

  /// Takes the current state and the change stream together when listened to, so no change is
  /// lost in between.
  @override
  Stream<LinkState> get state {
    StreamSubscription<LinkState>? changes;
    late final StreamController<LinkState> controller;
    controller = StreamController(
      onListen: () {
        controller.add(_state);
        changes = _states.stream.listen(controller.add);
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Stream<Uint8List> get packets => _packets.stream;

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
    if (_state != LinkState.connected) throw const LinkException('not connected');

    final data = Uint8List.fromList(bytes);
    try {
      await _adapter.write(deviceId, _service, fullUuid(write), data);
    } catch (_) {
      await _delay(writeRetryDelay);
      try {
        await _adapter.write(deviceId, _service, fullUuid(write), data);
      } catch (e) {
        throw LinkException('write failed: ${e.runtimeType}');
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _wanted = false;
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
      await _subscribe(services);
    } catch (e) {
      try {
        await _adapter.disconnect(deviceId);
      } catch (_) {
        // Best effort.
      }
      throw e is LinkException ? e : LinkException('connect failed: ${e.runtimeType}');
    }
    _setState(LinkState.connected);
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

    await _cancelValueSubs();
    // Listen before subscribing so the first value is not missed.
    _valueSubs.add(_adapter.values(deviceId, notify).listen(_packets.add));
    await _adapter.subscribe(deviceId, _service, notify);

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
  }

  void _addBattery(Uint8List value) {
    if (value.isNotEmpty) _battery.add(value.first.clamp(0, 100));
  }

  void _onConnection(bool connected) {
    if (!connected && _wanted && _state == LinkState.connected) unawaited(_reconnect());
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

  Future<void> _cancelValueSubs() async {
    for (final sub in _valueSubs) {
      await sub.cancel();
    }
    _valueSubs.clear();
  }

  void _setState(LinkState state) {
    if (state == _state) return;
    _state = state;
    _states.add(state);
  }
}
