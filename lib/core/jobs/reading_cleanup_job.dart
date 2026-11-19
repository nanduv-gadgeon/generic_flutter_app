import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/history/local_day.dart';
import '../../domain/services/alert_repository.dart';
import '../../domain/services/daily_summary_repository.dart';
import '../../domain/services/device_event_repository.dart';
import '../../domain/services/heartbeat_repository.dart';
import '../../domain/services/reading_repository.dart';

/// Keeps [daysOnPhone] days of readings, device events and alerts (the config's `history.daysOnPhone`)
/// and [heartbeatsKept] of heartbeats: deletes older ones when [start] is called, then once a day
/// while the app runs. First it sums up each finished day still kept ([summaryFrom] to
/// yesterday), so History has them, and deletes the summaries of older days.
// TODO(phase2): delete only readings, events and heartbeats the uploader has sent.
class ReadingCleanupJob {
  ReadingCleanupJob(
    this._readings,
    this.daysOnPhone, {
    this._heartbeats,
    this._events,
    this._summaries,
    this._alerts,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ReadingRepository _readings;
  final HeartbeatRepository? _heartbeats;
  final DeviceEventRepository? _events;
  final DailySummaryRepository? _summaries;
  final AlertRepository? _alerts;
  final int daysOnPhone;
  final DateTime Function() _now;
  Timer? _timer;

  static const every = Duration(days: 1);

  /// How long heartbeats are kept (requirements §12).
  static const heartbeatsKept = Duration(hours: 24);

  /// Readings measured before this are deleted.
  DateTime get cutoff => _now().toUtc().subtract(Duration(days: daysOnPhone));

  /// The first day summed up: the [daysOnPhone] days kept are today and the ones before it, so
  /// the day [cutoff] falls in, which is only partly kept, is not.
  DateTime get summaryFrom => addDays(startOfDay(_now()), 1 - daysOnPhone);

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
    if (_summaries case final summaries?) {
      try {
        final days = await summaries.refresh(from: summaryFrom, to: startOfDay(_now()));
        final deleted = await summaries.deleteBefore(summaryFrom);
        if (kDebugMode) debugPrint('Summaries: days summed up $days, old ones deleted $deleted');
      } catch (e) {
        if (kDebugMode) debugPrint('Summaries: failed: ${e.runtimeType}');
      }
    }
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
    if (_alerts case final alerts?) {
      try {
        final deleted = await alerts.deleteOlderThan(cutoff);
        if (kDebugMode) debugPrint('Alerts: deleted $deleted older than $daysOnPhone days');
      } catch (e) {
        if (kDebugMode) debugPrint('Alerts: clean-up failed: ${e.runtimeType}');
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
