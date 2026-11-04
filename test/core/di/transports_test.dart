import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/di/transports.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_adapter.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_device_link.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_scanner_impl.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/transport/device_link.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/test_config.dart';

class MockBleAdapter extends Mock implements BleAdapter {}

void main() {
  late ProviderContainer container;
  final profile = DeviceProfile.fromJson(validProfileJson());

  setUp(() {
    container = ProviderContainer(
      overrides: [bleAdapterProvider.overrideWithValue(MockBleAdapter())],
    );
    addTearDown(container.dispose);
  });

  test('provides the BLE scanner', () {
    expect(container.read(bleScannerProvider), isA<BleScannerImpl>());
  });

  test('opens a BLE link for a profile with a ble block', () {
    final link = container.read(deviceLinkFactoryProvider)(profile, 'AA:BB:CC:00:00:01');

    expect(link, isA<BleDeviceLink>());
  });

  test('refuses a profile whose protocol is not known yet', () {
    expect(
      () => container.read(deviceLinkFactoryProvider)(profile.copyWith(ble: null), 'id'),
      throwsA(isA<NotConnectableException>()),
    );
  });
}
