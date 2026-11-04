import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/transports/ble/ble_adapter.dart';
import '../../data/transports/ble/ble_device_link.dart';
import '../../data/transports/ble/ble_scanner_impl.dart';
import '../../data/transports/ble/universal_ble_adapter.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/transport/ble_scanner.dart';
import '../../domain/transport/device_link.dart';

part 'transports.g.dart';

// Device transports work the same in both phases, so nothing here depends on isCloud.

/// Opens a link to the device [deviceId] of type [profile].
typedef DeviceLinkFactory = DeviceLink Function(DeviceProfile profile, String deviceId);

@Riverpod(keepAlive: true)
BleAdapter bleAdapter(Ref ref) => UniversalBleAdapter();

@Riverpod(keepAlive: true)
BleScanner bleScanner(Ref ref) => BleScannerImpl(ref.watch(bleAdapterProvider));

/// Throws [NotConnectableException] for a profile without connection details.
@Riverpod(keepAlive: true)
DeviceLinkFactory deviceLinkFactory(Ref ref) {
  final adapter = ref.watch(bleAdapterProvider);
  return (profile, deviceId) {
    final ble = profile.ble ?? (throw NotConnectableException(profile.id));
    return BleDeviceLink(adapter, deviceId, ble);
  };
}
