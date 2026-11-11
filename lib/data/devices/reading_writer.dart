import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/decoder/decoded_packet.dart';
import '../../domain/models/device_profile.dart' show batteryKey;
import '../../domain/services/device_event_repository.dart';
import '../../domain/services/reading_repository.dart';

/// Saves the battery level on the device row.
typedef SaveBattery = Future<void> Function(int deviceId, int batteryPercent);

/// Stores one connected device's readings in batches: every [every], once [maxBatch] are waiting,
/// and on [close]. The battery level goes to the device row instead, only when it changes.
/// Readings in [skip] (waveforms, sampled many times a second) are not stored. Device events go
/// to [events] as they arrive. "Seen" is saved by the heartbeat recorder.
///
/// Values are health data: never logged.
class ReadingWriter {
  ReadingWriter(
    this._deviceId,
    this._readings,
    this._saveBattery, {
    this.every = const Duration(seconds: 2),
    this.maxBatch = 200,
    this._events,
    this._skip = const {},
  }) {
    _timer = Timer.periodic(every, (_) => unawaited(flush()));
  }

  final int _deviceId;
  final ReadingRepository _readings;
  final SaveBattery _saveBattery;
  final DeviceEventRepository? _events;
  final Set<String> _skip;
  final Duration every;
  final int maxBatch;

  late final Timer _timer;
  var _waiting = <Sample>[];
  int? _battery;
  Future<void> _last = Future.value();

  void add(Sample sample) {
    if (sample.key == batteryKey) return _onBattery(sample.value.round());
    if (_skip.contains(sample.key)) return;
    _waiting.add(sample);
    if (_waiting.length >= maxBatch) unawaited(flush());
  }

  /// Stores [event], after the writes already waiting. A failure drops it: the device sends its
  /// log again on the next sync.
  void addEvent(DeviceEvent event) {
    final events = _events;
    if (events == null) return;
    _status(() => events.addAll(_deviceId, [event]), () {
      // Kinds only: events sit next to health data.
      if (kDebugMode) debugPrint('Readings: could not store a ${event.kind.name} event');
    });
  }

  /// Stores what is waiting, after any store already running.
  Future<void> flush() {
    if (_waiting.isEmpty) return _last;
    final batch = _waiting;
    _waiting = [];
    return _last = _last.then((_) => _store(batch));
  }

  /// Stores what is waiting and stops the timer.
  Future<void> close() {
    _timer.cancel();
    return flush();
  }

  Future<void> _store(List<Sample> batch) async {
    try {
      await _readings.addAll(_deviceId, batch);
      // Counts only: the values are health data.
      if (kDebugMode) debugPrint('Readings: stored ${batch.length} for device $_deviceId');
    } catch (e) {
      // Counts only: the values are health data.
      if (kDebugMode) debugPrint('Readings: could not store ${batch.length}: ${e.runtimeType}');
    }
  }

  void _onBattery(int percent) {
    if (percent == _battery || percent < 0 || percent > 100) return;
    _battery = percent;
    _status(() => _saveBattery(_deviceId, percent), () => _battery = null);
  }

  /// Runs [save] after the writes already waiting; [failed] lets the next value try again.
  void _status(Future<void> Function() save, void Function() failed) {
    _last = _last.then((_) async {
      try {
        await save();
      } catch (_) {
        failed();
      }
    });
  }
}
