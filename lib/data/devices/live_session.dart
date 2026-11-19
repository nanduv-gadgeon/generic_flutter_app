import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/decoder/decoded_packet.dart';
import '../../domain/decoder/device_codec.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/services/live_readings.dart';
import '../../domain/signal/agc.dart';
import '../../domain/signal/ppg_oximetry.dart';
import '../../domain/transport/device_link.dart';
import 'command_sequencer.dart';
import 'log_sync.dart';

/// A connection to a saved device: connects, sends the heartbeat interval when the profile has a
/// `heartbeat.setInterval` command, fetches stored data with the profile's `sync` commands,
/// starts the live data with its `streaming` commands, and passes on the profile's readings and
/// battery until [stop]. All of it runs again after a reconnect.
///
/// Values are passed on, never logged.
class LiveSession {
  LiveSession(this._profile, this._link, this._codec, this._out, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _oximetry = switch (_profile.signal?.ppgOximetry) {
        final s? => PpgOximetry(s),
        null => null,
      },
      _agc = switch (_profile.agc) {
        final s? => Agc(s),
        null => null,
      },
      _readingKeys = {for (final r in _profile.readings) r.key};

  /// Pause after the stop commands before the link drops, so the device leaves streaming cleanly.
  static const stopSettle = Duration(milliseconds: 150);

  /// Pause after connecting (notifications on) before the start commands, so the link's MTU,
  /// PHY and connection interval settle on the device.
  static const startSettle = Duration(milliseconds: 150);

  /// No data this long after Start means the device is stuck: the link is reopened once, then the
  /// start fails. Safety net for the reconnect cool-down in the BLE link.
  static const noDataTimeout = Duration(seconds: 4);

  final DeviceProfile _profile;
  final DeviceLink _link;
  final DeviceCodec _codec;
  final StreamController<LiveUpdate> _out;
  final DateTime Function() _now;
  final PpgOximetry? _oximetry;
  final Agc? _agc;
  final Set<String> _readingKeys;

  final _replies = StreamController<CommandReply>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];
  late final _commands = CommandSequencer(
    _link,
    _codec,
    _profile.commands,
    _replies.stream,
    timeout: Duration(milliseconds: _profile.streaming?.replyTimeoutMs ?? 2500),
    retries: _profile.streaming?.retries ?? 1,
  );
  late final _sync = switch (_profile.sync) {
    final s? => LogSync(s, _commands),
    null => null,
  };
  bool _stopped = false;
  bool _streaming = false;
  bool _adjusting = false;

  /// A device action is running: worked-out readings are held back.
  bool _acting = false;
  LinkState? _lastState;
  SensorContact? _contact;

  /// Debug builds only: counts for the once-a-second diagnostic line. Never values.
  int _frames = 0;
  int _samples = 0;
  int _invalid = 0;
  Timer? _reportTimer;

  /// Runs from Start until the first data frame; at most one at a time.
  Timer? _noDataTimer;
  final _sinceStart = Stopwatch();

  /// The link was reopened once for no data; set back when data comes.
  bool _reopened = false;

  Future<void> start() async {
    if (kDebugMode) {
      _reportTimer = Timer.periodic(const Duration(seconds: 1), (_) => _report());
    }
    _subs
      ..add(_link.packets.listen(_onPacket))
      ..add(_link.battery.listen((v) => _emit(LiveValue(Sample(batteryKey, v.toDouble(), _at)))))
      ..add(_link.state.listen(_onState));
    _emit(const LiveStatusChanged(LiveStatus.connecting));
    try {
      await _link.connect();
    } on LinkException {
      return _fail(LiveFailureReason.connectFailed);
    }
    // Closed while connecting: stop() already ran, so make sure the link does not stay up.
    if (_stopped) return _link.disconnect();
    await _afterConnect();
  }

  /// Sends a device action's [steps] in order (the dashboard's action button), waiting for each
  /// reply and each step's pause. Meanwhile the AGC waits and worked-out readings are not passed
  /// on (an LED flashing for the action would skew them); afterwards any LED the AGC drives is put
  /// back at its level. Throws [CommandFailedException], [LinkException] or
  /// [UnsupportedCommandException].
  Future<void> runAction(List<ActionStep> steps) async {
    _adjusting = true;
    _acting = true;
    try {
      for (final step in steps) {
        await _commands.run(step.command, value: step.value);
        if (step.waitMs > 0) await Future<void>.delayed(Duration(milliseconds: step.waitMs));
      }
    } finally {
      await _restoreAgcLevels(steps);
      _acting = false;
      _adjusting = false;
    }
  }

