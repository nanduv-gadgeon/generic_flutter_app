import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/transports/ble/ble_adapter.dart';
import '../../data/transports/ble/ble_device_link.dart';
import '../../data/transports/ble/ble_device_pairing.dart';
import '../../data/transports/ble/ble_scanner_impl.dart';
import '../../data/transports/ble/universal_ble_adapter.dart';
import '../../data/transports/wifi/ble_wifi_provisioner.dart';
import '../../data/transports/wifi/http_poll_channel.dart';
import '../../data/transports/wifi/mdns_finder.dart';
import '../../data/transports/wifi/softap_provisioner.dart';
import '../../data/transports/wifi/wifi_channel.dart';
import '../../data/transports/wifi/wifi_device_link.dart';
import '../../data/transports/wifi/wifi_provisioner_impl.dart';
import '../../data/transports/wifi/ws_channel.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/transport/ble_scanner.dart';
import '../../domain/transport/device_link.dart';
import '../../domain/transport/device_pairing.dart';
import '../../domain/transport/wifi_device_finder.dart';
import '../../domain/transport/wifi_provisioner.dart';

part 'transports.g.dart';

// Device transports work the same in both phases, so nothing here depends on isCloud.

/// Opens a link over [transport] to the device [deviceId] of type [profile]. [lastAddress] is the
/// Wi‑Fi device's last known IP, used when mDNS does not find it.
typedef DeviceLinkFactory = DeviceLink Function(
  DeviceProfile profile,
  Transport transport,
  String deviceId, {
  String? lastAddress,
});

@Riverpod(keepAlive: true)
BleAdapter bleAdapter(Ref ref) => UniversalBleAdapter();

@Riverpod(keepAlive: true)
BleScanner bleScanner(Ref ref) => BleScannerImpl(ref.watch(bleAdapterProvider));

/// Unpairs removed BLE devices.
@Riverpod(keepAlive: true)
DevicePairing devicePairing(Ref ref) => BleDevicePairing(ref.watch(bleAdapterProvider));

/// HTTP client for devices on the local network only (callers check `isLanHost`); never the cloud.
/// No logging interceptors: bodies hold Wi‑Fi passwords and readings.
@Riverpod(keepAlive: true)
Dio localNetworkDio(Ref ref) {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
  ref.onDispose(dio.close);
  return dio;
}

@Riverpod(keepAlive: true)
WifiProvisioner wifiProvisioner(Ref ref) => WifiProvisionerImpl(
  BleWifiProvisioner(ref.watch(bleAdapterProvider)),
  SoftApProvisioner(ref.watch(localNetworkDioProvider)),
);

@Riverpod(keepAlive: true)
WifiDeviceFinder wifiDeviceFinder(Ref ref) => MdnsFinder();

/// Opens a WebSocket or HTTP poll channel, as the profile's `wifi.stream` says.
@Riverpod(keepAlive: true)
WifiChannelOpener wifiChannelOpener(Ref ref) {
  final dio = ref.watch(localNetworkDioProvider);
  return (endpoint, stream) async => switch (stream.type) {
    WifiStreamType.websocket => await WsChannel.open(endpoint, stream.path),
    WifiStreamType.http => await HttpPollChannel.open(dio, endpoint, stream),
  };
}

/// Throws [NotConnectableException] for a profile without connection details for [Transport].
@Riverpod(keepAlive: true)
DeviceLinkFactory deviceLinkFactory(Ref ref) {
  final adapter = ref.watch(bleAdapterProvider);
  final finder = ref.watch(wifiDeviceFinderProvider);
  final opener = ref.watch(wifiChannelOpenerProvider);
  return (profile, transport, deviceId, {lastAddress}) => switch (transport) {
    Transport.ble => BleDeviceLink(
      adapter,
      deviceId,
      profile.ble ?? (throw NotConnectableException(profile.id)),
    ),
    Transport.wifi => WifiDeviceLink(finder, opener, profile, deviceId, lastAddress: lastAddress),
  };
}
