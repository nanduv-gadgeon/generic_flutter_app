import 'package:intl/intl.dart';

import '../../domain/alerts/alert.dart';
import '../../domain/alerts/alert_category.dart';
import '../../domain/alerts/alert_notification.dart';
import '../../domain/models/reading.dart';
import '../../l10n/app_localizations.dart';
import 'device_strings.dart';

/// The words for raised alerts: phone notifications and the Alerts list.
extension AlertStrings on AppLocalizations {
  /// "Heart rate above 110 bpm", "Battery low (12%)", "Missed 3 heartbeats – device offline": the
  /// same in a notification and on its Alerts card. [reading] is the alert's reading in the
  /// device's profile (label, unit, decimals); without it the reading key is shown.
  /// [offlineAfterMissed] is the profile's number of missed heartbeats.
  String alertTitle(RaisedAlert alert, {Reading? reading, int offlineAfterMissed = 3}) {
    final label = reading?.label ?? alert.key ?? '';
    return switch (alert.kind) {
      AlertKind.above => alertAboveTitle(label, _value(alert.limit, reading)),
      AlertKind.below => alertBelowTitle(label, _value(alert.limit, reading)),
      AlertKind.batteryLow => alertBatteryLowTitle((alert.value ?? 0).round()),
      AlertKind.offline => alertOfflineTitle(offlineAfterMissed),
    };
  }

  /// "Heart rate above 110 bpm" / "Test band · now 115 bpm". See [alertTitle].
  AlertNotificationText alertNotification(
    RaisedAlert alert, {
    required String deviceName,
    Reading? reading,
    int offlineAfterMissed = 3,
  }) => (
    title: alertTitle(alert, reading: reading, offlineAfterMissed: offlineAfterMissed),
    body: switch (alert.kind) {
      AlertKind.above ||
      AlertKind.below => alertNotificationBody(deviceName, _value(alert.value, reading)),
      AlertKind.batteryLow || AlertKind.offline => deviceName,
    },
    channel: channelOf(alert.kind),
  );

  String _value(double? v, Reading? reading) =>
      deviceValue(v ?? 0, reading?.decimals ?? 0, reading?.unit ?? '');

  /// The Android channel names and descriptions.
  Map<AlertChannel, AlertChannelText> get alertChannels => {
    AlertChannel.readings: (
      name: alertChannelReadings,
      description: alertChannelReadingsDescription,
    ),
    AlertChannel.device: (name: alertChannelDevice, description: alertChannelDeviceDescription),
  };

  /// The chip on an Alerts card: "Threshold" for a reading's limit, "Device health" for the
  /// battery and Offline.
  String alertSource(AlertKind kind) => switch (kind) {
    AlertKind.above || AlertKind.below => alertSourceThreshold,
    AlertKind.batteryLow || AlertKind.offline => alertSourceDeviceHealth,
  };

  /// A filter chip's label; null is "All".
  String alertFilter(AlertCategory? category) => switch (category) {
    null => alertFilterAll,
    AlertCategory.reading => alertFilterReadings,
    AlertCategory.event => alertFilterEvents,
    AlertCategory.episode => alertFilterEpisodes,
    AlertCategory.channel => alertFilterChannels,
    AlertCategory.health => alertFilterHealth,
  };

  /// When an alert was raised, as of [now]: "Just now", "10 min ago", "Today, 07:10",
  /// "Yesterday, 18:40", "Fri 23 Oct, 13:05". A time in the future counts as now.
  String alertTime(DateTime at, DateTime now) {
    final local = at.toLocal();
    final current = now.toLocal();
    final ago = current.difference(local);
    if (ago < const Duration(minutes: 1)) return alertTimeJustNow;
    if (ago < const Duration(hours: 1)) return alertTimeMinutesAgo(ago.inMinutes);
    final time = DateFormat.Hm(localeName).format(local);
    final day = DateTime(local.year, local.month, local.day);
    // Calendar days, not 24-hour spans, so a daylight-saving change does not shift them.
    if (day == DateTime(current.year, current.month, current.day)) return alertTimeToday(time);
    if (day == DateTime(current.year, current.month, current.day - 1)) {
      return alertTimeYesterday(time);
    }
    return alertTimeDate(
      DateFormat.E(localeName).format(local),
      DateFormat.d(localeName).format(local),
      DateFormat.MMM(localeName).format(local),
      time,
    );
  }
}
