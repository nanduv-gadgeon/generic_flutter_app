import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_adapter.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_scanner_impl.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/transport/ble_scanner.dart';
import 'package:generic_flutter_app/domain/transport/device_link.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/test_config.dart';

class MockBleAdapter extends Mock implements BleAdapter {}

void main() {
  late MockBleAdapter adapter;
  late StreamController<FoundDevice> results;
  late BleScannerImpl scanner;
  final profile = DeviceProfile.fromJson(validProfileJson());

  setUp(() {
    adapter = MockBleAdapter();
    results = StreamController.broadcast();
    when(() => adapter.scanResults).thenAnswer((_) => results.stream);
    when(
      () => adapter.startScan(
        services: any(named: 'services'),
        namePrefixes: any(named: 'namePrefixes'),
      ),
    ).thenAnswer((_) async {});
    when(() => adapter.stopScan()).thenAnswer((_) async {});
    scanner = BleScannerImpl(adapter);
  });

  final filters = <String, (BleSettings, List<String>, List<String>)>{
    'the service and name prefix': (profile.ble!, [fullUuid(profile.ble!.serviceUuid)], ['TST']),
    'the scan UUID over the service UUID': (
      profile.ble!.copyWith(scanServiceUuid: 'ABCD', scanNamePrefix: null),
      [fullUuid('abcd')],
      [],
    ),
  };
  for (final MapEntry(key: name, value: (ble, services, prefixes)) in filters.entries) {
    test('scans for $name', () async {
      final sub = scanner.scan(profile.copyWith(ble: ble)).listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      verify(() => adapter.startScan(services: services, namePrefixes: prefixes)).called(1);
      verify(() => adapter.stopScan()).called(1);
    });
  }

  test('keeps the newest result per device', () async {
    final lists = <List<FoundDevice>>[];
    final sub = scanner.scan(profile).listen(lists.add);
    await Future<void>.delayed(Duration.zero);

    results
      ..add(const FoundDevice(id: 'a', rssi: -70))
      ..add(const FoundDevice(id: 'b', rssi: -60))
      ..add(const FoundDevice(id: 'a', rssi: -50));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(lists.last, const [FoundDevice(id: 'a', rssi: -50), FoundDevice(id: 'b', rssi: -60)]);
  });

  test('ends and stops scanning after the timeout', () async {
    await expectLater(scanner.scan(profile, timeout: const Duration(milliseconds: 10)), emitsDone);
    verify(() => adapter.stopScan()).called(1);
  });

  test('reports a failed start as LinkException', () async {
    when(
      () => adapter.startScan(
        services: any(named: 'services'),
        namePrefixes: any(named: 'namePrefixes'),
      ),
    ).thenThrow(Exception('Bluetooth off'));

    await expectLater(
      scanner.scan(profile),
      emitsInOrder([emitsError(isA<LinkException>()), emitsDone]),
    );
  });

  test('refuses a profile without a ble block', () {
    expect(
      () => scanner.scan(profile.copyWith(ble: null)),
      throwsA(isA<NotConnectableException>()),
    );
  });
}
