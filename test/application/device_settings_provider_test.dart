import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/application/device_settings_provider.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/fake_auth.dart';

class MockDeviceService extends Mock implements DeviceService {}

const _band = DeviceDetails(
  id: 7,
  name: 'Test band',
  profileId: 'test_device_v1',
  transport: Transport.ble,
  address: 'AA:BB:CC:00:00:01',
);

void main() {
  late MockAuthService auth;
  late MockDeviceService devices;

  setUp(() {
    auth = MockAuthService();
    devices = MockDeviceService();
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
    when(() => devices.rename(any(), any())).thenAnswer((_) async {});
    when(() => devices.removeDevice(any(), any())).thenAnswer((_) async {});
    when(() => devices.setAlertEnabled(any(), any(), enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
  });

  Future<ProviderContainer> container({bool loggedIn = true}) async {
    if (!loggedIn) when(() => auth.currentUser()).thenAnswer((_) async => null);
    final c = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        deviceServiceProvider.overrideWithValue(devices),
      ],
    );
    addTearDown(c.dispose);
    await c.read(authControllerProvider.future);
    return c;
  }

  /// The provider is auto-dispose: keep it listened to while the stream emits.
  Future<DeviceDetails?> details(ProviderContainer c, int id) {
    final sub = c.listen(deviceDetailsProvider(id), (_, _) {});
    addTearDown(sub.close);
    return c.read(deviceDetailsProvider(id).future);
  }

  test('deviceDetails watches the logged-in user\'s device', () async {
    when(() => devices.watchDevice(fakeUser.id, 7)).thenAnswer((_) => Stream.value(_band));
    final c = await container();

    expect(await details(c, 7), _band);
  });

  test('deviceDetails is null when nobody is logged in', () async {
    final c = await container(loggedIn: false);

    expect(await details(c, 7), isNull);
    verifyNever(() => devices.watchDevice(any(), any()));
  });

  // typed name -> saved as (null = not saved)
  final renames = <String, String?>{
    'Kitchen band': 'Kitchen band',
    '  Kitchen band  ': 'Kitchen band',
    'B' * 40: 'B' * 40,
    '': null,
    '   ': null,
    'B' * 41: null,
  };
  for (final MapEntry(key: typed, value: saved) in renames.entries) {
    test('rename "${typed.length > 12 ? '${typed.length} chars' : typed}" -> $saved', () async {
      final c = await container();

      final ok = await c.read(deviceSettingsControllerProvider.notifier).rename(7, typed);

      expect(ok, saved != null);
      if (saved == null) {
        verifyNever(() => devices.rename(any(), any()));
      } else {
        verify(() => devices.rename(7, saved)).called(1);
      }
    });
  }

  test('setAlert turns the alert on or off', () async {
    final c = await container();

    await c.read(deviceSettingsControllerProvider.notifier).setAlert(7, 'battery', enabled: false);

    verify(() => devices.setAlertEnabled(7, 'battery', enabled: false)).called(1);
  });

  test('remove deletes the user\'s device by its address', () async {
    final c = await container();

    await c.read(deviceSettingsControllerProvider.notifier).remove(_band);

    verify(() => devices.removeDevice(fakeUser.id, 'AA:BB:CC:00:00:01')).called(1);
  });
}
