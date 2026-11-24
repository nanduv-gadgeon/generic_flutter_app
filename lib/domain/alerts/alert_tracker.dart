import '../decoder/decoded_packet.dart';
import 'alert.dart';
import 'alert_rules.dart';

/// Raises each alert once per crossing: a condition that stays met raises nothing more until it
/// has cleared ([rearms], the device back online, or the limit turned off: [close]). Low battery is the exception: while it stays
/// below its limit, each new whole-percent low raises another alert (14 %, 13 %, 12 %…), so the
/// user sees it running down. Kept in memory.
class AlertTracker {
  /// The conditions met now, as (device id, reading key or [offlineKey]).
  final _open = <(int, String)>{};

  /// The lowest whole-percent battery level already alerted, per (device id, `battery`).
  final _lowestBattery = <(int, String), int>{};

  /// The key Offline is tracked under.
  static const offlineKey = 'offline';

  /// The alert [sample] of [deviceId] raises against its [limits], if any.
  RaisedAlert? onValue(int deviceId, Sample sample, Iterable<AlertLimit> limits) {
    final limit = limits.where((l) => l.key == sample.key).firstOrNull;
    if (limit == null) return null;
    final id = (deviceId, sample.key);
    final kind = breachOf(limit, sample.value);
    if (_open.contains(id)) {
      if (rearms(limit, sample.value)) {
        _open.remove(id);
        _lowestBattery.remove(id);
        return null;
      }
      if (kind != AlertKind.batteryLow || !_newBatteryLow(id, sample.value)) return null;
      return _alert(deviceId, kind!, sample, limit);
    }
    if (kind == null) return null;
    _open.add(id);
    if (kind == AlertKind.batteryLow) _lowestBattery[id] = sample.value.round();
    return _alert(deviceId, kind, sample, limit);
  }

  /// Whether [value] is a new whole-percent low for the battery [id]; if so it is remembered.
  bool _newBatteryLow((int, String) id, double value) {
    final level = value.round();
    final lowest = _lowestBattery[id];
    if (lowest != null && level >= lowest) return false;
    _lowestBattery[id] = level;
    return true;
  }

  RaisedAlert _alert(int deviceId, AlertKind kind, Sample sample, AlertLimit limit) {
    return RaisedAlert(
      deviceId: deviceId,
      kind: kind,
      key: sample.key,
      value: sample.value,
      limit: kind == AlertKind.above ? limit.above : limit.below,
      at: sample.at,
    );
  }

  /// The Offline alert, when [deviceId] has just gone offline.
  RaisedAlert? onOnline(int deviceId, {required bool online, required DateTime at}) {
    final id = (deviceId, offlineKey);
    if (online) {
      _open.remove(id);
      return null;
    }
    if (!_open.add(id)) return null;
    return RaisedAlert(deviceId: deviceId, kind: AlertKind.offline, at: at);
  }

  /// Ends [deviceId]'s open alert for [key], as if the value had cleared: its limit was turned
  /// off in Device settings, so turning it back on alerts again while the value is still over.
  void close(int deviceId, String key) {
    _open.remove((deviceId, key));
    _lowestBattery.remove((deviceId, key));
  }

  /// Drops what is known about [deviceId] (removed).
  void forget(int deviceId) {
    _open.removeWhere((id) => id.$1 == deviceId);
    _lowestBattery.removeWhere((id, _) => id.$1 == deviceId);
  }

  /// Drops everything (logged out).
  void clear() {
    _open.clear();
    _lowestBattery.clear();
  }
}
