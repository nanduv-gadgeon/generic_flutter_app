import '../../application/add_device/add_device_state.dart';
import '../../domain/models/device_profile.dart';
import '../../l10n/app_localizations.dart';

/// Add device text that needs more than a message from `app_en.arb`.
extension AddDeviceStrings on AppLocalizations {
  /// The type card badge, e.g. "Wi‑Fi · BLE".
  String addDeviceTransports(List<Transport> transports) => [
    if (transports.contains(Transport.wifi)) addDeviceWifi,
    if (transports.contains(Transport.ble)) addDeviceBle,
  ].join(' · ');

  /// "…:7B:21 · -52 dBm": the end of the address and the signal strength.
  String addDeviceDeviceDetail(String id, int? rssi) {
    final tail = id.length <= 6 ? id : '…${id.substring(id.length - 6)}';
    return rssi == null ? tail : addDeviceSignal(tail, rssi);
  }

  String addDeviceDoneBody(String type, Transport transport, {required bool cloud}) {
    final link = transport == Transport.wifi ? addDeviceWifi : addDeviceBluetoothName;
    return cloud ? addDeviceDoneBodyCloud(type, link) : addDeviceDoneBodyLocal(type, link);
  }

  /// "Heart rate above" / "Battery below".
  String addDeviceAlertLabel(String reading, AlertRule rule) =>
      rule.above != null ? addDeviceAlertAbove(reading) : addDeviceAlertBelow(reading);

  /// "110 bpm", "37.8 °C", "15 %".
  String addDeviceAlertValue(AlertRule rule, String unit) {
    final value = rule.above ?? rule.below ?? 0;
    final text = value == value.roundToDouble() ? value.toInt().toString() : value.toString();
    return unit.isEmpty ? text : '$text $unit';
  }

  /// Hides the middle of a device key: `DK-7F3A-9C2E-4B18-0D51` gives `DK-7F3A-••••-••••-0D51`.
  String addDeviceMaskedKey(String key) {
    if (key.length <= 11) return key;
    return '${key.substring(0, 7)}-••••-••••-${key.substring(key.length - 4)}';
  }

  String addDeviceError(AddDeviceError error) => switch (error) {
    AddDeviceError.bluetoothPermission => addDeviceErrorBluetoothPermission,
    AddDeviceError.scanFailed => addDeviceErrorScanFailed,
    AddDeviceError.connectFailed => addDeviceErrorConnectFailed,
    AddDeviceError.alreadyAdded => addDeviceErrorAlreadyAdded,
    AddDeviceError.deviceNotReachable => addDeviceErrorDeviceNotReachable,
    AddDeviceError.deviceNoAnswer => addDeviceErrorDeviceNoAnswer,
    AddDeviceError.setupFailed => addDeviceErrorSetupFailed,
    AddDeviceError.saveFailed => addDeviceErrorSaveFailed,
    AddDeviceError.removeFailed => addDeviceErrorRemoveFailed,
  };
}
