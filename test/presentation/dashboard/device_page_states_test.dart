import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/device_settings_provider.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/domain/models/device_details.dart';
import 'package:generic_flutter_app/domain/models/user_device.dart';
import 'package:generic_flutter_app/presentation/dashboard/device_page_states.dart';
import 'package:generic_flutter_app/presentation/dashboard/live_device_screen.dart';
import 'package:go_router/go_router.dart';

import '../../fixtures/dashboard_harness.dart';
import '../../fixtures/l10n.dart';
import '../../fixtures/scripted_live_readings.dart';

final _now = DateTime.utc(2026, 11, 11, 9);

const _band = UserDevice(id: 3, name: 'Band', profileId: 'smart_band_v1');

/// Just saved by Add device: in the database, not yet in My devices.
const _added = UserDevice(id: 5, name: 'Therapy', profileId: 'ief_device_v1');
const _addedDetails = DeviceDetails(
  id: 5,
  name: 'Therapy',
  profileId: 'ief_device_v1',
  transport: Transport.ble,
  address: 'AA:BB:CC:DD:EE:05',
);

/// What the device page shows before its dashboard: a spinner while the device or its type is
/// loading, "Device not found" when it is not the user's or its type is gone. Never placeholder
/// text (it once flashed "Device dashboard (later task)" right after Add device).
void main() {
  late StreamController<List<UserDevice>> myDevices;
  late StreamController<DeviceDetails?> details;

  setUp(() {
    myDevices = StreamController();
    details = StreamController();
  });

  tearDown(() async {
    await myDevices.close();
    await details.close();
  });

  Future<void> pump(WidgetTester tester, {required int deviceId}) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/device/$deviceId',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/device/:id',
          builder: (_, _) => LiveDeviceScreen(deviceId: deviceId),
          routes: [GoRoute(path: 'settings', builder: (_, _) => const Text('settings'))],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...dashboardOverrides(
            live: ScriptedLiveReadings(),
            devices: const [],
            now: _now,
            deviceUpdates: myDevices.stream,
          ),
          deviceDetailsProvider(deviceId).overrideWith((ref) => details.stream),
        ],
        child: MaterialApp.router(
          theme: buildTheme(testTheme, Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
  }

  Finder notFound() => find.text(en.deviceNotFoundTitle);

  testWidgets('just after Add device: a spinner, then the dashboard, never "not found"', (
    tester,
  ) async {
    await pump(tester, deviceId: 5);
    myDevices.add(const [_band]); // The list has not caught up yet.
    details.add(_addedDetails);
    await tester.pump();

    expect(find.byType(DeviceLoading), findsOneWidget);
    expect(notFound(), findsNothing);
    expect(find.textContaining('later task'), findsNothing);

    myDevices.add(const [_band, _added]);
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }

    expect(find.byType(DeviceLoading), findsNothing);
    expect(find.text('Therapy'), findsOneWidget); // The dashboard header.

    // Its settings button opens Device settings.
    await tester.tap(find.byTooltip(en.deviceSettingsOpen));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('settings'), findsOneWidget);
  });

  testWidgets('while the device is loading, the spinner says "Loading" to screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, deviceId: 5);
    await tester.pump();

    expect(find.byType(DeviceLoading), findsOneWidget);
    expect(find.bySemanticsLabel(en.commonLoading), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a removed device says so, and Back goes to My devices', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, deviceId: 9);
    myDevices.add(const [_band]);
    details.add(null);
    await tester.pump();

    expect(notFound(), findsOneWidget);
    expect(find.text(en.deviceNotFoundBody), findsOneWidget);
    expect(find.byTooltip(en.commonBack), findsOneWidget); // Read out by screen readers.

    await tester.tap(find.text(en.deviceNotFoundBack));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a device whose type is no longer in the config is not found', (tester) async {
    await pump(tester, deviceId: 7);
    myDevices.add(const [UserDevice(id: 7, name: 'Old', profileId: 'retired_v1')]);
    await tester.pump();
    await tester.pump();

    expect(notFound(), findsOneWidget);
  });
}
