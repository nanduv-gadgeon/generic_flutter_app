import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/di/transports.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_adapter.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_device_link.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_scanner_impl.dart';
import 'package:generic_flutter_app/data/transports/wifi/mdns_finder.dart';
import 'package:generic_flutter_app/data/transports/wifi/wifi_device_link.dart';
import 'package:generic_flutter_app/data/transports/wifi/wifi_provisioner_impl.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/transport/device_link.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/test_config.dart';

class MockBleAdapter extends Mock implements BleAdapter {}

void main() {
  late ProviderContainer container;
  final profile = DeviceProfile.fromJson(validWifiProfileJson());

  DeviceLinkFactory factory() => container.read(deviceLinkFactoryProvider);

  setUp(() {
    container = ProviderContainer(
      overrides: [bleAdapterProvider.overrideWithValue(MockBleAdapter())],
    );
    addTearDown(container.dispose);
  });

  test('provides the BLE scanner and the Wi‑Fi provisioner and finder', () {
    expect(container.read(bleScannerProvider), isA<BleScannerImpl>());
    expect(container.read(wifiProvisionerProvider), isA<WifiProvisionerImpl>());
    expect(container.read(wifiDeviceFinderProvider), isA<MdnsFinder>());
  });

  test('opens a link for the transport asked for', () {
    expect(factory()(profile, Transport.ble, 'AA:BB:CC:00:00:01'), isA<BleDeviceLink>());

    final wifi = factory()(profile, Transport.wifi, 'tst-0001', lastAddress: '192.168.1.20');
    expect(wifi, isA<WifiDeviceLink>());
    expect((wifi as WifiDeviceLink).lastAddress, '192.168.1.20');
  });

  final unknown = <String, (DeviceProfile, Transport)>{
    'BLE without a ble block': (profile.copyWith(ble: null), Transport.ble),
    'Wi‑Fi without a wifi block': (profile.copyWith(wifi: null), Transport.wifi),
  };
  for (final MapEntry(key: name, value: (p, transport)) in unknown.entries) {
    test('refuses $name', () {
      expect(() => factory()(p, transport, 'id'), throwsA(isA<NotConnectableException>()));
    });
  }
}
