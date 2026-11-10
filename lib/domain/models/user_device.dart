import 'package:freezed_annotation/freezed_annotation.dart';

import 'device_profile.dart' show Transport;

export 'device_profile.dart' show Transport;

part 'user_device.freezed.dart';

/// A device the logged-in user has added, as screens see it. Whether it is connected comes from
/// `LiveReadings.watchActive`, its readings from `ReadingRepository`.
@freezed
abstract class UserDevice with _$UserDevice {
  const factory UserDevice({
    required int id,
    required String name,

    /// A device type id from the config file's `deviceTypes`.
    required String profileId,
    @Default(Transport.ble) Transport transport,
    int? batteryPercent,

    /// When data last arrived from the device ("Seen"). Heartbeats (task 1.2.8) update it too.
    DateTime? lastHeartbeatAt,
  }) = _UserDevice;
}
