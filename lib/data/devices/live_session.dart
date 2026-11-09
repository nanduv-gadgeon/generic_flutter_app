import 'dart:async';

import '../../domain/decoder/decoded_packet.dart';
import '../../domain/decoder/device_codec.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/services/live_readings.dart';
import '../../domain/signal/agc.dart';
import '../../domain/signal/ppg_oximetry.dart';
import '../../domain/transport/device_link.dart';
import 'command_sequencer.dart';

/// One listener's connection to a saved device: connects, starts the data with the profile's
/// `streaming` commands, and passes on the profile's readings and battery until [stop].
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
  bool _stopped = false;
  bool _streaming = false;
  bool _adjusting = false;
  LinkState? _lastState;

  Future<void> start() async {
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
    await _startStreaming();
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    if (_streaming) {
      for (final id in _profile.streaming?.stop ?? const <String>[]) {
        try {
          await _commands.run(id);
        } catch (_) {
          break; // Disconnecting stops the data too; nothing more to do.
        }
      }
    }
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _link.disconnect();
    await _replies.close();
  }

  DateTime get _at => _now().toUtc();

  Future<void> _startStreaming() async {
    if (_stopped) return;
    _emit(const LiveStatusChanged(LiveStatus.starting));
    try {
      for (final id in _profile.streaming?.start ?? const <String>[]) {
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
    _emit(const LiveStatusChanged(LiveStatus.streaming));
  }

  void _onState(LinkState state) {
    final previous = _lastState;
    _lastState = state;
    if (state == LinkState.reconnecting) {
      _streaming = false;
      _emit(const LiveStatusChanged(LiveStatus.reconnecting));
    } else if (state == LinkState.connected && previous == LinkState.reconnecting) {
      unawaited(_startStreaming()); // The device starts again after a drop.
    }
  }

  void _onPacket(DevicePacket packet) {
    for (final decoded in _codec.feed(packet.bytes, source: packet.source)) {
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
        case DeviceEvent() || BatchEnd() || InvalidPacket():
          break;
      }
    }
  }

  void _onSample(Sample sample) {
    if (_readingKeys.contains(sample.key)) _emit(LiveValue(sample));
    for (final result in _oximetry?.feed(sample) ?? const <Sample>[]) {
      if (_readingKeys.contains(result.key)) _emit(LiveValue(result));
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
    if (!_out.isClosed && !_stopped) _out.add(update);
  }
}
