import '../../../domain/transport/device_pairing.dart';
import 'ble_adapter.dart';

/// [DevicePairing] through the BLE adapter.
class BleDevicePairing implements DevicePairing {
  const BleDevicePairing(this._adapter);

  final BleAdapter _adapter;

  @override
  Future<void> unpair(String address) => _adapter.unpair(address);
}