  Future<void> _restoreAgcLevels(List<ActionStep> steps) async {
    final agc = _agc;
    if (agc == null) return;
    final touched = {for (final s in steps) s.command}.intersection(_profile.agc!.commands.toSet());
    for (final id in touched) {
      try {
        await _commands.run(id, value: agc.level);
      } catch (_) {
        // The AGC sets it again on its next change.
      }
    }
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _reportTimer?.cancel();
    _cancelNoDataWatch();
    _sync?.cancel();
    if (_streaming) await _stopStreaming();
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _link.disconnect();
    await _replies.close();
  }

  /// Sends the profile's stop commands, then waits [stopSettle] before the link is closed.
  Future<void> _stopStreaming() async {
    final stop = _profile.streaming?.stop ?? const <String>[];
    if (stop.isEmpty) return;
    try {
      for (final id in stop) {
        await _commands.run(id);
      }
    } catch (_) {
      return; // Disconnecting stops the data too; nothing more to do.
    }
    await Future<void>.delayed(stopSettle);
  }

  DateTime get _at => _now().toUtc();

  Future<void> _afterConnect() async {
    // Tell the device the heartbeat interval, when its profile can.
    if (_profile.heartbeat case HeartbeatSettings(:final setInterval?, :final intervalSeconds)) {
      if (_stopped) return;
      try {
        await _commands.run(setInterval, value: intervalSeconds);
      } on CommandFailedException {
        return _fail(LiveFailureReason.startFailed);
      } on LinkException {
        return _fail(LiveFailureReason.startFailed);
      }
    }
    final sync = _sync;
    if (sync != null && !_stopped) {
      _emit(const LiveStatusChanged(LiveStatus.syncing));
      try {
        await sync.run();
      } on CommandFailedException {
        return _fail(LiveFailureReason.startFailed);
      } on LinkException {
        return _fail(LiveFailureReason.startFailed);
      }
    }
    await _startStreaming();
  }

  Future<void> _startStreaming() async {
    if (_stopped) return;
    final start = _profile.streaming?.start ?? const <String>[];
    if (start.isNotEmpty) {
      await Future<void>.delayed(startSettle);
      if (_stopped) return;
    }
    _emit(const LiveStatusChanged(LiveStatus.starting));
    try {
      for (final id in start) {
        await _commands.run(id);
      }
    } on CommandFailedException catch (e) {
      final problem = _problem(e.replyId, e.code);
      return _fail(LiveFailureReason.startFailed, problem: problem);
    } on LinkException {
      return _fail(LiveFailureReason.startFailed);
    }
    if (_stopped) return;
    _streaming = true;
    _sync?.startPolling();
    _emit(const LiveStatusChanged(LiveStatus.streaming));
    if (start.isNotEmpty) _watchForData();
  }

  void _watchForData() {
    _cancelNoDataWatch();
    _sinceStart
      ..reset()
      ..start();
    _noDataTimer = Timer(noDataTimeout, () => unawaited(_onNoData()));
  }

  void _cancelNoDataWatch() {
    _noDataTimer?.cancel();
    _noDataTimer = null;
  }

  /// Started but silent: reopen the link once (stop, close, the BLE cool-down, connect, start
  /// again); silent again means the start failed. Never loops.
  Future<void> _onNoData() async {
    _noDataTimer = null;
    if (_stopped || !_streaming) return;
    _streaming = false;
    _sync?.cancel();
    if (_reopened) return _fail(LiveFailureReason.startFailed);
    _reopened = true;
    if (kDebugMode) debugPrint('Live device: no data after start, reopening the link');
    _emit(const LiveStatusChanged(LiveStatus.connecting));
    await _stopStreaming();
    if (_stopped) return;
    await _link.disconnect();
    if (_stopped) return;
    try {
      await _link.connect();
    } on LinkException {
      return _fail(LiveFailureReason.connectFailed);
    }
    if (_stopped) return _link.disconnect();
    await _afterConnect();
  }

  void _onData() {
    if (_noDataTimer == null) return;
    _cancelNoDataWatch();
    _reopened = false;
    if (kDebugMode) {
      debugPrint('Live device: first data ${_sinceStart.elapsedMilliseconds} ms after start');
    }
  }

