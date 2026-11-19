import 'dart:async';

import '../../domain/decoder/generic_codec.dart';
import '../../domain/heartbeat/heartbeat_monitor.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/permissions/permission_problem.dart';
import '../../domain/services/live_readings.dart';
import '../../domain/transport/device_link.dart';
import '../db/app_database.dart';
import 'active_entry.dart';
import 'heartbeat_recorder.dart';
import 'live_session.dart';
import 'reading_writer.dart';

/// Opens a link to the device of type [profile] over [transport]; [lastAddress] is a Wi‑Fi
/// device's last IP.
typedef LinkOpener = DeviceLink Function(
  DeviceProfile profile,
  Transport transport,
  String deviceId, {
  String? lastAddress,
});

/// Makes the writer that stores a connected device's readings and events.
typedef WriterFor = ReadingWriter Function(int deviceId, DeviceProfile profile);

/// Makes the recorder that saves a connected device's heartbeats.
typedef RecorderFor = HeartbeatRecorder Function(int deviceId, HeartbeatSettings settings);

/// Null when Bluetooth can be used; with [ask] the phone's permission prompt may show.
typedef BluetoothReady = Future<PermissionProblem?> Function({required bool ask});

/// [LiveConnections] with at most one device connected at a time: watching a device connects it, and
/// watching another one disconnects the first. Leaving its screen keeps it connected and storing
/// readings, until another device is watched, it is removed, or the user logs out ([stop]).
///
/// Any data from the device is a heartbeat. After the profile's number of missed intervals it is
/// Offline (no automatic reconnect: the link's own reconnect keeps running) until data returns.
class ActiveDevice implements LiveConnections {
  ActiveDevice(
    this._db,
    this._profileFor,
    this._openLink,
    this._writerFor,
    this._recorderFor, {
    Future<void> Function(Duration)? delay,
    this._now,
    this._bluetoothReady,
  }) : _delay = delay ?? Future.delayed;

  final AppDatabase _db;

  /// The profile with an id, or null when the config no longer has it.
  final DeviceProfile? Function(String id) _profileFor;
  final LinkOpener _openLink;
  final WriterFor _writerFor;
  final RecorderFor _recorderFor;
  final Future<void> Function(Duration) _delay;
  final DateTime Function()? _now;

  /// Checked before each BLE connection attempt; null skips the check (tests).
  final BluetoothReady? _bluetoothReady;

  /// Waits between attempts when the device cannot be reached; the last one repeats.
  static const retryWaits = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  final _updates = StreamController<(int, LiveUpdate)>.broadcast(sync: true);
  final _activeLinks = StreamController<ActiveLink?>.broadcast(sync: true);
  ActiveLink? _link;
  StreamSubscription<List<Device>>? _devices;
  Future<void> _switching = Future.value();
  ActiveEntry? _active;

  /// The id of the connected (or connecting) device, if any.
  int? get activeId => _active?.deviceId;

  @override
  Future<void> start(int userId) async {
    await _devices?.cancel();
    _devices = _db.devicesDao.watchForUser(userId).listen((devices) {
      final id = activeId;
      if (id != null && !devices.any((d) => d.id == id)) unawaited(_select(null));
    });
  }

  @override
  Future<void> stop() async {
    await _devices?.cancel();
    _devices = null;
    await _select(null);
  }

  @override
  Stream<(int, LiveUpdate)> watchAll() => _updates.stream;

  @override
  Stream<LiveUpdate> watch(int deviceId) {
    StreamSubscription<(int, LiveUpdate)>? sub;
    late final StreamController<LiveUpdate> out;
    out = StreamController(
      onListen: () async {
        if (activeId != deviceId) await _select(deviceId);
        if (out.isClosed || !out.hasListener) return;
        // What happened before this screen opened, then what happens next.
        _active?.replay.forEach(out.add);
        sub = _updates.stream.where((u) => u.$1 == deviceId).listen((u) => out.add(u.$2));
      },
      onCancel: () => sub?.cancel(), // The device stays connected.
    );
    return out.stream;
  }

  @override
  Stream<ActiveLink?> watchActive() async* {
    yield _link;
    yield* _activeLinks.stream;
  }

  void _setLink(ActiveLink? link) {
    if (link == _link) return;
    _link = link;
    _activeLinks.add(link);
  }

