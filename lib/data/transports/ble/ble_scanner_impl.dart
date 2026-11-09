import 'dart:async';

import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/ble_scanner.dart';
import '../../../domain/transport/device_link.dart';
import 'ble_adapter.dart';

/// [BleScanner] that only looks for devices matching the profile's `ble` (or `wifi.bleSetup`) block.
class BleScannerImpl implements BleScanner {
  BleScannerImpl(this._adapter);

  final BleAdapter _adapter;

  @override
  Stream<BleAvailability> get availability => _adapter.availability;

  /// False when the request itself fails (e.g. Bluetooth not supported).
  @override
  Future<bool> requestPermission() async {
    try {
      return await _adapter.requestPermission();
    } catch (_) {
      return false;
    }
  }

  /// Throws [NotConnectableException] when the profile has no `ble` block.
  @override
  Stream<List<FoundDevice>> scan(
    DeviceProfile profile, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    final ble = profile.ble ?? (throw NotConnectableException(profile.id));
    return _scan(ble.scanUuid, ble.scanNamePrefix, timeout);
  }

  /// Throws [NotConnectableException] when the profile cannot be set up over BLE.
  @override
  Stream<List<FoundDevice>> scanForSetup(
    DeviceProfile profile, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    final setup = profile.wifi?.bleSetup ?? (throw NotConnectableException(profile.id));
    return _scan(setup.serviceUuid, setup.scanNamePrefix, timeout);
  }

  Stream<List<FoundDevice>> _scan(String service, String? namePrefix, Duration timeout) {
    final found = <String, FoundDevice>{};
    StreamSubscription<FoundDevice>? results;
    Timer? timer;
    late final StreamController<List<FoundDevice>> controller;

    controller = StreamController(
      onListen: () async {
        results = _adapter.scanResults.listen((device) {
          found[device.id] = device; // newest name and signal per device
          controller.add(List.unmodifiable(found.values));
        });
        timer = Timer(timeout, controller.close);
        try {
          await _adapter.startScan(services: [fullUuid(service)], namePrefixes: [?namePrefix]);
        } catch (e) {
          controller.addError(LinkException('scan failed: ${e.runtimeType}'));
          await controller.close();
        }
      },
      onCancel: () async {
        timer?.cancel();
        await results?.cancel();
        await stop();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    try {
      await _adapter.stopScan();
    } catch (_) {
      // Bluetooth turned off while scanning; the scan is over anyway.
    }
  }
}
