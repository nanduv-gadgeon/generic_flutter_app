import '../../domain/models/device_profile.dart';
import '../../l10n/app_localizations.dart';

/// Device settings text that needs more than a message from `app_en.arb`.
extension DeviceSettingsStrings on AppLocalizations {
  String deviceSettingsTransport(Transport t) => switch (t) {
    Transport.ble => deviceSettingsTransportBle,
    Transport.wifi => deviceSettingsTransportWifi,
  };

  String deviceSettingsAddressLabel(Transport t) =>
      t == Transport.ble ? deviceSettingsMacAddress : deviceSettingsIpAddress;

  /// "Every 1 min", "Every 30 s".
  String deviceSettingsEvery(Duration interval) =>
      deviceSettingsEveryText(deviceSettingsSpan(interval));

  /// "3 missed (3 min)".
  String deviceSettingsMissed(int count, Duration total) =>
      deviceSettingsMissedText(count, deviceSettingsSpan(total));

  /// "30 s", "1 min", "90 s", "2 h".
  String deviceSettingsSpan(Duration d) {
    final s = d.inSeconds;
    if (s < 60 || s % 60 != 0) return commonSeconds(s);
    if (s < 3600 || s % 3600 != 0) return commonMinutes(s ~/ 60);
    return commonHours(s ~/ 3600);
  }

  /// "12 s ago", "5 min ago", "2 h ago", "3 days ago"; a time in the future counts as now.
  String deviceSettingsAgo(Duration elapsed) {
    final s = elapsed.isNegative ? 0 : elapsed.inSeconds;
    if (s < 60) return agoSeconds(s);
    if (s < 3600) return agoMinutes(s ~/ 60);
    if (s < 86400) return agoHours(s ~/ 3600);
    return deviceSettingsAgoDays(s ~/ 86400);
  }
}
