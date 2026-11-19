import '../../domain/alerts/alert.dart';
import '../../domain/alerts/alert_notification.dart';
import '../../domain/models/reading.dart';
import '../../l10n/app_localizations.dart';
import 'device_strings.dart';

/// The words for raised alerts: notifications now, the Alerts list later.
extension AlertStrings on AppLocalizations {
  /// "Heart rate above 110 bpm" / "Test band · now 115 bpm". [reading] is the alert's reading in
  /// the device's profile (label, unit, decimals); without it the reading key is shown.
  /// [offlineAfterMissed] is the profile's number of missed heartbeats.
  AlertNotificationText alertNotification(
    RaisedAlert alert, {
    required String deviceName,
    Reading? reading,
    int offlineAfterMissed = 3,
  }) {
    final label = reading?.label ?? alert.key ?? '';
    String value(double? v) => deviceValue(v ?? 0, reading?.decimals ?? 0, reading?.unit ?? '');
    final channel = channelOf(alert.kind);
    return switch (alert.kind) {
      AlertKind.above => (
        title: alertAboveTitle(label, value(alert.limit)),
        body: alertNotificationBody(deviceName, value(alert.value)),
        channel: channel,
      ),
      AlertKind.below => (
        title: alertBelowTitle(label, value(alert.limit)),
        body: alertNotificationBody(deviceName, value(alert.value)),
        channel: channel,
      ),
      AlertKind.batteryLow => (
        title: alertBatteryLowTitle((alert.value ?? 0).round()),
        body: deviceName,
        channel: channel,
      ),
      AlertKind.offline => (
        title: alertOfflineTitle(offlineAfterMissed),
        body: deviceName,
        channel: channel,
      ),
    };
  }

  /// The Android channel names and descriptions.
  Map<AlertChannel, AlertChannelText> get alertChannels => {
    AlertChannel.readings: (
      name: alertChannelReadings,
      description: alertChannelReadingsDescription,
    ),
    AlertChannel.device: (name: alertChannelDevice, description: alertChannelDeviceDescription),
  };
}
