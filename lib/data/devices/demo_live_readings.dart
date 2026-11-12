import 'dart:async';
import 'dart:math' as math;

import '../../domain/devices/demo_devices.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/services/live_readings.dart';
import 'active_device.dart' show RecorderFor, WriterFor;
import 'demo_feed.dart';
import 'heartbeat_recorder.dart';
import 'reading_writer.dart';

/// The saved device's address and type, or null when it is gone.
typedef DemoDeviceLookup = Future<({String address, String profileId})?> Function(int deviceId);

/// Debug builds only: [LiveReadings] that plays a [DemoFeed] for dummy devices (addresses in the
/// `AA:BB:CC:DD` range) and passes everything else to the real one. Demo readings are stored like
/// real ones, so trends and today's lists fill up. Release builds never create it.
class DemoLiveReadings implements LiveReadings {
  DemoLiveReadings(
    this._inner,
    this._deviceFor,
    this._profileFor,
    this._writerFor,
    this._recorderFor, {
    this.tick = const Duration(seconds: 1),
    DateTime Function()? now,
    this._random,
  }) : _now = now ?? DateTime.now;

  final LiveReadings _inner;
  final DemoDeviceLookup _deviceFor;
  final DeviceProfile? Function(String id) _profileFor;
  final WriterFor _writerFor;
  final RecorderFor _recorderFor;
  final Duration tick;
  final DateTime Function() _now;
  final math.Random? _random;

  final _sessions = <int, _DemoSession>{};
  final _demoChanged = StreamController<void>.broadcast();
  ActiveLink? _demoLink;

  @override
  Stream<LiveUpdate> watch(int deviceId) {
    StreamSubscription<LiveUpdate>? sub;
    var cancelled = false;
    late final StreamController<LiveUpdate> out;
    out = StreamController(
      onListen: () async {
        final device = await _deviceFor(deviceId);
        final profile = device == null ? null : _profileFor(device.profileId);
        if (cancelled) return;
        final source = device != null && profile != null && isDemoAddress(device.address)
            ? _session(deviceId, profile).watch()
            : _inner.watch(deviceId);
        sub = source.listen(out.add, onError: out.addError, onDone: out.close);
      },
      onCancel: () async {
        cancelled = true;
        await sub?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Stream<ActiveLink?> watchActive() {
    ActiveLink? inner;
    final subs = <StreamSubscription<Object?>>[];
    late final StreamController<ActiveLink?> out;
    void emit() => out.add(_demoLink ?? inner);
    out = StreamController(
      onListen: () {
        subs
          ..add(
            _inner.watchActive().listen((link) {
              inner = link;
              emit();
            }),
          )
          ..add(_demoChanged.stream.listen((_) => emit()));
        if (_demoLink != null) emit();
      },
      onCancel: () => Future.wait([for (final s in subs) s.cancel()]),
    );
    return out.stream;
  }

  @override
  Future<void> retry(int deviceId) async {
    if (!_sessions.containsKey(deviceId)) await _inner.retry(deviceId);
  }

  /// A dummy device has no real link: the command "works" at once, so the action can be tried.
  @override
  Future<void> runCommand(int deviceId, String commandId) async {
    if (!_sessions.containsKey(deviceId)) await _inner.runCommand(deviceId, commandId);
  }

  @override
  Future<void> start(int userId) => _inner.start(userId);

  @override
  Future<void> stop() async {
    for (final session in [..._sessions.values]) {
      await session.close();
    }
    await _inner.stop();
  }

  _DemoSession _session(int deviceId, DeviceProfile profile) =>
      _sessions[deviceId] ??= _DemoSession(
        deviceId,
        profile,
        DemoFeed(profile, random: _random),
        _writerFor(deviceId, profile),
        _recorderFor(deviceId, profile.heartbeatOrDefault),
        tick: tick,
        now: _now,
        onLink: (link) {
          if (link == null && _demoLink?.deviceId != deviceId) return;
          _demoLink = link;
          if (link == null) _sessions.remove(deviceId);
          _demoChanged.add(null);
        },
      );
}

/// One dummy device's demo data while its screen is open: stored, and sent to every listener.
class _DemoSession {
  _DemoSession(
    this.deviceId,
    this.profile,
    this._feed,
    this._writer,
    this._recorder, {
    required this.tick,
    required this._now,
    required this._onLink,
  }) {
    _out = StreamController.broadcast(
      onCancel: () {
        if (!_out.hasListener) unawaited(close());
      },
    );
  }

  final int deviceId;
  final DeviceProfile profile;
  final DemoFeed _feed;
  final ReadingWriter _writer;
  final HeartbeatRecorder _recorder;
  final Duration tick;
  final DateTime Function() _now;
  final void Function(ActiveLink?) _onLink;

  late final StreamController<LiveUpdate> _out;
  final _latest = <String, LiveValue>{};
  LiveHeartbeat? _heartbeat;
  final _timers = <Timer>[];
  bool _started = false;
  bool _closed = false;

  /// What has been sent so far (status, latest values, heartbeat), then everything new.
  Stream<LiveUpdate> watch() async* {
    if (!_started) _start();
    yield const LiveStatusChanged(LiveStatus.streaming);
    yield* Stream.fromIterable([..._latest.values, ?_heartbeat]);
    yield* _out.stream;
  }

  void _start() {
    _started = true;
    _onLink((deviceId: deviceId, status: LiveStatus.streaming, online: true));
    _second();
    _timers.add(Timer.periodic(tick, (_) => _second()));
    for (final view in profile.dashboard?.views ?? const <DashboardView>[]) {
      final (key, hz) = (view.reading, view.sampleHz);
      if (view.type != DashboardViewType.waveform || key == null || hz == null) continue;
      const every = Duration(milliseconds: 100);
      _timers.add(
        Timer.periodic(every, (_) {
          final at = _now();
          for (final v in _feed.wave(hz ~/ 10, hz)) {
            _send(LiveValue(Sample(key, v, at)));
          }
        }),
      );
    }
  }

  void _second() {
    for (final update in _feed.second(_now())) {
      switch (update) {
        case LiveValue(:final sample):
          _latest[sample.key] = update;
          _recorder.beat(batteryPercent: sample.key == batteryKey ? sample.value.round() : null);
          _send(update);
        case LiveEvent(:final event):
          _writer.addEvent(event); // Stored; the dashboard reads events from the database.
        case LiveHeartbeat():
          _heartbeat = update;
          _send(update);
        case LiveStatusChanged() || LiveContactChanged() || LiveFailure():
          _send(update);
      }
    }
  }

  void _send(LiveUpdate update) {
    if (_closed) return;
    if (update case LiveValue(:final sample)) _writer.add(sample);
    _out.add(update);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final t in _timers) {
      t.cancel();
    }
    _onLink(null);
    await _writer.close();
    await _recorder.close();
  }
}
