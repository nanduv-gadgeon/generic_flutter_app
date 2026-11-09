import 'package:freezed_annotation/freezed_annotation.dart';

import 'device_profile.dart';

part 'new_device.freezed.dart';

/// A device being added (Add device step 3), before it has an id.
@freezed
abstract class NewDevice with _$NewDevice {
  const factory NewDevice({
    required int userId,

    /// A device type id from the config file's `deviceTypes`.
    required String profileId,
    required Transport transport,

    /// BLE: MAC address or remote id. Wi‑Fi: the device id it announces by mDNS.
    required String address,

    /// Wi‑Fi: the IP the device reported after joining the network.
    String? ipAddress,
    required String name,
  }) = _NewDevice;
}

/// A device just saved, with the alert limits it starts with.
@freezed
abstract class AddedDevice with _$AddedDevice {
  const factory AddedDevice({
    required int id,
    required String name,
    required List<AlertRule> alerts,

    /// Phase 2: the key the cloud gave the device; null in Phase 1 or until the cloud answers.
    String? deviceKey,

    /// True when [alerts] were suggested by the cloud, false when they are the config defaults.
    @Default(false) bool suggestedAlerts,
  }) = _AddedDevice;
}

/// What the cloud sends back when a device is registered (Phase 2).
@freezed
abstract class CloudRegistration with _$CloudRegistration {
  const factory CloudRegistration({
    required String deviceKey,

    /// Suggested alert limits; empty keeps the config defaults.
    @Default([]) List<AlertRule> alerts,
  }) = _CloudRegistration;
}
