import 'package:freezed_annotation/freezed_annotation.dart';

part 'heartbeat_settings.freezed.dart';
part 'heartbeat_settings.g.dart';

/// `heartbeat` block of a profile: how often the device is expected to be heard from, and how
/// many intervals may pass without it before the device shows as Offline.
///
/// Any data from the device counts as a heartbeat: packets, replies and battery level.
@freezed
abstract class HeartbeatSettings with _$HeartbeatSettings {
  const factory HeartbeatSettings({
    @Default(60) int intervalSeconds,

    /// Intervals in a row with no data before the device is Offline.
    @Default(3) int offlineAfterMissed,

    /// Profile command sent after every connection with [intervalSeconds] as its value, so the
    /// device and the app use the same interval. Missing when the device cannot be told.
    String? setInterval,
  }) = _HeartbeatSettings;

  factory HeartbeatSettings.fromJson(Map<String, dynamic> json) =>
      _$HeartbeatSettingsFromJson(json);
}

extension HeartbeatTimes on HeartbeatSettings {
  Duration get interval => Duration(seconds: intervalSeconds);

  /// How long the device may be silent before it is Offline.
  Duration get offlineAfter => interval * offlineAfterMissed;
}
