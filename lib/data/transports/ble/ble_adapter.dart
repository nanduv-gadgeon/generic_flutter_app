import 'dart:typed_data';

import '../../../domain/transport/ble_scanner.dart';

/// The few BLE calls the transport needs, so its logic can be tested without a radio.
///
/// UUIDs going in may be short or long; UUIDs coming out are lower-case 128-bit ([fullUuid]).
abstract interface class BleAdapter {
  /// Starts with the current state.
  Stream<BleAvailability> get availability;

  /// Every advertisement seen while scanning.
  Stream<FoundDevice> get scanResults;

  /// Finds devices advertising any of [services] or with a name starting with any of [namePrefixes].
  Future<void> startScan({required List<String> services, required List<String> namePrefixes});

  Future<void> stopScan();

  Future<void> connect(String deviceId);

  Future<void> disconnect(String deviceId);

  /// true when connected, false when the link drops.
  Stream<bool> connection(String deviceId);

  /// Pairs (bonds) with the device; throws if pairing fails.
  Future<void> pair(String deviceId);

  /// Asks for a larger packet size; returns the size agreed.
  Future<int> requestMtu(String deviceId, int mtu);

  /// Service UUID -> its characteristic UUIDs.
  Future<Map<String, Set<String>>> discover(String deviceId);

  Future<void> subscribe(String deviceId, String service, String characteristic);

  /// Values notified on [characteristic].
  Stream<Uint8List> values(String deviceId, String characteristic);

  Future<Uint8List> read(String deviceId, String service, String characteristic);

  /// Writes with response.
  Future<void> write(String deviceId, String service, String characteristic, Uint8List value);
}
