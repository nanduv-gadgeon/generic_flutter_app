import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_device.freezed.dart';

/// A device the logged-in user has added, as screens see it. Module 2 adds connection state and
/// the latest reading.
@freezed
abstract class UserDevice with _$UserDevice {
  const factory UserDevice({
    required int id,
    required String name,

    /// A device type id from the config file's `deviceTypes`.
    required String profileId,
    int? batteryPercent,
    DateTime? lastHeartbeatAt,
  }) = _UserDevice;
}
