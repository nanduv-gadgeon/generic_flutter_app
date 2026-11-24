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

  /// After "Mark all read": "All alerts marked as read", or "Readings alerts marked as read" under
  /// a filter.
  String alertsMarkedRead(AlertCategory? filter) =>
      filter == null ? alertsMarkedAllRead : alertsMarkedFilterRead(alertFilter(filter));

  /// The "Clear all" question and its text, for "All" or one filter.
  ({String title, String body}) alertsClearQuestion(AlertCategory? filter) => filter == null
      ? (title: alertsClearAllTitle, body: alertsClearAllBody)
      : (
          title: alertsClearFilterTitle(alertFilter(filter)),
          body: alertsClearFilterBody(alertFilter(filter)),
        );

  /// After "Clear all": "All alerts cleared", or "Readings alerts cleared" under a filter.
  String alertsClearedText(AlertCategory? filter) =>
      filter == null ? alertsCleared : alertsFilterCleared(alertFilter(filter));

  /// When an alert was raised, as of [now], on the phone's clock, as in mockup 34. [AlertTime.short]
  /// is shown: "Just now" (under a minute), "10 min ago" (under an hour), "Today, 07:10",
  /// "Yesterday, 18:40", "Fri 23 Oct, 13:05", and "Fri 23 Oct 2025, 13:05" for another year.
  /// [AlertTime.full] is the exact time, for screen readers: "Monday, November 23, 2026 at 11:49".
  /// A time in the future counts as now.
  AlertTime alertTime(DateTime at, DateTime now) {
    final local = at.toLocal();
    final current = now.toLocal();
    final time = DateFormat.Hm(localeName).format(local);
    final full = alertTimeFull(DateFormat.yMMMMEEEEd(localeName).format(local), time);
    return (short: _shortTime(local, current, time), full: full);
  }

  String _shortTime(DateTime at, DateTime now, String time) {
    final ago = now.difference(at);
    if (ago < const Duration(minutes: 1)) return alertTimeJustNow;
    if (ago < const Duration(hours: 1)) return alertTimeMinutesAgo(ago.inMinutes);
    // Calendar days, not 24-hour spans, so a daylight-saving change does not shift them.
    final days = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(at.year, at.month, at.day)).inDays;
    if (days <= 0) return alertTimeToday(time);
    if (days == 1) return alertTimeYesterday(time);
    final weekday = DateFormat.E(localeName).format(at);
    final day = DateFormat.d(localeName).format(at);
    final month = DateFormat.MMM(localeName).format(at);
    if (at.year == now.year) return alertTimeDate(weekday, day, month, time);
    return alertTimeDateYear(weekday, day, month, DateFormat.y(localeName).format(at), time);
  }
}

/// An alert's time: [short] for the card, [full] (the exact time) for screen readers.
typedef AlertTime = ({String short, String full});
