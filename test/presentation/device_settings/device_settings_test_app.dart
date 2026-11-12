// Shared by the Device settings screen tests. Fake data only.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';
import 'package:generic_flutter_app/presentation/device_settings/device_settings_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/fake_auth.dart';
import '../../fixtures/test_config.dart';
import '../../fixtures/l10n.dart';

class MockDeviceService extends Mock implements DeviceService {}

const _theme = ThemeConfig(
  primary: '#123456',
  accent: '#ABCDEF',
  font: 'TestFont',
  cornerRadius: 20,
  cornerRadiusSmall: 12,
  mode: ThemeModeSetting.light,
);

/// 12 s after [band]'s last heartbeat.
final testNow = DateTime(2026, 1, 1, 9, 0, 12);

/// A BLE device of the test config's type ("Test device": readings Current (u) and Battery (%)).
final band = DeviceDetails(
  id: 7,
  name: 'Test band',
  profileId: 'test_device_v1',
  transport: Transport.ble,
  address: 'AA:BB:CC:00:00:01',
  firmware: '1.4.2',
  batteryPercent: 78,
  lastHeartbeatAt: DateTime(2026, 1, 1, 9),
  alerts: const [
    AlertSetting(rule: AlertRule(key: 'battery', below: 15), enabled: true),
    AlertSetting(rule: AlertRule(key: 'current', above: 25), enabled: false),
  ],
);

/// The screen's device service and the stream it watches; set by [pumpSettings].
late MockDeviceService devices;
late StreamController<DeviceDetails?> deviceStream;

/// Opens Device settings for [device] (null: no such device) over a stand-in home page.
Future<void> pumpSettings(
  WidgetTester tester, {
  DeviceDetails? device,
  int historyDays = 7,
  ActiveLink? activeLink,
  Map<String, dynamic>? heartbeat,
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 1600),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = MockAuthService();
  when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
  devices = MockDeviceService();
  deviceStream = StreamController<DeviceDetails?>();
  addTearDown(deviceStream.close);
  deviceStream.add(device);
  when(() => devices.watchDevice(fakeUser.id, any())).thenAnswer((_) => deviceStream.stream);
  when(() => devices.rename(any(), any())).thenAnswer((_) async {});
  when(() => devices.setAlertEnabled(any(), any(), enabled: any(named: 'enabled')))
      .thenAnswer((_) async {});
  when(() => devices.removeDevice(any(), any())).thenAnswer((_) async => deviceStream.add(null));

  final json = validConfigJson()..['history'] = {'daysOnPhone': historyDays};
  if (heartbeat != null) {
    ((json['deviceProfiles'] as List).single as Map<String, dynamic>)['heartbeat'] = heartbeat;
  }
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith((_) async => AppConfig.fromJson(json)),
      authServiceProvider.overrideWithValue(auth),
      deviceServiceProvider.overrideWithValue(devices),
      clockProvider.overrideWithValue(() => testNow),
      activeLinkProvider.overrideWith((_) => Stream.value(activeLink)),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appConfigProvider.future);
  await container.read(authControllerProvider.future);

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home page')),
      ),
      GoRoute(
        path: DeviceSettingsScreen.path,
        builder: (_, s) => DeviceSettingsScreen(deviceId: int.parse(s.pathParameters['id']!)),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(_theme, brightness),
        routerConfig: router,
      ),
    ),
  );
  unawaited(router.push(DeviceSettingsScreen.route(device?.id ?? 7)));
  await tester.pumpAndSettle();
}
