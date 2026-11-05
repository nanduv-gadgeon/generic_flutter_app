import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../../../domain/transport/ble_scanner.dart';
import 'ble_adapter.dart';

/// [BleAdapter] over the `universal_ble` package. The only file that imports it; no logic here.
class UniversalBleAdapter implements BleAdapter {
  @override
  Stream<BleAvailability> get availability async* {
    yield _map(await UniversalBle.getBluetoothAvailabilityState());
    yield* UniversalBle.availabilityStream.map(_map);
  }

  static BleAvailability _map(AvailabilityState state) => switch (state) {
    AvailabilityState.poweredOn => BleAvailability.on,
    AvailabilityState.poweredOff => BleAvailability.off,
    AvailabilityState.unauthorized => BleAvailability.unauthorized,
    AvailabilityState.unsupported => BleAvailability.unsupported,
    AvailabilityState.unknown || AvailabilityState.resetting => BleAvailability.unknown,
  };

  @override
  Stream<FoundDevice> get scanResults =>
      UniversalBle.scanStream.map((d) => FoundDevice(id: d.deviceId, name: d.name, rssi: d.rssi));

  @override
  Future<void> startScan({required List<String> services, required List<String> namePrefixes}) =>
      UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: services, withNamePrefix: namePrefixes),
      );

  @override
  Future<void> stopScan() => UniversalBle.stopScan();

  @override
  Future<void> connect(String deviceId) => UniversalBle.connect(deviceId);

  @override
  Future<void> disconnect(String deviceId) => UniversalBle.disconnect(deviceId);

  @override
  Stream<bool> connection(String deviceId) => UniversalBle.connectionStream(deviceId);

  @override
  Future<void> pair(String deviceId) => UniversalBle.pair(deviceId);

  @override
  Future<int> requestMtu(String deviceId, int mtu) => UniversalBle.requestMtu(deviceId, mtu);

  @override
  Future<Map<String, Set<String>>> discover(String deviceId) async => {
    for (final service in await UniversalBle.discoverServices(deviceId))
      service.uuid: {for (final c in service.characteristics) c.uuid},
  };

  @override
  Future<void> subscribe(String deviceId, String service, String characteristic) =>
      UniversalBle.subscribeNotifications(deviceId, service, characteristic);

  @override
  Stream<Uint8List> values(String deviceId, String characteristic) =>
      UniversalBle.characteristicValueStream(deviceId, characteristic);

  @override
  Future<Uint8List> read(String deviceId, String service, String characteristic) =>
      UniversalBle.read(deviceId, service, characteristic);

  @override
  Future<void> write(String deviceId, String service, String characteristic, Uint8List value) =>
      UniversalBle.write(deviceId, service, characteristic, value);
}
