import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:generic_flutter_app/domain/alerts/alert.dart';
import 'package:generic_flutter_app/domain/alerts/alert_category.dart';
import 'package:generic_flutter_app/domain/alerts/alert_notification.dart';
import 'package:generic_flutter_app/domain/models/reading.dart';
import 'package:generic_flutter_app/presentation/strings/alert_strings.dart';

import '../../fixtures/l10n.dart';

/// The words of alert notifications and Alerts cards, as in the mockup's alerts (made-up values).
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

  test('a card and its notification have the same title', () {
    for (final (a, reading) in cases.keys) {
      expect(
        en.alertTitle(a, reading: reading),
        en.alertNotification(a, deviceName: 'Test band', reading: reading).title,
      );
    }
  });

  // kind -> source chip
  final sources = {
    AlertKind.above: 'Threshold',
    AlertKind.below: 'Threshold',
    AlertKind.batteryLow: 'Device health',
    AlertKind.offline: 'Device health',
  };
  for (final MapEntry(key: kind, value: text) in sources.entries) {
    test('${kind.name} -> chip "$text"', () => expect(en.alertSource(kind), text));
  }

  // filter -> chip label, in the order shown
  final filters = <AlertCategory?, String>{
    null: 'All',
    AlertCategory.reading: 'Readings',
    AlertCategory.event: 'Device events',
    AlertCategory.episode: 'Episodes',
    AlertCategory.channel: 'Channels',
    AlertCategory.health: 'Device health',
  };
  for (final MapEntry(key: category, value: label) in filters.entries) {
    test('filter ${category?.name ?? 'all'} -> "$label"', () {
      expect(en.alertFilter(category), label);
    });
  }

  group('alertTime', () {
    setUpAll(() => initializeDateFormatting('en'));

    // Saturday 24 Oct 2026, 12:00 on the phone's clock.
    final now = DateTime(2026, 10, 24, 12);

    // raised at -> shown as (mockup 34)
    final times = <DateTime, String>{
      now: 'Just now',
      now.add(const Duration(minutes: 5)): 'Just now',
      now.add(const Duration(days: 3)): 'Just now',
      now.subtract(const Duration(seconds: 59)): 'Just now',
      now.subtract(const Duration(minutes: 1)): '1 min ago',
      now.subtract(const Duration(minutes: 10)): '10 min ago',
      now.subtract(const Duration(minutes: 59, seconds: 59)): '59 min ago',
      now.subtract(const Duration(hours: 1)): 'Today, 11:00',
      DateTime(2026, 10, 24, 7, 10): 'Today, 07:10',
      DateTime(2026, 10, 24): 'Today, 00:00',
      // Under 24 hours, but on the day before: Yesterday.
      DateTime(2026, 10, 23, 23, 59): 'Yesterday, 23:59',
      DateTime(2026, 10, 23, 18, 40): 'Yesterday, 18:40',
      DateTime(2026, 10, 23): 'Yesterday, 00:00',
      DateTime(2026, 10, 22, 23, 59): 'Thu 22 Oct, 23:59',
      DateTime(2026, 10, 16, 13, 5): 'Fri 16 Oct, 13:05',
      DateTime(2026, 1, 1, 8): 'Thu 1 Jan, 08:00',
      DateTime(2025, 10, 23, 13, 5): 'Thu 23 Oct 2025, 13:05',
      DateTime(2020, 11, 15, 8): 'Sun 15 Nov 2020, 08:00',
    };
    for (final MapEntry(key: at, value: text) in times.entries) {
      test('$at -> "$text"', () => expect(en.alertTime(at, now).short, text));
    }

    test('the full time is exact, for screen readers', () {
      expect(
        en.alertTime(DateTime(2026, 10, 24, 11, 49), now).full,
        'Saturday, October 24, 2026 at 11:49',
      );
      expect(
        en.alertTime(DateTime(2025, 3, 2, 16, 30), now).full,
        'Sunday, March 2, 2025 at 16:30',
      );
    });

    test("a stored UTC time is shown on the phone's clock", () {
      final at = now.toUtc().subtract(const Duration(hours: 26));
      expect(en.alertTime(at, now).short, 'Yesterday, 10:00');
    });

    test('today, yesterday and dates across a new year', () {
      final newYear = DateTime(2027, 1, 1, 21);
      expect(en.alertTime(DateTime(2027, 1, 1, 0, 5), newYear).short, 'Today, 00:05');
      expect(en.alertTime(DateTime(2026, 12, 31, 20), newYear).short, 'Yesterday, 20:00');
      expect(en.alertTime(DateTime(2026, 12, 28, 9), newYear).short, 'Mon 28 Dec 2026, 09:00');
    });
  });
}
