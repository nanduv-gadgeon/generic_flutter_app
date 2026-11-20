import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/alerts_provider.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/application/device_profiles_provider.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/device_profile_registry.dart';
import 'package:generic_flutter_app/core/di/alerts.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/services/alert_repository.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/fake_auth.dart';
import '../fixtures/test_config.dart';

class MockDeviceService extends Mock implements DeviceService {}

class MockAlertRepository extends Mock implements AlertRepository {}

const _band = UserDevice(id: 1, name: 'Test band', profileId: 'test_device_v1');
const _old = UserDevice(id: 2, name: 'Old sensor', profileId: 'gone_v1');

final _at = DateTime.utc(2026, 10, 24, 9);

RaisedAlert _alert(int deviceId, AlertKind kind, {String? key, bool read = false}) => RaisedAlert(
  id: deviceId * 10 + kind.index,
  deviceId: deviceId,
  kind: kind,
  key: key,
  value: 30,
  limit: 25,
  at: _at,
  read: read,
);

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
    when(() => alerts.markAllRead(any())).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        deviceServiceProvider.overrideWithValue(devices),
        alertRepositoryProvider.overrideWithValue(alerts),
        deviceProfileRegistryProvider.overrideWith(
          (ref) async => DeviceProfileRegistry(AppConfig.fromJson(validConfigJson())),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> logIn() async {
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
    await container.read(authControllerProvider.future);
  }

  /// Reads the list while listening, so the provider is not disposed mid-load.
  Future<List<AlertListItem>> listNow() async {
    final sub = container.listen(alertListProvider, (_, _) {});
    addTearDown(sub.close);
    return container.read(alertListProvider.future);
  }

  test('nobody logged in: no alerts and no repository call', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => null);
    await container.read(authControllerProvider.future);

    expect(await listNow(), isEmpty);
    verifyNever(() => alerts.watchAll(any()));
  });

  test('each alert comes with its device name, profile reading and missed count', () async {
    await logIn();
    when(() => devices.watchDevices(fakeUser.id)).thenAnswer((_) => Stream.value([_band]));
    final above = _alert(1, AlertKind.above, key: 'current');
    final battery = _alert(1, AlertKind.batteryLow, key: 'battery');
    final offline = _alert(1, AlertKind.offline);
    when(() => alerts.watchAll(fakeUser.id))
        .thenAnswer((_) => Stream.value([above, battery, offline]));

    final list = await listNow();

    expect([for (final i in list) i.alert], [above, battery, offline]);
    expect({for (final i in list) i.deviceName}, {'Test band'});
    expect([for (final i in list) i.reading?.label], ['Current', 'Battery', null]);
    expect({for (final i in list) i.offlineAfterMissed}, {3});
  });

  test('an alert of a device no longer in the list is left out', () async {
    await logIn();
    when(() => devices.watchDevices(fakeUser.id)).thenAnswer((_) => Stream.value([_band]));
    when(
      () => alerts.watchAll(fakeUser.id),
    ).thenAnswer((_) => Stream.value([_alert(9, AlertKind.offline), _alert(1, AlertKind.offline)]));

    expect([for (final i in await listNow()) i.alert.deviceId], [1]);
  });

  test('a device type the config no longer has: shown without a reading', () async {
    await logIn();
    when(() => devices.watchDevices(fakeUser.id)).thenAnswer((_) => Stream.value([_old]));
    when(() => alerts.watchAll(fakeUser.id))
        .thenAnswer((_) => Stream.value([_alert(2, AlertKind.above, key: 'co2')]));

    final [item] = await listNow();

    expect(item.deviceName, 'Old sensor');
    expect(item.reading, isNull);
    expect(item.offlineAfterMissed, 3);
  });

  test('new alerts come through as they are stored', () async {
    await logIn();
    when(() => devices.watchDevices(fakeUser.id)).thenAnswer((_) => Stream.value([_band]));
    final stored = StreamController<List<RaisedAlert>>();
    addTearDown(stored.close);
    when(() => alerts.watchAll(fakeUser.id)).thenAnswer((_) => stored.stream);
    final seen = <int>[];
    container.listen(
      alertListProvider,
      (_, next) => seen.add(next.value?.length ?? -1),
      fireImmediately: true,
    );

    stored.add([]);
    await pumpEventQueue();
    stored.add([_alert(1, AlertKind.offline)]);
    await pumpEventQueue();

    expect(seen.where((n) => n >= 0), [0, 1]);
  });

  test('Mark all read marks the logged-in user\'s alerts', () async {
    await logIn();

    await container.read(markAllAlertsReadProvider)();

    verify(() => alerts.markAllRead(fakeUser.id)).called(1);
  });

  test('Mark all read does nothing when nobody is logged in', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => null);
    await container.read(authControllerProvider.future);

    await container.read(markAllAlertsReadProvider)();

    verifyNever(() => alerts.markAllRead(any()));
  });

  group('deleting', () {
    final alert = _alert(1, AlertKind.offline);
    setUp(() {
      when(() => alerts.delete(any(), any())).thenAnswer((_) async {});
      when(() => alerts.deleteAll(any())).thenAnswer((_) async {});
      when(() => alerts.add(alert)).thenAnswer((_) async => 9);
    });

    final cases = <(String, Future<void> Function(ProviderContainer), void Function())>[
      (
        'one alert',
        (c) => c.read(deleteAlertProvider)(7),
        () => verify(() => alerts.delete(fakeUser.id, 7)).called(1),
      ),
      (
        'all alerts',
        (c) => c.read(clearAlertsProvider)(),
        () => verify(() => alerts.deleteAll(fakeUser.id)).called(1),
      ),
      (
        'Undo stores it again',
        (c) => c.read(restoreAlertProvider)(alert),
        () => verify(() => alerts.add(alert)).called(1),
      ),
    ];

    for (final (name, run, check) in cases) {
      test('$name for the logged-in user', () async {
        await logIn();
        await run(container);
        check();
      });

      test('$name: nothing when nobody is logged in', () async {
        when(() => auth.currentUser()).thenAnswer((_) async => null);
        await container.read(authControllerProvider.future);
        await run(container);
        verifyNever(() => alerts.delete(any(), any()));
        verifyNever(() => alerts.deleteAll(any()));
        verifyNever(() => alerts.add(alert));
      });
    }
  });

  test('the minute tick gives the time now and again every minute', () {
    fakeAsync((async) {
      var now = DateTime(2026, 10, 24, 12);
      final ticks = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => now)]);
      final seen = <DateTime>[];
      ticks.listen(minuteTickProvider, (_, next) {
        if (next.value case final t?) seen.add(t);
      }, fireImmediately: true);

      async.flushMicrotasks();
      now = DateTime(2026, 10, 24, 12, 1);
      async.elapse(const Duration(minutes: 1));
      now = DateTime(2026, 10, 24, 12, 2);
      async.elapse(const Duration(minutes: 1));

      expect(seen, [
        DateTime(2026, 10, 24, 12),
        DateTime(2026, 10, 24, 12, 1),
        DateTime(2026, 10, 24, 12, 2),
      ]);
      ticks.dispose();
    });
  });
}
