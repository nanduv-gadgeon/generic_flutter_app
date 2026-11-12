import 'dart:async';

import '../../domain/decoder/generic_codec.dart';
import '../../domain/heartbeat/heartbeat_monitor.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/services/live_readings.dart';
import '../../domain/transport/device_link.dart';
import '../db/app_database.dart';
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

/// [LiveReadings] with at most one device connected at a time: watching a device connects it, and
/// watching another one disconnects the first. Leaving its screen keeps it connected and storing
/// readings, until another device is watched, it is removed, or the user logs out ([stop]).
///
/// Any data from the device is a heartbeat. After the profile's number of missed intervals it is
/// Offline (no automatic reconnect: the link's own reconnect keeps running) until data returns.
class ActiveDevice implements LiveReadings {
  ActiveDevice(
    this._db,
    this._profileFor,
    this._openLink,
    this._writerFor,
    this._recorderFor, {
    Future<void> Function(Duration)? delay,
    this._now,
  }) : _delay = delay ?? Future.delayed;

  final AppDatabase _db;

  /// The profile with an id, or null when the config no longer has it.
  final DeviceProfile? Function(String id) _profileFor;
  final LinkOpener _openLink;
  final WriterFor _writerFor;
  final RecorderFor _recorderFor;
  final Future<void> Function(Duration) _delay;
  final DateTime Function()? _now;

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
  _Active? _active;

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

  /// Disconnects the current device, then connects [deviceId] (or nothing), one switch at a time.
  Future<void> _select(int? deviceId) => _switching = _switching.then((_) async {
    if (deviceId != null && activeId == deviceId) return;
    final old = _active;
    _active = null;
    _setLink(null);
    await old?.close();
    if (deviceId != null) _active = await _open(deviceId);
  });

  Future<_Active> _open(int deviceId) async {
    late final _Active active;
    active = _Active(deviceId, (u) {
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
      // TODO(1.5.3): raise the "Device offline" alert when [online] turns false.
      active.emit(LiveHeartbeat(online: online, lastAt: lastAt));
    }, now: _now)..start();
    _active = active; // Its first statuses already count as the active link.
    unawaited(_connect(active, profile, row, 0));
    return active;
  }

  Future<void> _connect(_Active active, DeviceProfile profile, Device row, int attempt) async {
    final LiveSession session;
    final DeviceLink link;
    final out = StreamController<LiveUpdate>(sync: true);
    try {
      final codec = codecFor(profile, now: _now);
      final transport = Transport.values.byName(row.transport.name);
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
      active.emit(u);
    });
    active.session = session;
    await active.listenTo(link);
    await session.start();
    if (!unreachable || active.closed) return;

    await session.stop();
    await active.stopListening();
    await out.close();
    active.emit(const LiveStatusChanged(LiveStatus.waiting));
    await _delay(retryWaits[attempt.clamp(0, retryWaits.length - 1)]);
    if (!active.closed) await _connect(active, profile, row, attempt + 1);
  }
}

/// The connected device: its session, its writer and what a newly opened screen needs to see.
class _Active {
  _Active(this.deviceId, this._send);

  final int deviceId;
  final void Function(LiveUpdate) _send;
  LiveSession? session;
  ReadingWriter? writer;
  HeartbeatRecorder? recorder;
  HeartbeatMonitor? monitor;
  bool closed = false;
  final _beats = <StreamSubscription<Object?>>[];

  LiveStatus? _status;
  SensorContact? _contact;
  LiveFailure? _failure;
  final _values = <String, Sample>{};

  /// The link as the rest of the app sees it, once there is a status.
  ActiveLink? get link => switch (_status) {
    final s? => (deviceId: deviceId, status: s, online: monitor?.online ?? true),
    null => null,
  };

  /// The last status, heartbeat, finger contact, value of each key and problem.
  Iterable<LiveUpdate> get replay => [
    if (_status case final s?) LiveStatusChanged(s),
    if (monitor case final m?) LiveHeartbeat(online: m.online, lastAt: m.lastAt),
    if (_contact case final c?) LiveContactChanged(c),
    for (final v in _values.values) LiveValue(v),
    ?_failure,
  ];

  void emit(LiveUpdate update) {
    if (closed) return;
    switch (update) {
      case LiveStatusChanged(:final status):
        _status = status;
        if (status == LiveStatus.streaming) _failure = null;
      case LiveContactChanged(:final contact):
        _contact = contact;
        if (contact != SensorContact.ok) _values.removeWhere((k, _) => k != batteryKey);
      case LiveValue(:final sample):
        _values[sample.key] = sample;
        writer?.add(sample);
      case LiveEvent(:final event):
        writer?.addEvent(event);
        return; // Stored; the dashboard reads events from the database.
      case LiveFailure():
        _failure = update;
      case LiveHeartbeat():
        break; // The monitor keeps it, for the replay.
    }
    _send(update);
  }

  /// Any data on [link] is a heartbeat; its battery level is kept with it.
  Future<void> listenTo(DeviceLink link) async {
    await stopListening();
    _beats
      ..add(link.packets.listen((_) => _beat()))
      ..add(link.battery.listen((v) => _beat(batteryPercent: v)));
  }

  Future<void> stopListening() async {
    for (final sub in _beats) {
      await sub.cancel();
    }
    _beats.clear();
  }

  void _beat({int? batteryPercent}) {
    if (closed) return;
    monitor?.beat();
    recorder?.beat(batteryPercent: batteryPercent);
  }

  Future<void> close() async {
    closed = true;
    monitor?.stop();
    await stopListening();
    await session?.stop();
    await writer?.close();
    await recorder?.close();
  }
}
