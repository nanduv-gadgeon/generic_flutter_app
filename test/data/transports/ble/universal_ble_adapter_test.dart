import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/transports/ble/universal_ble_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_ble/universal_ble.dart';

class MockPlatform extends Mock implements UniversalBlePlatform {}

/// Encrypted characteristics: the phone may ask the user for the pairing key on the first
/// subscribe or read, which takes longer than the package's 10 s command timeout.
void main() {
  const device = 'AA:BB:CC:00:7B:21';
  const service = '0000fff0-0000-1000-8000-00805f9b34fb';
  const characteristic = '0000fff1-0000-1000-8000-00805f9b34fb';
  const keyEntry = Duration(seconds: 30);

  late MockPlatform platform;

  setUpAll(() => registerFallbackValue(BleInputProperty.notification));

  setUp(() {
    platform = MockPlatform();
    when(() => platform.hasAddressDeviceIds).thenReturn(true);
    UniversalBle.setInstance(platform);
  });

  test('subscribe waits while the user enters the pairing key', () {
    when(() => platform.setNotifiable(any(), any(), any(), any()))
        .thenAnswer((_) => Future.delayed(keyEntry));

    fakeAsync((async) {
      Object? error;
      var done = false;
      UniversalBleAdapter()
          .subscribe(device, service, characteristic)
          .then(
            (_) => done = true,
            onError: (Object e) {
              error = e;
              return false;
            },
          );
      async.elapse(keyEntry + const Duration(seconds: 1));

      expect(error, isNull);
      expect(done, isTrue);
    });
  });

  test('read waits while the user enters the pairing key', () {
    when(() => platform.readValue(any(), any(), any(), timeout: any(named: 'timeout')))
        .thenAnswer((_) => Future.delayed(keyEntry, () => Uint8List.fromList([80])));

    fakeAsync((async) {
      Uint8List? value;
      Object? error;
      UniversalBleAdapter()
          .read(device, service, characteristic)
          .then(
            (v) => value = v,
            onError: (Object e) {
              error = e;
              return Uint8List(0);
            },
          );
      async.elapse(keyEntry + const Duration(seconds: 1));

      expect(error, isNull);
      expect(value, [80]);
    });
  });

  group('pair', () {
    late bool systemPairing;
    late StreamController<bool> pairingState;

    setUp(() {
      systemPairing = BleCapabilities.hasSystemPairingApi;
      pairingState = StreamController.broadcast();
      when(() => platform.pairingStateStream(any())).thenAnswer((_) => pairingState.stream);
      when(() => platform.isPaired(any())).thenAnswer((_) async => false);
    });
    tearDown(() => BleCapabilities.hasSystemPairingApi = systemPairing);

    group('when the device asks to pair as it connects (Android pairs on its own)', () {
      setUp(() {
        BleCapabilities.hasSystemPairingApi = true;
        when(() => platform.pair(any())).thenThrow(
          UniversalBleException(
            code: UniversalBleErrorCode.pairingFailed,
            message: 'Failed to pair',
          ),
        );
      });

      test('waits for the user to accept the system dialog', () async {
        final pair = UniversalBleAdapter().pair(device);
        await pumpEventQueue();
        pairingState.add(true);

        await expectLater(pair, completes);
      });

      test('fails when the user cancels it', () async {
        final pair = UniversalBleAdapter().pair(device);
        await pumpEventQueue();
        pairingState.add(false);

        await expectLater(pair, throwsA(isA<PairingException>()));
      });

      test('is done when it already finished', () async {
        when(() => platform.isPaired(any())).thenAnswer((_) async => true);

        await expectLater(UniversalBleAdapter().pair(device), completes);
      });

      test('gives up when nothing happens', () {
        fakeAsync((async) {
          Object? error;
          UniversalBleAdapter().pair(device).catchError((Object e) {
            error = e;
          });
          async.elapse(UniversalBleAdapter.pairingTimeout + const Duration(seconds: 1));

          expect(error, isA<TimeoutException>());
        });
      });
    });

    test('Android waits while the user enters the pairing key', () {
      BleCapabilities.hasSystemPairingApi = true;
      when(() => platform.pair(any())).thenAnswer((_) => Future.delayed(keyEntry, () => true));

      fakeAsync((async) {
        Object? error;
        var done = false;
        UniversalBleAdapter()
            .pair(device)
            .then(
              (_) => done = true,
              onError: (Object e) {
                error = e;
                return false;
              },
            );
        async.elapse(keyEntry + const Duration(seconds: 1));

        expect(error, isNull);
        expect(done, isTrue);
      });
    });

    test('Android throws when pairing is refused', () async {
      BleCapabilities.hasSystemPairingApi = true;
      when(() => platform.pair(any())).thenAnswer((_) async => false);

      await expectLater(UniversalBleAdapter().pair(device), throwsA(isA<PairingException>()));
    });

    test('iOS leaves pairing to the system', () async {
      BleCapabilities.hasSystemPairingApi = false;

      await UniversalBleAdapter().pair(device);

      verifyNever(() => platform.pair(any()));
    });
  });

  test('subscribe still gives up when nothing answers', () {
    when(() => platform.setNotifiable(any(), any(), any(), any()))
        .thenAnswer((_) => Future.delayed(const Duration(minutes: 5)));

    fakeAsync((async) {
      Object? error;
      UniversalBleAdapter().subscribe(device, service, characteristic).catchError((Object e) {
        error = e;
      });
      async.elapse(UniversalBleAdapter.pairingTimeout + const Duration(seconds: 1));

      expect(error, isNotNull);
      async.elapse(const Duration(minutes: 5)); // let the slow answer finish
    });
  });
}
