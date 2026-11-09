import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../../../domain/transport/ble_scanner.dart';
import 'ble_adapter.dart';

/// [BleAdapter] over the `universal_ble` package. The only file that imports it; only platform
/// plumbing here.
class UniversalBleAdapter implements BleAdapter {
  /// For pairing, and the first subscribe or read of an encrypted characteristic: the phone may
  /// stop there and ask the user for the device's pairing key, which takes longer than the
  /// package's 10 s default.
  static const pairingTimeout = Duration(seconds: 60);

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
  Future<bool> requestPermission() async {
    // minSdk 34: scan and connect permissions only, never location.
    await UniversalBle.requestPermissions();
    return UniversalBle.hasPermissions();
  }

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
  Future<void> pair(String deviceId) async {
    // iOS has no pairing call: it asks for the key itself on the first encrypted subscribe or
    // read, which wait [pairingTimeout] for it.
    if (!BleCapabilities.hasSystemPairingApi) return;

    // A device may ask to pair as soon as it connects. Android then pairs on its own (its dialog
    // is already up) and refuses our request, so listen first and wait for that pairing instead.
    final systemPairing = Completer<bool>();
    final sub = UniversalBle.pairingStateStream(deviceId).listen((paired) {
      if (!systemPairing.isCompleted) systemPairing.complete(paired);
    });
    try {
      await UniversalBle.pair(deviceId, timeout: pairingTimeout);
    } on PairingException {
      rethrow; // Declined, or the device refused.
    } on UniversalBleException {
      if (await UniversalBle.isPaired(deviceId) ?? false) return;
      if (!await systemPairing.future.timeout(pairingTimeout)) throw PairingException();
    } finally {
      unawaited(sub.cancel()); // Nothing to wait for: the result is known.
    }
  }

  @override
  Future<int> requestMtu(String deviceId, int mtu) => UniversalBle.requestMtu(deviceId, mtu);

  @override
  Future<Map<String, Set<String>>> discover(String deviceId) async => {
    for (final service in await UniversalBle.discoverServices(deviceId))
      service.uuid: {for (final c in service.characteristics) c.uuid},
  };

  @override
  Future<void> subscribe(String deviceId, String service, String characteristic) =>
      UniversalBle.subscribeNotifications(
        deviceId,
        service,
        characteristic,
        timeout: pairingTimeout,
      );

  @override
  Stream<Uint8List> values(String deviceId, String characteristic) =>
      UniversalBle.characteristicValueStream(deviceId, characteristic);

  @override
  Future<Uint8List> read(String deviceId, String service, String characteristic) =>
      UniversalBle.read(deviceId, service, characteristic, timeout: pairingTimeout);

  @override
  Future<void> write(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value, {
    bool withoutResponse = false,
  }) => UniversalBle.write(
    deviceId,
    service,
    characteristic,
    value,
    withoutResponse: withoutResponse,
  );
}
