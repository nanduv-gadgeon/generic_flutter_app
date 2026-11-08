import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/add_device/add_device_controller.dart';
import 'package:generic_flutter_app/application/device_profiles_provider.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:generic_flutter_app/domain/transport/wifi_provisioner.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/add_device_fakes.dart';
import '../../fixtures/fake_auth.dart';

void main() {
  late AddDeviceFakes fakes;
  late ProviderContainer container;
  late DeviceProfile bleType;
  late DeviceProfile wifiType;
  late DeviceProfile unknownType;

  AddDeviceController controller() => container.read(addDeviceControllerProvider.notifier);
  AddDeviceState state() => container.read(addDeviceControllerProvider);

  setUpAll(() {
    registerFallbackValue(WifiSetupMethod.ble);
    registerFallbackValue(fakeCredentials);
  });

  setUp(() async {
    fakes = AddDeviceFakes();
    container = await fakes.container();
    // Keep the auto-dispose controller alive for the whole test, as the screen does.
    container.listen(addDeviceControllerProvider, (_, _) {});
    final registry = await container.read(deviceProfileRegistryProvider.future);
    bleType = registry.byId('test_device_v1');
    wifiType = registry.byId('wifi_device_v1');
    unknownType = registry.byId('unknown_v1');
  });

  Future<void> toScan() async {
    controller()
      ..selectType(bleType)
      ..continueFromType();
    await controller().continueFromConnection();
  }

  Future<void> toWifiForm({WifiSetupMethod method = WifiSetupMethod.softap}) async {
    controller()
      ..selectType(wifiType)
      ..continueFromType()
      ..selectTransport(Transport.wifi);
    await controller().continueFromConnection();
    controller().selectSetupMethod(method);
  }

  group('steps 1 and 2', () {
    test('only types that can connect can be picked', () {
      controller().selectType(unknownType);
      expect(state().profile, isNull);

      controller().selectType(bleType);
      expect(state().canContinueFromType, isTrue);
    });

    test('a type with one way to connect has it picked on Continue', () {
      controller()
        ..selectType(bleType)
        ..continueFromType();

      expect((state().step, state().transport), (2, Transport.ble));
    });

    test('a type with two ways waits for the user, and changing type clears it', () {
      controller()
        ..selectType(wifiType)
        ..continueFromType();
      expect((state().step, state().transport), (2, null));

      controller().selectTransport(Transport.wifi);
      expect(state().transport, Transport.wifi);

      controller().selectType(bleType);
      expect(state().transport, isNull);
    });
  });

  group('Bluetooth', () {
    test('scans for 20 s, marks devices already added, then stops until Scan again', () async {
      await fakes.devices.addDevice(
        NewDevice(
          userId: fakeUser.id,
          profileId: 'test_device_v1',
          transport: Transport.ble,
          address: fakeFound[1].id,
          name: 'Old',
        ),
        const [],
      );
      await toScan();

      fakes.scanner.results.add(fakeFound);
      await pumpEventQueue();
      final phase = state().phase as Scanning;
      expect(phase.found, fakeFound);
      expect(phase.added, {fakeFound[1].id});
      expect(phase.searching, isTrue);
      expect(fakes.scanner.lastTimeout, const Duration(seconds: 20));

      await fakes.scanner.results.close(); // the 20 s are up
      await pumpEventQueue();
      final stopped = state().phase as Scanning;
      expect((stopped.searching, stopped.found, stopped.added), (false, fakeFound, phase.added));
      expect((state().error, fakes.scanner.scans), (null, 1));

      await controller().startScan();
      expect((state().phase as Scanning).searching, isTrue);
      expect(fakes.scanner.scans, 2);
    });

    test('connect proves the link, saves with the config alerts and a suggested name', () async {
      await toScan();

      await controller().connect(fakeFound.first);

      final link = fakes.links.single;
      expect((link.connected, link.disconnected), (true, true));
      final (device, alerts) = fakes.devices.added.single;
      expect(device.address, 'AA:BB:CC:00:7B:21');
      expect(device.transport, Transport.ble);
      expect(device.name, 'Test device 7B21');
      expect(alerts, bleType.alerts);
      expect(state().step, 4);
      expect(state().phase, isA<Done>());
      expect(fakes.scanner.stopped, isTrue);
    });

    test('a failed connect goes back to the scan with an error and saves nothing', () async {
      fakes.linkFails = true;
      await toScan();

      await controller().connect(fakeFound.first);

      expect((state().step, state().error), (3, AddDeviceError.connectFailed));
      expect(state().phase, isA<Scanning>());
      expect(fakes.devices.added, isEmpty);
    });

    test('no Bluetooth permission shows an error and does not scan', () async {
      fakes.scanner.permission = false;
      await toScan();

      expect(state().error, AddDeviceError.bluetoothPermission);
      expect(fakes.scanner.scans, 0);
    });

    test('a scan error is shown and Try again scans again', () async {
      await toScan();
      fakes.scanner.results.addError(Exception('scan'));
      await pumpEventQueue();
      expect(state().error, AddDeviceError.scanFailed);

      await controller().startScan();
      expect((state().error, fakes.scanner.scans), (null, 2));
    });
  });

  group('Wi‑Fi', () {
    const result = ProvisionResult(deviceId: 'tst-5c1a', address: '192.168.1.20');

    test('hotspot setup: form, join instructions, then send and save', () async {
      when(() => fakes.provisioner.provision(wifiType, WifiSetupMethod.softap, fakeCredentials))
          .thenAnswer((_) async => result);
      await toWifiForm();
      expect(state().phase, isA<WifiForm>());

      await controller().submitWifi(fakeCredentials);
      expect((state().phase as JoinHotspot).ssidPrefix, 'TST-');

      await controller().hotspotJoined();

      final (device, alerts) = fakes.devices.added.single;
      expect(
        (device.transport, device.address, device.ipAddress),
        (Transport.wifi, 'tst-5c1a', '192.168.1.20'),
      );
      expect(alerts, wifiType.alerts);
      expect(state().phase, isA<Done>());
    });

    test('BLE setup scans for setup-mode devices and sends to the one picked', () async {
      when(
        () => fakes.provisioner.provision(
          wifiType,
          WifiSetupMethod.ble,
          fakeCredentials,
          bleDeviceId: fakeFound.first.id,
        ),
      ).thenAnswer((_) async => result);
      await toWifiForm(method: WifiSetupMethod.ble);

      await controller().submitWifi(fakeCredentials);
      expect(fakes.scanner.setupScans, 1);
      expect(state().phase, isA<Scanning>());

      await controller().connect(fakeFound.first);
      expect(fakes.devices.added.single.$1.address, 'tst-5c1a');
    });

    final errors = <String, AddDeviceError>{
      'device not reachable – join its Wi‑Fi first': AddDeviceError.deviceNotReachable,
      'device did not answer': AddDeviceError.deviceNoAnswer,
      'device refused the network': AddDeviceError.setupFailed,
    };
    for (final MapEntry(key: reason, value: error) in errors.entries) {
      test('"$reason" goes back to the form with $error', () async {
        when(() => fakes.provisioner.provision(wifiType, any(), any()))
            .thenThrow(ProvisioningException(reason));
        await toWifiForm();
        await controller().submitWifi(fakeCredentials);

        await controller().hotspotJoined();

        expect((state().step, state().error), (3, error));
        expect(state().phase, isA<WifiForm>());
        expect(fakes.devices.added, isEmpty);
      });
    }
  });

  group('back', () {
    test('steps back from 3 to 1, then lets the screen close', () async {
      await toScan();

      expect(await controller().back(), isTrue);
      expect(state().step, 2);
      expect(fakes.scanner.stopped, isTrue);
      expect(await controller().back(), isTrue);
      expect(state().step, 1);
      expect(await controller().back(), isFalse);
    });

    test('Wi‑Fi hotspot instructions go back to the form', () async {
      await toWifiForm();
      await controller().submitWifi(fakeCredentials);

      expect(await controller().back(), isTrue);
      expect(state().step, 3);
      expect(state().phase, isA<WifiForm>());
    });

    test('step 4 lets the screen close', () async {
      await toScan();
      await controller().connect(fakeFound.first);

      expect(await controller().back(), isFalse);
    });
  });

  test('finish renames only when the name changed', () async {
    await toScan();
    await controller().connect(fakeFound.first);

    expect(await controller().finish('Test device 7B21'), 1);
    expect(fakes.devices.renamed, isEmpty);
    expect(await controller().finish('  Bedroom '), 1);
    expect(fakes.devices.renamed, [(1, 'Bedroom')]);
  });

  test('leaving the flow stops the scan', () async {
    final sub = container.listen(addDeviceControllerProvider, (_, _) {});
    await toScan();

    sub.close();
    container.invalidate(addDeviceControllerProvider);
    await pumpEventQueue();

    expect(fakes.scanner.stopped, isTrue);
  });
}
