import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/services/device_event_repository.dart';
import '../../domain/services/heartbeat_repository.dart';
import '../../domain/services/reading_repository.dart';

/// Keeps [daysOnPhone] days of readings and device events (the config's `history.daysOnPhone`)
/// and [heartbeatsKept] of heartbeats: deletes older ones when [start] is called, then once a day
/// while the app runs.
// TODO(phase2): delete only readings, events and heartbeats the uploader has sent.
class ReadingCleanupJob {
  ReadingCleanupJob(
    this._readings,
    this.daysOnPhone, {
    this._heartbeats,
    this._events,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ReadingRepository _readings;
  final HeartbeatRepository? _heartbeats;
  final DeviceEventRepository? _events;
  final int daysOnPhone;
  final DateTime Function() _now;
  Timer? _timer;

  static const every = Duration(days: 1);

  /// How long heartbeats are kept (requirements §12).
  static const heartbeatsKept = Duration(hours: 24);

  /// Readings measured before this are deleted.
  DateTime get cutoff => _now().toUtc().subtract(Duration(days: daysOnPhone));

  void start() {
    _timer?.cancel();
    unawaited(runOnce());
    _timer = Timer.periodic(every, (_) => unawaited(runOnce()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> runOnce() async {
    try {
      final deleted = await _readings.deleteOlderThan(cutoff);
      if (kDebugMode) debugPrint('Readings: deleted $deleted older than $daysOnPhone days');
    } catch (e) {
      if (kDebugMode) debugPrint('Readings: clean-up failed: ${e.runtimeType}');
    }
    if (_events case final events?) {
      try {
        final deleted = await events.deleteOlderThan(cutoff);
        if (kDebugMode) debugPrint('Device events: deleted $deleted older than $daysOnPhone days');
      } catch (e) {
        if (kDebugMode) debugPrint('Device events: clean-up failed: ${e.runtimeType}');
      }
    }
    if (_heartbeats case final heartbeats?) {
      try {
        final deleted = await heartbeats.deleteOlderThan(_now().toUtc().subtract(heartbeatsKept));
        if (kDebugMode) debugPrint('Heartbeats: deleted $deleted older than 24 h');
      } catch (e) {
        if (kDebugMode) debugPrint('Heartbeats: clean-up failed: ${e.runtimeType}');
      }
    }
  }
}
