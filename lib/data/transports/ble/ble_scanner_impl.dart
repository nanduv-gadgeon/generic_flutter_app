import 'dart:async';

import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/ble_scanner.dart';
import '../../../domain/transport/device_link.dart';
import 'ble_adapter.dart';

/// [BleScanner] that only looks for devices matching the profile's `ble` block.
class BleScannerImpl implements BleScanner {
  BleScannerImpl(this._adapter);

  final BleAdapter _adapter;

  @override
  Stream<BleAvailability> get availability => _adapter.availability;

  /// Throws [NotConnectableException] when the profile has no `ble` block.
  @override
  Stream<List<FoundDevice>> scan(
    DeviceProfile profile, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    final ble = profile.ble ?? (throw NotConnectableException(profile.id));
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
          await _adapter.startScan(
            services: [fullUuid(ble.scanUuid)],
            namePrefixes: [?ble.scanNamePrefix],
          );
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
