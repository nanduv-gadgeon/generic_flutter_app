import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/core/di/alerts.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/services/alert_repository.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/fake_auth.dart';

class MockDeviceService extends Mock implements DeviceService {}

class MockAlertRepository extends Mock implements AlertRepository {}

const _band = UserDevice(id: 1, name: 'Test band', profileId: 'test_device_v1');
const _sensor = UserDevice(id: 2, name: 'Test sensor', profileId: 'test_device_v1');

void main() {
  late MockAuthService auth;
  late MockDeviceService devices;
  late MockAlertRepository alerts;
  late ProviderContainer container;

  setUp(() {
    auth = MockAuthService();
    devices = MockDeviceService();
    alerts = MockAlertRepository();
    when(() => alerts.watchUnreadCount(any())).thenAnswer((_) => Stream.value(0));
    when(() => auth.logout()).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        deviceServiceProvider.overrideWithValue(devices),
        alertRepositoryProvider.overrideWithValue(alerts),
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

  test('the summary counts the user\'s unread alerts', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
    when(() => devices.watchDevices(fakeUser.id)).thenAnswer((_) => Stream.value([_band]));
    when(() => alerts.watchUnreadCount(fakeUser.id)).thenAnswer((_) => Stream.value(3));
    await container.read(authControllerProvider.future);
    await devicesNow();
    final sub = container.listen(unreadAlertCountProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(unreadAlertCountProvider.future);

    expect(container.read(homeSummaryProvider).alerts, 3);
  });

  test('logging out clears the list', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
    when(() => devices.watchDevices(fakeUser.id)).thenAnswer((_) => Stream.value([_band]));
    await container.read(authControllerProvider.future);
    expect(await devicesNow(), [_band]);

    await container.read(authControllerProvider.notifier).logout();

    expect(await devicesNow(), isEmpty);
  });

  test('saveDeviceOrder saves for the logged-in user', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
    when(() => devices.reorder(any(), any())).thenAnswer((_) async {});
    await container.read(authControllerProvider.future);

    await container.read(saveDeviceOrderProvider)([2, 1]);

    verify(() => devices.reorder(fakeUser.id, [2, 1])).called(1);
  });

  test('saveDeviceOrder saves nothing when nobody is logged in', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => null);
    await container.read(authControllerProvider.future);

    await container.read(saveDeviceOrderProvider)([2, 1]);

    verifyNever(() => devices.reorder(any(), any()));
  });

  test('removeDevice removes for the logged-in user', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
    when(() => devices.removeById(any(), any())).thenAnswer((_) async {});
    await container.read(authControllerProvider.future);

    await container.read(removeDeviceProvider)(2);

    verify(() => devices.removeById(fakeUser.id, 2)).called(1);
  });

  test('removeDevice removes nothing when nobody is logged in', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => null);
    await container.read(authControllerProvider.future);

    await container.read(removeDeviceProvider)(2);

    verifyNever(() => devices.removeById(any(), any()));
  });
}
