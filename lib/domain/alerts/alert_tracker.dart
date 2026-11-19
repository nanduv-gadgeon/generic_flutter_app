import '../decoder/decoded_packet.dart';
import 'alert.dart';
import 'alert_rules.dart';

/// Raises each alert once per crossing: a condition that stays met raises nothing more until it
/// has cleared ([rearms], or the device back online). Kept in memory.
class AlertTracker {
  /// The conditions met now, as (device id, reading key or [offlineKey]).
  final _open = <(int, String)>{};

  /// The key Offline is tracked under.
  static const offlineKey = 'offline';

  /// The alert [sample] of [deviceId] raises against its [limits], if any.
  RaisedAlert? onValue(int deviceId, Sample sample, Iterable<AlertLimit> limits) {
    final limit = limits.where((l) => l.key == sample.key).firstOrNull;
    if (limit == null) return null;
    final id = (deviceId, sample.key);
    if (_open.contains(id)) {
      if (rearms(limit, sample.value)) _open.remove(id);
      return null;
    }
    final kind = breachOf(limit, sample.value);
    if (kind == null) return null;
    _open.add(id);
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

  /// Drops what is known about [deviceId] (removed).
  void forget(int deviceId) => _open.removeWhere((id) => id.$1 == deviceId);

  /// Drops everything (logged out).
  void clear() => _open.clear();
}
