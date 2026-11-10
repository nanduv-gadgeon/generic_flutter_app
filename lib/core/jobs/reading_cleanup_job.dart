import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/services/reading_repository.dart';

/// Keeps [daysOnPhone] days of readings (the config's `history.daysOnPhone`): deletes older ones
/// when [start] is called, then once a day while the app runs.
// TODO(phase2): delete only readings the uploader has sent.
class ReadingCleanupJob {
  ReadingCleanupJob(this._readings, this.daysOnPhone, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ReadingRepository _readings;
  final int daysOnPhone;
  final DateTime Function() _now;
  Timer? _timer;

  static const every = Duration(days: 1);

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
  }
}
