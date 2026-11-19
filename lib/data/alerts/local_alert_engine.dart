import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/alerts/alert_tracker.dart';
import '../../domain/services/alert_engine.dart';
import '../../domain/services/alert_notifier.dart';
import '../../domain/services/alert_repository.dart';
import '../../domain/services/live_readings.dart';

/// Each of a user's devices' alert limits, by device id; emits again when they change.
typedef AlertLimitsOf = Stream<Map<int, List<AlertLimit>>> Function(int userId);

/// [AlertEngine] for the device that is connected: watches every live update ([LiveConnections.
/// watchAll]) against the device's limits, raises each alert once per crossing ([AlertTracker]),
/// stores it and passes it to the notifier. Never logs values.
class LocalAlertEngine implements AlertEngine {
  LocalAlertEngine(
    this._live,
    this._limitsOf,
    this._alerts,
    this._notifier, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final LiveConnections _live;
  final AlertLimitsOf _limitsOf;
  final AlertRepository _alerts;
  final AlertNotifier _notifier;
  final DateTime Function() _now;
  final _tracker = AlertTracker();

  /// Null until the limits have loaded; a device missing from it is not (or no longer) the user's.
  Map<int, List<AlertLimit>>? _limits;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  Future<void> start(int userId) async {
    await stop();
    _subs
      ..add(_limitsOf(userId).listen(_onLimits))
      ..add(_live.watchAll().listen((u) => _onUpdate(u.$1, u.$2)));
  }

  @override
  Future<void> stop() async {
    final subs = [..._subs];
    _subs.clear();
    for (final s in subs) {
      await s.cancel();
    }
    _limits = null;
    _tracker.clear();
  }

  void _onLimits(Map<int, List<AlertLimit>> limits) {
    for (final id in _limits?.keys ?? const <int>[]) {
      if (!limits.containsKey(id)) _tracker.forget(id); // Removed.
    }
    _limits = limits;
  }

  void _onUpdate(int deviceId, LiveUpdate update) {
    final limits = _limits?[deviceId];
    if (limits == null) return;
    final alert = switch (update) {
      LiveValue(:final sample) => _tracker.onValue(deviceId, sample, limits),
      LiveHeartbeat(:final online) => _tracker.onOnline(
        deviceId,
        online: online,
        at: _now().toUtc(),
      ),
      _ => null,
    };
    if (alert != null) unawaited(_raise(alert));
  }

  Future<void> _raise(RaisedAlert alert) async {
    try {
      final id = await _alerts.add(alert);
      await _notifier.show(alert.copyWith(id: id));
    } catch (e) {
      if (kDebugMode) debugPrint('Alerts: could not raise one: ${e.runtimeType}');
    }
  }
}
