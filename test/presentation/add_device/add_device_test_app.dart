// Shared by the Add device screen tests.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/core/config/config_sections.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/presentation/add_device/add_device_screen.dart';
import 'package:go_router/go_router.dart';

import '../../fixtures/add_device_fakes.dart';
import '../../fixtures/l10n.dart';

export '../../fixtures/add_device_fakes.dart';

const _theme = ThemeConfig(
  primary: '#123456',
  accent: '#ABCDEF',
  font: 'TestFont',
  cornerRadius: 20,
  cornerRadiusSmall: 12,
  mode: ThemeModeSetting.light,
);

/// Fresh fakes for each test (set in `setUp`).
late AddDeviceFakes fakes;

Future<void> pumpAddDevice(
  WidgetTester tester, {
  bool isCloud = false,
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),

  /// On by default so the scan pulse stays still and `pumpAndSettle` can settle.
  bool reduceMotion = true,
}) async {
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home page')),
      ),
      GoRoute(path: '/add', builder: (_, _) => const AddDeviceScreen()),
      GoRoute(
        path: '/device/:id',
        builder: (_, s) => Scaffold(body: Text('dashboard ${s.pathParameters['id']}')),
      ),
    ],
  );
  final container = ProviderContainer(overrides: fakes.overrides(isCloud: isCloud));
  addTearDown(container.dispose);
  await container.read(appConfigProvider.future);
  await container.read(authControllerProvider.future);

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
  unawaited(router.push('/add'));
  await tester.pumpAndSettle();
}

Finder button(String label) => find.widgetWithText(FilledButton, label);

bool isEnabled(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(button(label)).onPressed != null;

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Step 1 to the BLE scan for the BLE-only test type.
Future<void> toScan(WidgetTester tester) async {
  await tapAndSettle(tester, find.text('Test device'));
  await tapAndSettle(tester, button('Continue'));
  await tapAndSettle(tester, button('Continue'));
}

/// Step 1 to the Wi‑Fi form for the BLE + Wi‑Fi test type.
Future<void> toWifiForm(WidgetTester tester) async {
  await tapAndSettle(tester, find.text('Test sensor'));
  await tapAndSettle(tester, button('Continue'));
  await tapAndSettle(tester, find.text('Wi‑Fi'));
  await tapAndSettle(tester, button('Continue'));
}
