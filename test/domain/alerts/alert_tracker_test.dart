import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/alerts/alert.dart';
import 'package:generic_flutter_app/domain/alerts/alert_tracker.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';

/// Once per crossing: a condition that stays met raises nothing more until it clears.
void main() {
  final at = DateTime.utc(2026, 10, 20, 9);
  const limits = [AlertLimit(key: 'hr', above: 110), AlertLimit(key: 'battery', below: 15)];

  List<RaisedAlert> feed(AlertTracker tracker, String key, List<double> values, {int device = 1}) =>
      [for (final v in values) ?tracker.onValue(device, Sample(key, v, at), limits)];

  // (key, values) -> how many alerts
  final sequences = <(String, List<double>), int>{
    ('hr', [105, 111, 115, 108, 112]): 2,
    ('hr', [111, 120, 130]): 1,
    ('hr', [100, 105]): 0,
    ('battery', [14, 13, 16, 14]): 1, // 16 is not 5 above the limit
    ('battery', [14, 21, 14]): 2,
    ('spo2', [80, 70]): 0, // no limit for it
  };
  for (final MapEntry(key: (key, values), value: count) in sequences.entries) {
    test('$key $values raises $count', () {
      expect(feed(AlertTracker(), key, values), hasLength(count));
    });
  }

  test('the alert says what crossed which limit', () {
    final alert = feed(AlertTracker(), 'battery', [12]).single;
    expect(
      alert,
      RaisedAlert(
        deviceId: 1,
        kind: AlertKind.batteryLow,
        key: 'battery',
        value: 12,
        limit: 15,
        at: at,
      ),
    );
  });

  // online changes -> how many Offline alerts
  final onlines = <List<bool>, int>{
    [false]: 1,
    [false, false]: 1,
    [false, true, false]: 2,
    [true, true]: 0,
  };
  for (final MapEntry(key: changes, value: count) in onlines.entries) {
    test('online $changes raises $count Offline', () {
      final tracker = AlertTracker();
      final alerts = [for (final o in changes) ?tracker.onOnline(3, online: o, at: at)];
      expect(alerts, hasLength(count));
      expect(alerts.every((a) => a.kind == AlertKind.offline && a.deviceId == 3), isTrue);
    });
  }

  test('devices are tracked apart', () {
    final tracker = AlertTracker();
    expect(feed(tracker, 'hr', [120], device: 1), hasLength(1));
    expect(feed(tracker, 'hr', [120], device: 2), hasLength(1));
  });

  test('forget and clear drop what is open', () {
    final tracker = AlertTracker();
    feed(tracker, 'hr', [120], device: 1);
    tracker.forget(1);
    expect(feed(tracker, 'hr', [120], device: 1), hasLength(1));
    tracker.clear();
    expect(feed(tracker, 'hr', [120], device: 1), hasLength(1));
  });
}