  void _onState(LinkState state) {
    final previous = _lastState;
    _lastState = state;
    if (state == LinkState.reconnecting) {
      _cancelNoDataWatch();
      _streaming = false;
      _sync?.cancel();
      _emit(const LiveStatusChanged(LiveStatus.reconnecting));
    } else if (state == LinkState.connected && previous == LinkState.reconnecting) {
      unawaited(_afterConnect()); // Fetch what was missed, then start again after a drop.
    }
  }

  void _onPacket(DevicePacket packet) {
    if (packet.source == FrameSource.data) {
      _onData();
      if (kDebugMode) _frames++;
      _sync?.onFrame();
    }
    for (final decoded in _codec.feed(packet.bytes, source: packet.source)) {
      if (kDebugMode) {
        if (decoded is Sample) _samples++;
        if (decoded is InvalidPacket) _invalid++;
      }
      switch (decoded) {
        case CommandReply():
          if (!_replies.isClosed) _replies.add(decoded);
          // Unprompted problem reports; replies to commands are handled by whoever waits.
          if (_streaming) {
            final problem = _problem(decoded.id, decoded.data.firstOrNull);
            if (problem != null) _fail(LiveFailureReason.deviceProblem, problem: problem);
          }
        case Sample():
          _onSample(decoded);
        case BatchEnd():
          _sync?.onBatchEnd();
        case DeviceEvent():
          _emit(LiveEvent(decoded));
        case InvalidPacket():
          break;
      }
    }
  }

  /// Debug builds only: every second, how much data arrived and what the finger check decided,
  /// e.g. `Live device: frames 10/s, samples 200/s, invalid 0, contact settling, finger ok`.
  /// Printed even when nothing arrives (`frames 0/s`). Counts and states only; never readings or
  /// light levels.
  void _report() {
    final check = _oximetry?.lastCheck;
    debugPrint(
      'Live device: frames $_frames/s, samples $_samples/s, invalid $_invalid, '
      'contact ${_contact?.name ?? '-'}, finger ${check?.name ?? '-'}',
    );
    _frames = _samples = _invalid = 0;
  }

  void _onSample(Sample sample) {
    if (_readingKeys.contains(sample.key)) _emit(LiveValue(sample));
    final oximetry = _oximetry;
    if (oximetry != null) {
      final results = oximetry.feed(sample);
      final contact = oximetry.contact;
      if (contact != null && contact != _contact) {
        _contact = contact;
        _emit(LiveContactChanged(contact));
      }
      for (final result in results) {
        if (_readingKeys.contains(result.key) && !_acting) _emit(LiveValue(result));
      }
    }
    final agc = _agc;
    if (agc != null && sample.key == _profile.agc!.input && _streaming && !_adjusting) {
      final level = agc.feed(sample.value, _at);
      if (level != null) unawaited(_setLevel(agc, level));
    }
  }

  Future<void> _setLevel(Agc agc, int level) async {
    _adjusting = true;
    try {
      for (final id in _profile.agc!.commands) {
        await _commands.run(id, value: level);
      }
      agc.applied(level, _at);
    } catch (_) {
      // Keep the current level; the next out-of-range stretch tries again.
    } finally {
      _adjusting = false;
    }
  }

  DeviceProblem? _problem(int? replyId, int? code) {
    if (replyId == null || code == null) return null;
    for (final p in _profile.streaming?.problems ?? const <ReplyProblem>[]) {
      if (hexByte(p.id) == replyId && hexByte(p.data) == code) return p.problem;
    }
    return null;
  }

  void _fail(LiveFailureReason reason, {DeviceProblem? problem}) =>
      _emit(LiveFailure(reason, problem: problem));

  void _emit(LiveUpdate update) {
    if (kDebugMode) {
      switch (update) {
        case LiveStatusChanged(:final status):
          debugPrint('Live device: status ${status.name}');
        case LiveFailure(:final reason, :final problem):
          debugPrint(
            'Live device: failed ${reason.name}${problem == null ? '' : ' (${problem.name})'}',
          );
        case LiveContactChanged(:final contact):
          debugPrint('Live device: contact ${contact.name}');
        case LiveValue() || LiveEvent() || LiveHeartbeat():
          break; // Readings and events: never logged. Heartbeats are not the session's.
      }
    }
    if (!_out.isClosed && !_stopped) _out.add(update);
  }
}
