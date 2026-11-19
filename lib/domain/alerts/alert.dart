import 'package:freezed_annotation/freezed_annotation.dart';

part 'alert.freezed.dart';

/// Why an alert was raised.
enum AlertKind {
  /// A reading went above its limit.
  above,

  /// A reading went below its limit.
  below,

  /// The battery went below its limit.
  batteryLow,

  /// The device missed the profile's number of heartbeats in a row.
  offline,
}

/// One alert limit of a device: its copy of the config's condition for [key], which the user can
/// turn off. Exactly one of [above] or [below] is set.
@freezed
abstract class AlertLimit with _$AlertLimit {
  const factory AlertLimit({
    required String key,
    double? above,
    double? below,
    @Default(true) bool enabled,
  }) = _AlertLimit;
}

/// An alert the phone raised. The words are made where it is shown, from [kind], [key] and the
/// device's profile; [value] is health data: never log it.
@freezed
abstract class RaisedAlert with _$RaisedAlert {
  const factory RaisedAlert({
    int? id,
    required int deviceId,
    required AlertKind kind,

    /// The reading key; null for [AlertKind.offline].
    String? key,

    /// The value that crossed the limit; null for [AlertKind.offline].
    double? value,

    /// The limit it crossed; null for [AlertKind.offline].
    double? limit,
    required DateTime at,
    @Default(false) bool read,
  }) = _RaisedAlert;
}
