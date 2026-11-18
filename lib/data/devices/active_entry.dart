import 'dart:async';

import '../../domain/heartbeat/heartbeat_monitor.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/services/live_readings.dart';
import '../../domain/transport/device_link.dart';
import 'heartbeat_recorder.dart';
import 'live_session.dart';
import 'reading_writer.dart';

/// The connected device: its session, its writer and what a newly opened screen needs to see.
class ActiveEntry {
  ActiveEntry(this.deviceId, this._send);

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
