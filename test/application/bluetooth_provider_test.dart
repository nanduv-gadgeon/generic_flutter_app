import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/bluetooth_provider.dart';
import 'package:generic_flutter_app/core/di/transports.dart';
import 'package:generic_flutter_app/domain/transport/ble_scanner.dart';
import 'package:mocktail/mocktail.dart';

class MockBleScanner extends Mock implements BleScanner {}

/// The "Bluetooth is off" banner's source: only a phone that says `off` shows it.
void main() {
  late MockBleScanner scanner;

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [bleScannerProvider.overrideWithValue(scanner)]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => scanner = MockBleScanner());

  final cases = <BleAvailability, bool>{
    BleAvailability.off: true,
    BleAvailability.on: false,
    BleAvailability.unauthorized: false,
    BleAvailability.unknown: false,
    BleAvailability.unsupported: false,
  };
  for (final MapEntry(key: state, value: off) in cases.entries) {
    test('${state.name} → banner ${off ? 'shown' : 'hidden'}', () async {
      when(() => scanner.availability).thenAnswer((_) => Stream.value(state));

      final c = container();
      c.listen(bluetoothOffProvider, (_, _) {}); // Riverpod pauses what nobody listens to
      await pumpEventQueue();

      expect(c.read(bluetoothOffProvider).value, off);
    });
  }

  test('follows Bluetooth turning off and on again', () async {
    when(() => scanner.availability).thenAnswer(
      (_) => Stream.fromIterable([
        BleAvailability.on,
        BleAvailability.off,
        BleAvailability.off,
        BleAvailability.on,
      ]),
    );
    final seen = <bool>[];
    final c = container();
    c.listen(bluetoothOffProvider, (_, next) {
      if (next case AsyncData(:final value)) seen.add(value);
    }, fireImmediately: true);
    await pumpEventQueue();

    expect(seen, [false, true, false]); // repeats are not passed on
  });

  test('a phone that cannot say never shows the banner', () async {
    when(() => scanner.availability).thenAnswer((_) => Stream.error(Exception('no plugin')));
    final c = container();
    c.listen(bluetoothOffProvider, (_, _) {});
    await pumpEventQueue();

    expect(c.read(bluetoothOffProvider).value ?? false, isFalse);
    expect(c.read(bluetoothOffProvider).hasError, isFalse);
  });

  test('Turn on is offered and asked for through the scanner', () async {
    when(() => scanner.canEnableBluetooth).thenReturn(true);
    when(() => scanner.enableBluetooth()).thenAnswer((_) async => true);
    final c = container();

    expect(c.read(canTurnOnBluetoothProvider), isTrue);
    expect(await c.read(turnOnBluetoothProvider)(), isTrue);
    verify(() => scanner.enableBluetooth()).called(1);
  });
}
