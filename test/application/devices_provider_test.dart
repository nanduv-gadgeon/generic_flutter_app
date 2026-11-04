import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/fake_auth.dart';

class MockDeviceService extends Mock implements DeviceService {}

const _band = UserDevice(id: 1, name: 'Test band', profileId: 'test_device_v1');
const _sensor = UserDevice(id: 2, name: 'Test sensor', profileId: 'test_device_v1');

void main() {
  late MockAuthService auth;
  late MockDeviceService devices;
  late ProviderContainer container;

  setUp(() {
    auth = MockAuthService();
    devices = MockDeviceService();
    when(() => auth.logout()).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        deviceServiceProvider.overrideWithValue(devices),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Reads the list while listening, so the provider is not disposed mid-load.
  Future<List<UserDevice>> devicesNow() async {
    final sub = container.listen(myDevicesProvider, (_, _) {});
    addTearDown(sub.close);
    return container.read(myDevicesProvider.future);
  }

  test('nobody logged in: no devices and no service call', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => null);
    await container.read(authControllerProvider.future);

    expect(await devicesNow(), isEmpty);
    verifyNever(() => devices.watchDevices(any()));
  });

  test('lists the logged-in user\'s devices', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
    when(() => devices.watchDevices(fakeUser.id)).thenAnswer((_) => Stream.value([_band]));
    await container.read(authControllerProvider.future);

    expect(await devicesNow(), [_band]);
  });

  // devices stored -> summary shown
  final summaries = <List<UserDevice>, HomeSummary>{
    []: (devices: 0, connected: 0, alerts: 0),
    [_band]: (devices: 1, connected: 0, alerts: 0),
    [_band, _sensor]: (devices: 2, connected: 0, alerts: 0),
  };
  for (final MapEntry(key: list, value: expected) in summaries.entries) {
    test('summary for ${list.length} devices', () async {
      when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
      when(() => devices.watchDevices(fakeUser.id)).thenAnswer((_) => Stream.value(list));
      await container.read(authControllerProvider.future);
      await devicesNow();

      expect(container.read(homeSummaryProvider), expected);
    });
  }

  test('logging out clears the list', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
    when(() => devices.watchDevices(fakeUser.id)).thenAnswer((_) => Stream.value([_band]));
    await container.read(authControllerProvider.future);
    expect(await devicesNow(), [_band]);

    await container.read(authControllerProvider.notifier).logout();

    expect(await devicesNow(), isEmpty);
  });
}