  @override
  Future<void> retry(int deviceId) async {
    if (activeId == deviceId) await _select(null);
    await _select(deviceId);
  }

  @override
  Future<void> close(int deviceId) async {
    if (activeId == deviceId) await _select(null);
  }

  @override
  Future<void> runAction(int deviceId, List<ActionStep> steps) async {
    final session = _active?.deviceId == deviceId ? _active?.session : null;
    if (session == null) throw const LinkException('not connected');
    await session.runAction(steps);
  }

  /// Disconnects the current device, then connects [deviceId] (or nothing), one switch at a time.
  Future<void> _select(int? deviceId) => _switching = _switching.then((_) async {
    if (deviceId != null && activeId == deviceId) return;
    final old = _active;
    _active = null;
    _setLink(null);
    await old?.close();
    if (deviceId != null) _active = await _open(deviceId);
  });

  Future<ActiveEntry> _open(int deviceId) async {
    late final ActiveEntry active;
    active = ActiveEntry(deviceId, (u) {
      if ((u is LiveStatusChanged || u is LiveHeartbeat) && _active?.deviceId == deviceId) {
        _setLink(active.link);
      }
      _updates.add((deviceId, u));
    });
    final row = await _db.devicesDao.byId(deviceId);
    final profile = row == null ? null : _profileFor(row.profileId);
    if (row == null || profile == null) {
      active.emit(const LiveFailure(LiveFailureReason.unknownDevice));
      return active;
    }
    active.writer = _writerFor(deviceId, profile);
    final heartbeat = profile.heartbeatOrDefault;
    active.recorder = _recorderFor(deviceId, heartbeat);
    active.monitor = HeartbeatMonitor(heartbeat, (online, lastAt) {
      // Offline reaches the alert engine through [watchAll].
      active.emit(LiveHeartbeat(online: online, lastAt: lastAt));
    }, now: _now)..start();
    _active = active; // Its first statuses already count as the active link.
    unawaited(_connect(active, profile, row, 0));
    return active;
  }

  Future<void> _connect(ActiveEntry active, DeviceProfile profile, Device row, int attempt) async {
    final transport = Transport.values.byName(row.transport.name);
    final ready = _bluetoothReady;
    if (transport == Transport.ble && ready != null) {
      // The prompt only on the first attempt; background retries just check.
      final problem = await ready(ask: attempt == 0);
      if (active.closed) return;
      if (problem != null) {
        active.emit(LiveFailure(LiveFailureReason.bluetooth, permission: problem));
        return _retryLater(active, profile, row, attempt);
      }
    }
    final LiveSession session;
    final DeviceLink link;
    final out = StreamController<LiveUpdate>(sync: true);
    try {
      final codec = codecFor(profile, now: _now);
      link = _openLink(profile, transport, row.address, lastAddress: row.ipAddress);
      session = LiveSession(profile, link, codec, out, now: _now);
    } on NotConnectableException {
      // It never connects, so it has no heartbeats to miss.
      active.monitor?.stop();
      active.monitor = null;
      active.emit(const LiveFailure(LiveFailureReason.notSupported));
      return;
    }
    var unreachable = false;
    out.stream.listen((u) {
      if (u case LiveFailure(reason: LiveFailureReason.connectFailed)) unreachable = true;
      // A retry in the background stays "waiting" (Offline) until it actually connects, so the
      // device does not flash "Connecting…" every minute (task 1.3.6).
      if (u case LiveStatusChanged(status: LiveStatus.connecting) when attempt > 0) return;
      active.emit(u);
    });
    active.session = session;
    await active.listenTo(link);
    await session.start();
    if (!unreachable || active.closed) return;

    await session.stop();
    await active.stopListening();
    await out.close();
    await _retryLater(active, profile, row, attempt);
  }

  /// Offline ("waiting") until the next attempt, unless the device is closed meanwhile.
  Future<void> _retryLater(
    ActiveEntry active,
    DeviceProfile profile,
    Device row,
    int attempt,
  ) async {
    active.emit(const LiveStatusChanged(LiveStatus.waiting));
    await _delay(retryWaits[attempt.clamp(0, retryWaits.length - 1)]);
    if (!active.closed) await _connect(active, profile, row, attempt + 1);
  }
}
