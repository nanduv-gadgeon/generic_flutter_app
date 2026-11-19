import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/alerts/alert.dart';
import 'package:generic_flutter_app/domain/alerts/alert_notification.dart';
import 'package:generic_flutter_app/domain/models/reading.dart';
import 'package:generic_flutter_app/presentation/strings/alert_strings.dart';

import '../../fixtures/l10n.dart';

/// The words of alert notifications, as in the mockup's alerts (made-up values).
void main() {
  final at = DateTime.utc(2026, 10, 20, 9);
  const hr = Reading(key: 'hr', label: 'Heart rate', unit: 'bpm', icon: ReadingIcon.pulse);
  const spo2 = Reading(key: 'spo2', label: 'SpO₂', unit: '%', icon: ReadingIcon.pulse);
  const co2 = Reading(key: 'co2', label: 'CO₂', unit: 'ppm', icon: ReadingIcon.pulse);
  const temp = Reading(
    key: 'temp',
    label: 'Skin temp',
    unit: '°C',
    icon: ReadingIcon.thermo,
    decimals: 1,
  );

  RaisedAlert alert(AlertKind kind, [String? key, double? value, double? limit]) =>
      RaisedAlert(deviceId: 1, kind: kind, key: key, value: value, limit: limit, at: at);

  // (alert, reading in the profile) -> (title, body, channel)
  final cases = <(RaisedAlert, Reading?), AlertNotificationText>{
    (alert(AlertKind.above, 'hr', 115, 110), hr): (
      title: 'Heart rate above 110 bpm',
      body: 'Test band · now 115 bpm',
      channel: AlertChannel.readings,
    ),
    (alert(AlertKind.below, 'spo2', 89, 92), spo2): (
      title: 'SpO₂ below 92 %',
      body: 'Test band · now 89 %',
      channel: AlertChannel.readings,
    ),
    (alert(AlertKind.above, 'co2', 1250, 1000), co2): (
      title: 'CO₂ above 1,000 ppm',
      body: 'Test band · now 1,250 ppm',
      channel: AlertChannel.readings,
    ),
    (alert(AlertKind.above, 'temp', 38.04, 37.8), temp): (
      title: 'Skin temp above 37.8 °C',
      body: 'Test band · now 38.0 °C',
      channel: AlertChannel.readings,
    ),
    (alert(AlertKind.above, 'gone', 5, 4), null): (
      title: 'gone above 4',
      body: 'Test band · now 5',
      channel: AlertChannel.readings,
    ),
    (alert(AlertKind.batteryLow, 'battery', 12, 15), null): (
      title: 'Battery low (12%)',
      body: 'Test band',
      channel: AlertChannel.device,
    ),
    (alert(AlertKind.offline), null): (
      title: 'Missed 3 heartbeats – device offline',
      body: 'Test band',
      channel: AlertChannel.device,
    ),
  };
  for (final MapEntry(key: (a, reading), value: expected) in cases.entries) {
    test('${a.kind.name} ${a.key ?? ''} -> "${expected.title}"', () {
      expect(en.alertNotification(a, deviceName: 'Test band', reading: reading), expected);
    });
  }

  test('one missed heartbeat is said in the singular', () {
    expect(
      en.alertNotification(alert(AlertKind.offline), deviceName: 'X', offlineAfterMissed: 1).title,
      'Missed 1 heartbeat – device offline',
    );
  });

  test('both Android channels have a name and a description', () {
    expect(en.alertChannels, {
      AlertChannel.readings: (
        name: 'Reading alerts',
        description: 'A reading went above or below its limit.',
      ),
      AlertChannel.device: (
        name: 'Device alerts',
        description: "A device's battery is low or it went offline.",
      ),
    });
  });
}
