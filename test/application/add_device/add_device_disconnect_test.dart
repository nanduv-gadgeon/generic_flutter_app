import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/add_device/add_device_controller.dart';
import 'package:generic_flutter_app/application/device_profiles_provider.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';

import '../../fixtures/add_device_fakes.dart';
import '../../fixtures/fake_auth.dart';

/// "Disconnect" on a device already added (step 3): it is removed so it can be added again.
void main() {
  late AddDeviceFakes fakes;
  late ProviderContainer container;

  AddDeviceController controller() => container.read(addDeviceControllerProvider.notifier);
  AddDeviceState state() => container.read(addDeviceControllerProvider);
  Scanning scanning() => state().phase as Scanning;

  setUp(() async {
    fakes = AddDeviceFakes();
    container = await fakes.container();
    container.listen(addDeviceControllerProvider, (_, _) {});
    final registry = await container.read(deviceProfileRegistryProvider.future);

    await fakes.devices.addDevice(
      NewDevice(
        userId: fakeUser.id,
        profileId: 'test_device_v1',
        transport: Transport.ble,
        address: fakeFound.first.id,
        name: 'Old',
      ),
      const [],
    );
    controller()
      ..selectType(registry.byId('test_device_v1'))
      ..continueFromType();
    await controller().continueFromConnection();
    fakes.scanner.results.add(fakeFound);
    await pumpEventQueue();
  });

  test('removes the device and shows it as not added, still scanning', () async {
    expect(scanning().added, {fakeFound.first.id});

    await controller().disconnect(fakeFound.first);

    expect(await fakes.devices.isAdded(fakeUser.id, fakeFound.first.id), isFalse);
    expect(scanning().added, isEmpty);
    expect(scanning().found, fakeFound);
    expect((state().step, state().error), (3, null));
    expect(fakes.scanner.stopped, isFalse);
  });

  test('a failed remove keeps the device and shows an error', () async {
    fakes.devices.removeFails = true;

    await controller().disconnect(fakeFound.first);

    expect(state().error, AddDeviceError.removeFailed);
    expect(scanning().added, {fakeFound.first.id});
    expect(await fakes.devices.isAdded(fakeUser.id, fakeFound.first.id), isTrue);
  });

  test('a device not added is left alone', () async {
    await controller().disconnect(fakeFound[1]);

    expect(fakes.devices.devices, hasLength(1));
    expect(state().error, isNull);
  });
}
