import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/device_profile.dart';

part 'ble_scanner.freezed.dart';

/// Whether the phone can use Bluetooth right now.
enum BleAvailability { unknown, unsupported, unauthorized, off, on }

/// A nearby device that matches the profile being scanned for.
@freezed
abstract class FoundDevice with _$FoundDevice {
  const factory FoundDevice({
    /// MAC address on Android, a phone-specific UUID on iOS. Saved as the device address.
    required String id,
    String? name,

    /// Signal strength in dBm.
    int? rssi,
  }) = _FoundDevice;
}

/// Finds nearby BLE devices of one device type (Add device step 2).
abstract interface class BleScanner {
  /// Starts with the current state.
  Stream<BleAvailability> get availability;

  /// Devices matching [profile]'s scan service or name prefix, newest list first.
  ///
  /// Stops after [timeout] or when the listener cancels. The profile must have a `ble` block.
  Stream<List<FoundDevice>> scan(DeviceProfile profile, {Duration timeout});

  Future<void> stop();
}
