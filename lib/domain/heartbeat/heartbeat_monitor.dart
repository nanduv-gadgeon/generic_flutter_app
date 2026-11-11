import 'dart:async';

import '../models/heartbeat_settings.dart';

/// Watches one device's heartbeats: Offline once nothing has arrived for the profile's
/// `offlineAfterMissed` intervals, Online again on the next [beat]. [onChange] is called on
/// each change only.
///
/// The silence is counted from [start] until the first beat, so a device that never connects
/// also shows as Offline.
class HeartbeatMonitor {
  HeartbeatMonitor(this.settings, this._onChange, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final HeartbeatSettings settings;
  final void Function(bool online, DateTime? lastAt) _onChange;
  final DateTime Function() _now;

  Timer? _timer;
  DateTime? _since;
  DateTime? _lastAt;
  bool _online = true;

  bool get online => _online;

  /// When the device was last heard from, if ever since [start].
  DateTime? get lastAt => _lastAt;

  void start() {
    _since = _now().toUtc();
    _timer?.cancel();
    _timer = Timer.periodic(settings.interval, (_) => _check());
  }

  void beat() {
    _lastAt = _now().toUtc();
    if (!_online) _set(online: true);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _check() {
    final from = _lastAt ?? _since;
    if (!_online || from == null) return;
    if (_now().toUtc().difference(from) >= settings.offlineAfter) _set(online: false);
  }

  void _set({required bool online}) {
    _online = online;
    _onChange(online, _lastAt);
  }
}
