import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/services/heartbeat_repository.dart';

/// Saves when the device was last heard from ("Seen") on its device row.
typedef SaveSeen = Future<void> Function(int deviceId, DateTime seenAt);

/// Records one connected device's heartbeats: "Seen" on the device row at most every
/// [seenEvery], and a heartbeats row at most once per [interval], with the latest battery level.
///
/// Battery levels are device health: never logged.
class HeartbeatRecorder {
  HeartbeatRecorder(
    this._deviceId,
    this._heartbeats,
    this._saveSeen, {
    required this.interval,
    this.seenEvery = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int _deviceId;
  final HeartbeatRepository _heartbeats;
  final SaveSeen _saveSeen;
  final Duration interval;
  final Duration seenEvery;
  final DateTime Function() _now;

  DateTime? _seenSaved;
  DateTime? _rowSaved;
  int? _battery;
  Future<void> _last = Future.value();

  /// The device sent something; [batteryPercent] when it was its battery level.
  void beat({int? batteryPercent}) {
    if (batteryPercent != null && batteryPercent >= 0 && batteryPercent <= 100) {
      _battery = batteryPercent;
    }
    final now = _now().toUtc();
    if (_due(_seenSaved, now, seenEvery)) {
      _seenSaved = now;
      _run(() => _saveSeen(_deviceId, now), () => _seenSaved = null);
    }
    if (_due(_rowSaved, now, interval)) {
      _rowSaved = now;
      final battery = _battery;
      _run(() => _heartbeats.add(_deviceId, now, batteryPercent: battery), () => _rowSaved = null);
    }
  }

  /// Waits for the saves already started.
  Future<void> close() => _last;

  static bool _due(DateTime? last, DateTime now, Duration every) =>
      last == null || now.difference(last) >= every;

  /// Runs [save] after the ones already waiting; [failed] lets the next beat try again.
  void _run(Future<void> Function() save, void Function() failed) {
    _last = _last.then((_) async {
      try {
        await save();
      } catch (e) {
        failed();
        if (kDebugMode) {
          debugPrint('Heartbeat: could not save for device $_deviceId: ${e.runtimeType}');
        }
      }
    });
  }
}
