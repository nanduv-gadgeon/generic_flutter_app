import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/decoder/time_encoding.dart';
import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/device_link.dart';
import '../../../domain/transport/reconnect_backoff.dart';
import '../link_support.dart';
import 'ble_adapter.dart';
import 'ble_characteristics.dart';
import 'bluetooth_power.dart';

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

  /// Tries at the radio connect of [connect]. Android often refuses a connection right after the
  /// device was disconnected or unpaired (GATT error 133) and accepts the next one.
  static const connectAttempts = 3;

  /// Wait between those tries.
  static const connectRetryDelay = Duration(seconds: 2);

  /// Least time between closing the link to a device and connecting to it again: a device whose
  /// firmware has not finished with the old session can accept everything on the new one and
  /// still send no data (the PPG sensor did, reconnected ~90 ms after closing).
  static const reconnectCooldown = Duration(milliseconds: 1500);

  /// Before reconnecting to a device closed earlier, the link scans until it sees the device
  /// advertising (as the vendor app does, which always connects from a scan), at most this long.
  /// Not shown to the user.
  static const reconnectScanTimeout = Duration(seconds: 5);

  /// When each device's link was last closed, on [_clock]; shared by every link, since each
  /// connection makes a new one.
  static final _closedAt = <String, Duration>{};
  static final _clock = Stopwatch()..start();

  /// Tests only: forgets every close, so no connect waits.
  @visibleForTesting
  static void forgetClosedLinks() => _closedAt.clear();

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
  final _power = BluetoothPower();
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
      await _open(attempts: connectAttempts);
    } catch (_) {
      _wanted = false;
      _setState(LinkState.disconnected);
      rethrow;
    }
    _connectionSub ??= _adapter.connection(deviceId).listen(_onConnection);
    _power.watch(_adapter.availability, onOff: _onBluetoothOff);
  }

  @override
  Future<void> send(List<int> bytes) async {
    final write = _settings.writeUuid;
    if (write == null) throw const LinkException('device takes no commands');
    if (_states.value != LinkState.connected) throw const LinkException('not connected');

    final data = Uint8List.fromList(bytes);
    Future<void> writeOnce() => _adapter.write(
      deviceId,
      _service,
      fullUuid(write),
      data,
      withoutResponse: _settings.writeWithoutResponse,
    );
    try {
      await writeOnce();
    } catch (_) {
      await _delay(writeRetryDelay);
      try {
        await writeOnce();
      } catch (e) {
        throw LinkException('write failed: ${describeError(e)}');
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _wanted = false;
    _stopBatteryPoll();
    await _power.stop();
    await _connectionSub?.cancel();
    _connectionSub = null;
    await _cancelValueSubs();
    try {
      await _adapter.disconnect(deviceId);
    } catch (_) {
      // Already gone; nothing to do.
    }
    _closedAt[deviceId] = _clock.elapsed;
    _setState(LinkState.disconnected);
  }

  /// For a device whose link was closed earlier: waits out the rest of [reconnectCooldown], then
  /// looks for it advertising before connecting.
  Future<void> _waitCooldown() async {
    final closed = _closedAt[deviceId];
    if (closed == null) return;
    final wait = reconnectCooldown - (_clock.elapsed - closed);
    if (wait > Duration.zero) {
      if (kDebugMode) debugPrint('BLE link: waiting ${wait.inMilliseconds} ms before reconnecting');
      await _delay(wait);
    }
    if (_wanted) await _scanForDevice();
  }

  /// Scans for this device's service until the device is seen, for up to [reconnectScanTimeout].
  /// Connects anyway when it is not seen or the scan fails.
  Future<void> _scanForDevice() async {
    final took = Stopwatch()..start();
    try {
      // Listening before the scan starts, so an early result is not missed.
      final seen = _adapter.scanResults
          .firstWhere((d) => d.id == deviceId)
          .timeout(reconnectScanTimeout)
          .then((_) => true, onError: (Object _) => false);
      await _adapter.startScan(
        services: [fullUuid(_settings.scanUuid)],
        namePrefixes: [?_settings.scanNamePrefix],
      );
      final found = await seen;
      if (kDebugMode) {
        debugPrint(
          found
              ? 'BLE link: seen advertising after ${took.elapsedMilliseconds} ms'
              : 'BLE link: not seen in ${reconnectScanTimeout.inSeconds} s, connecting anyway',
        );
      }
    } catch (_) {
      // No scan: connect as before.
    } finally {
      try {
        await _adapter.stopScan();
      } catch (_) {
        // Best effort.
      }
    }
  }

  /// Connects and sets everything up; throws [LinkException] and leaves the device disconnected.
  /// The radio connect is tried up to [attempts] times (the reconnect loop has its own waits).
  Future<void> _open({int attempts = 1}) async {
    try {
      await _waitCooldown();
      if (!_wanted) throw const LinkException('disconnected while connecting');
      await _connectRadio(attempts);
      // Pairs before anything else: a device that asks to pair as soon as it connects drops the
      // first requests made while the user is still typing its key.
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

  /// A refused connection is tried again after [connectRetryDelay]; a timeout is not, since a
  /// device that is off or out of range would only make the user wait longer.
  Future<void> _connectRadio(int attempts) async {
    for (var attempt = 1; ; attempt++) {
      try {
        await _adapter.connect(deviceId);
        return;
      } on TimeoutException {
        rethrow;
      } catch (_) {
        if (attempt >= attempts || !_wanted) rethrow;
      }
      try {
        await _adapter.disconnect(deviceId); // Frees the failed attempt's GATT client.
      } catch (_) {
        // Best effort.
      }
      await _delay(connectRetryDelay);
      if (!_wanted) throw const LinkException('disconnected while connecting');
    }
  }

  Future<void> _requestMtu() async {
    try {
      await _adapter.requestMtu(deviceId, preferredMtu);
    } catch (_) {
      // Best effort: the default size still works for short frames.
    }
  }

  Future<void> _subscribe(Map<String, Set<String>> services) async {
    checkCharacteristics(services, _settings);
    final notify = fullUuid(_settings.notifyUuid);
    final reply = _settings.replyUuid;
    final clock = _settings.timeSync;

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

  /// Bluetooth turned off. The OS sends no disconnect for it, so the link drops what it had and
  /// reconnects once Bluetooth is back (TC-1.2-044); the heartbeat marks it Offline meanwhile.
  void _onBluetoothOff() {
    if (!_wanted) return;
    final wasConnected = _states.value == LinkState.connected;
    unawaited(_dropRadio());
    if (wasConnected) unawaited(_reconnect());
  }

  Future<void> _dropRadio() async {
    await _cancelValueSubs();
    try {
      await _adapter.disconnect(deviceId); // Frees the dead link's GATT client.
    } catch (_) {
      // Best effort.
    }
  }

  /// Waits [ReconnectBackoff] between tries; while Bluetooth is off it waits for it instead, and
  /// starts again from the first, short wait once it is back.
  Future<void> _reconnect() async {
    _setState(LinkState.reconnecting);
    for (var attempt = 0; _wanted; attempt++) {
      if (!_power.isOn) {
        await _power.whenOn();
        attempt = 0;
        if (!_wanted) return;
      }
      await _delay(_backoff.delayFor(attempt));
      if (!_wanted) return;
      if (!_power.isOn) continue;
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
