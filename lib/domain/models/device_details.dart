import 'package:freezed_annotation/freezed_annotation.dart';

import 'device_profile.dart';

part 'device_details.freezed.dart';

/// One of the user's devices with everything Device settings shows (task 1.2.9).
@freezed
abstract class DeviceDetails with _$DeviceDetails {
  const factory DeviceDetails({
    required int id,
    required String name,

    /// A device type id from the config file's `deviceTypes`.
    required String profileId,
    required Transport transport,

    /// BLE: MAC address or remote id. Wi‑Fi: the device id it announces by mDNS.
    required String address,

    /// Wi‑Fi: the last IP address the device reported.
    String? ipAddress,
    String? firmware,
    int? batteryPercent,
    DateTime? lastHeartbeatAt,

    /// The device's alert limits, in reading-key order.
    @Default([]) List<AlertSetting> alerts,
  }) = _DeviceDetails;
}

/// An alert limit of one device and whether it is turned on. (Not `DeviceAlert`: that name is the
/// database row class.)
@freezed
abstract class AlertSetting with _$AlertSetting {
  const factory AlertSetting({required AlertRule rule, required bool enabled}) = _AlertSetting;
}
