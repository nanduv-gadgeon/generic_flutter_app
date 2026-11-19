import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/alerts/alert.dart';
import 'package:generic_flutter_app/domain/alerts/alert_rules.dart';

/// When a value crosses a limit, and when it is back inside it (made-up values).
void main() {
  const hrAbove = AlertLimit(key: 'hr', above: 110);
  const spo2Below = AlertLimit(key: 'spo2', below: 92);
  const battery = AlertLimit(key: 'battery', below: 15);
  const off = AlertLimit(key: 'hr', above: 110, enabled: false);

  // (limit, value) -> alert raised
  final breaches = <(AlertLimit, double), AlertKind?>{
    (hrAbove, 111): AlertKind.above,
    (hrAbove, 110): null, // at the limit: not over it
    (hrAbove, 72): null,
    (spo2Below, 91): AlertKind.below,
    (spo2Below, 92): null,
    (battery, 14): AlertKind.batteryLow,
    (battery, 15): null,
    (off, 150): null, // turned off
  };
  for (final MapEntry(key: (limit, value), value: kind) in breaches.entries) {
    test('${limit.key} ${limit.above ?? limit.below} (on: ${limit.enabled}), $value -> $kind', () {
      expect(breachOf(limit, value), kind);
    });
  }

  // (limit, value) -> may be raised again
  final rearm = <(AlertLimit, double), bool>{
    (hrAbove, 111): false,
    (hrAbove, 110): true,
    (spo2Below, 91): false,
    (spo2Below, 92): true,
    (battery, 15): false, // at the limit, but not 5 above it
    (battery, 19): false,
    (battery, 20): true,
  };
  for (final MapEntry(key: (limit, value), value: again) in rearm.entries) {
    test('${limit.key}: $value re-arms: $again', () => expect(rearms(limit, value), again));
  }
}
