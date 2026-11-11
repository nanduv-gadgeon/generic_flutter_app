import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_adapter.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_device_pairing.dart';
import 'package:mocktail/mocktail.dart';

class MockBleAdapter extends Mock implements BleAdapter {}

void main() {
  test('unpair asks the adapter to forget the device', () async {
    final adapter = MockBleAdapter();
    when(() => adapter.unpair(any())).thenAnswer((_) async {});

    await BleDevicePairing(adapter).unpair('AA:BB:CC:00:00:01');

    verify(() => adapter.unpair('AA:BB:CC:00:00:01')).called(1);
  });
}
