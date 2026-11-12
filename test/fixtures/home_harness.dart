// Shared set-up for the My devices tests.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/application/device_profiles_provider.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/device_profile_registry.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/domain/services/auth_service.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';
import 'package:generic_flutter_app/domain/services/reading_repository.dart';
import 'package:generic_flutter_app/presentation/devices/home_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_auth.dart';
import 'l10n.dart';

class MockDeviceService extends Mock implements DeviceService {}

class MockLiveReadings extends Mock implements LiveReadings {}

class MockReadingRepository extends Mock implements ReadingRepository {}

final _config = AppConfig.fromJson(
  jsonDecode(File('assets/config/vitacare/app_config.json').readAsStringSync())
      as Map<String, dynamic>,
);
final _registry = DeviceProfileRegistry(_config);

const _theme = ThemeConfig(
  primary: '#123456',
  accent: '#ABCDEF',
  font: 'TestFont',
  cornerRadius: 20,
  cornerRadiusSmall: 12,
  mode: ThemeModeSetting.light,
);

/// Pumps My devices with fakes for the user, devices, stored readings and the linked device.
/// Returns the device service, e.g. to check what was saved or removed.
Future<MockDeviceService> pumpHome(
  WidgetTester tester, {
  List<UserDevice> devices = const [],
  DateTime? now,
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
  AuthUser user = fakeUser,
  Map<int, Map<String, Sample>> latest = const {},
  ActiveLink? active,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = MockAuthService();
  final deviceService = MockDeviceService();
  when(() => auth.currentUser()).thenAnswer((_) async => user);
  when(() => deviceService.watchDevices(any())).thenAnswer((_) => Stream.value(devices));
  when(() => deviceService.reorder(any(), any())).thenAnswer((_) async {});
  when(() => deviceService.removeById(any(), any())).thenAnswer((_) async {});
  final live = MockLiveReadings();
  when(live.watchActive).thenAnswer((_) => Stream.value(active));
  final readings = MockReadingRepository();
  when(() => readings.watchLatest(any()))
      .thenAnswer((i) => Stream.value(latest[i.positionalArguments.single] ?? const {}));

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: HomeScreen()),
      ),
      GoRoute(path: '/add', builder: (_, _) => const Text('add device page')),
      GoRoute(
        path: '/device/:id',
        builder: (_, state) => Text('device page ${state.pathParameters['id']}'),
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(auth),
      deviceServiceProvider.overrideWithValue(deviceService),
      liveReadingsProvider.overrideWithValue(live),
      readingRepositoryProvider.overrideWithValue(readings),
      appConfigProvider.overrideWith((ref) async => _config),
      deviceProfileRegistryProvider.overrideWith((ref) async => _registry),
      clockProvider.overrideWithValue(() => now ?? DateTime(2026, 1, 1, 9)),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);
  await container.read(appConfigProvider.future);

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
  await tester.pumpAndSettle();
  return deviceService;
}
