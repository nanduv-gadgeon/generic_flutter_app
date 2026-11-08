import '../../domain/validation/device_rules.dart';
import '../strings/add_device_strings.dart';

/// Form field validators for Add device: each pairs a rule from `device_rules.dart` with its
/// message. Return null when the value is valid.
abstract final class AddDeviceValidators {
  static String? deviceName(String? v) =>
      isValidDeviceName(v ?? '') ? null : AddDeviceStrings.enterDeviceName;

  static String? network(String? v) => isValidSsid(v ?? '') ? null : AddDeviceStrings.enterNetwork;

  static String? wifiPassword(String? v) =>
      isValidWifiPassword(v ?? '') ? null : AddDeviceStrings.wifiPasswordLength;
}
