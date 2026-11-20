import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/alerts/alert.dart';
import 'package:generic_flutter_app/domain/alerts/alert_category.dart';

/// Which filter of the Alerts list each kind of alert is under.
void main() {
  // kind -> category
  final cases = {
    AlertKind.above: AlertCategory.reading,
    AlertKind.below: AlertCategory.reading,
    AlertKind.batteryLow: AlertCategory.health,
    AlertKind.offline: AlertCategory.health,
  };
  for (final MapEntry(key: kind, value: category) in cases.entries) {
    test('${kind.name} -> ${category.name}', () => expect(categoryOf(kind), category));
  }

  test('every kind has a category', () {
    expect(AlertKind.values.map(categoryOf), hasLength(AlertKind.values.length));
  });
}
