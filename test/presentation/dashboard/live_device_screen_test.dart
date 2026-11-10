import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/device_profiles_provider.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/device_profile_registry.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/domain/models/user_device.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';
import 'package:generic_flutter_app/presentation/dashboard/live_device_screen.dart';
import 'package:go_router/go_router.dart';

const _theme = ThemeConfig(
  primary: '#123456',
  accent: '#ABCDEF',
  font: 'TestFont',
  cornerRadius: 20,
  cornerRadiusSmall: 12,
  mode: ThemeModeSetting.light,
);

/// Live readings the test sends by hand; counts who listens.
class _FakeLiveReadings implements LiveReadings {
  StreamController<LiveUpdate>? controller;
  int listens = 0;
  int cancels = 0;
  final retried = <int>[];

  @override
  Stream<LiveUpdate> watch(int deviceId) {
    controller = StreamController(onListen: () => listens++, onCancel: () => cancels++);
    return controller!.stream;
  }

  @override
  Stream<ActiveLink?> watchActive() => Stream.value(null);

  @override
  Future<void> retry(int deviceId) async => retried.add(deviceId);

  @override
  Future<void> start(int userId) async {}

  @override
  Future<void> stop() async {}

  void send(LiveUpdate update) => controller!.add(update);
}

final _registry = DeviceProfileRegistry(
  AppConfig.fromJson(
    jsonDecode(File('assets/config/vitacare/app_config.json').readAsStringSync())
        as Map<String, dynamic>,
  ),
);

final _t = DateTime.utc(2026, 11, 3);

const _sensor = UserDevice(id: 1, name: 'Finger sensor', profileId: 'ppg_motion_v1');
const _patch = UserDevice(id: 2, name: 'Patch', profileId: 'ief_device_v1');
const _band = UserDevice(id: 3, name: 'Band', profileId: 'smart_band_v1');

void main() {
  late _FakeLiveReadings live;
  late ValueNotifier<bool> open;

  setUp(() {
    live = _FakeLiveReadings();
    open = ValueNotifier(true);
  });

  Future<void> pump(
    WidgetTester tester, {
    int deviceId = 1,
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 844),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveReadingsProvider.overrideWithValue(live),
          myDevicesProvider.overrideWith((ref) => Stream.value(const [_sensor, _patch, _band])),
          deviceProfileRegistryProvider.overrideWith((ref) async => _registry),
        ],
        child: MaterialApp(
          theme: buildTheme(_theme, brightness),
          home: ValueListenableBuilder(
            valueListenable: open,
            builder: (_, isOpen, _) =>
                isOpen ? LiveDeviceScreen(deviceId: deviceId) : const Text('closed'),
          ),
        ),
      ),
    );
    // The connecting spinner never settles; a few frames let the device list and profiles load.
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  }

  Future<void> send(WidgetTester tester, List<LiveUpdate> updates) async {
    updates.forEach(live.send);
    await tester.pump();
  }

  testWidgets('connects when opened and shows "–" until values arrive', (tester) async {
    await pump(tester);

    expect(live.listens, 1);
    expect(find.text('Finger sensor'), findsOneWidget);
    expect(find.text('Connecting…'), findsOneWidget);
    expect(find.text('–'), findsNWidgets(5)); // 4 readings and battery
    expect(find.bySemanticsLabel('Heart rate, no reading yet'), findsOneWidget);
    expect(find.bySemanticsLabel('Connecting…'), findsOneWidget);
  });

  testWidgets('shows each reading with its unit and decimals, and the battery', (tester) async {
    await pump(tester);
    await send(tester, [
      const LiveStatusChanged(LiveStatus.streaming),
      LiveValue(Sample('heart_rate', 72, _t)),
      LiveValue(Sample('spo2', 97, _t)),
      LiveValue(Sample('pi_red', 0.7206, _t)),
      LiveValue(Sample('pi_ir', 1.4369, _t)),
      LiveValue(Sample('battery', 81, _t)),
    ]);

    expect(find.text('Live'), findsOneWidget);
    for (final text in ['72 bpm', '97 %', '0.72 %', '1.44 %', '81 %']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.bySemanticsLabel('Heart rate, 72 bpm'), findsOneWidget);
    expect(find.bySemanticsLabel('PI (IR), 1.44 %'), findsOneWidget);
  });

  testWidgets('says why it stopped, and Try again connects again', (tester) async {
    await pump(tester);
    await send(tester, [
      const LiveFailure(LiveFailureReason.startFailed, problem: DeviceProblem.lowBattery),
    ]);

    expect(find.text('The device battery is low. Charge it, then try again.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(live.retried, [_sensor.id]);
    expect(find.textContaining('battery is low'), findsNothing);
  });

  testWidgets('streaming again clears the problem', (tester) async {
    await pump(tester);
    await send(tester, [
      const LiveFailure(LiveFailureReason.deviceProblem, problem: DeviceProblem.transferError),
      const LiveStatusChanged(LiveStatus.reconnecting),
    ]);
    expect(find.text('The device stopped sending. Try again.'), findsOneWidget);
    expect(find.text('Connection lost. Reconnecting…'), findsOneWidget);

    await send(tester, [const LiveStatusChanged(LiveStatus.streaming)]);
    expect(find.textContaining('stopped sending'), findsNothing);
  });

  testWidgets('closing the screen stops listening (the device stays connected)', (tester) async {
    await pump(tester);
    open.value = false;
    await tester.pump();

    expect(live.cancels, 1);
  });

  testWidgets('a device type without a protocol keeps the placeholder', (tester) async {
    await pump(tester, deviceId: _band.id);

    expect(find.text('Device dashboard (later task)'), findsWidgets);
    expect(live.listens, 0);
  });

  final statuses = {
    LiveStatus.syncing: 'Getting stored readings…',
    LiveStatus.waiting: 'Device not found. Trying again…',
  };
  for (final MapEntry(key: status, value: text) in statuses.entries) {
    testWidgets('a device that syncs its logs shows "$text" while ${status.name}', (tester) async {
      await pump(tester, deviceId: _patch.id);
      await send(tester, [LiveStatusChanged(status)]);

      expect(live.listens, 1);
      expect(find.text(text), findsOneWidget);
      expect(find.bySemanticsLabel(text), findsWidgets);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('fits a small phone with double text size (${brightness.name})', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, brightness: brightness, size: const Size(320, 568));
      await send(tester, [
        const LiveFailure(LiveFailureReason.connectFailed),
        LiveValue(Sample('pi_red', 12.3456, _t)),
      ]);

      expect(tester.takeException(), isNull);
    });
  }

  final hints = <SensorContact, String?>{
    SensorContact.none: 'Place your finger on the sensor',
    SensorContact.settling: 'Measuring… hold still',
    SensorContact.ok: null,
  };
  for (final MapEntry(key: contact, value: hint) in hints.entries) {
    testWidgets('while streaming, contact ${contact.name} shows ${hint ?? 'no hint'}', (
      tester,
    ) async {
      await pump(tester);
      await send(tester, [
        const LiveStatusChanged(LiveStatus.streaming),
        LiveContactChanged(contact),
      ]);

      if (hint == null) {
        expect(find.byIcon(Icons.touch_app_outlined), findsNothing);
      } else {
        expect(find.text(hint), findsOneWidget);
        expect(find.bySemanticsLabel(hint), findsOneWidget);
      }
    });
  }

  testWidgets('lifting the finger clears the readings but keeps the battery', (tester) async {
    await pump(tester);
    await send(tester, [
      const LiveStatusChanged(LiveStatus.streaming),
      const LiveContactChanged(SensorContact.ok),
      LiveValue(Sample('heart_rate', 72, _t)),
      LiveValue(Sample('spo2', 97, _t)),
      LiveValue(Sample('battery', 81, _t)),
    ]);
    expect(find.text('72 bpm'), findsOneWidget);

    await send(tester, [const LiveContactChanged(SensorContact.none)]);

    expect(find.text('72 bpm'), findsNothing);
    expect(find.text('97 %'), findsNothing);
    expect(find.text('81 %'), findsOneWidget);
    expect(find.text('Place your finger on the sensor'), findsOneWidget);
  });

  testWidgets('no hint before the device is streaming', (tester) async {
    await pump(tester);
    await send(tester, [const LiveContactChanged(SensorContact.none)]);

    expect(find.text('Place your finger on the sensor'), findsNothing);
  });

  testWidgets('the chevron at the top goes to the home page', (tester) async {
    final router = GoRouter(
      // Opened the way Add device opens it: nothing to go back to.
      initialLocation: '/device/1',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home page')),
        GoRoute(path: '/device/:id', builder: (_, _) => const LiveDeviceScreen(deviceId: 1)),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveReadingsProvider.overrideWithValue(live),
          myDevicesProvider.overrideWith((ref) => Stream.value(const [_sensor, _patch, _band])),
          deviceProfileRegistryProvider.overrideWith((ref) async => _registry),
        ],
        child: MaterialApp.router(
          theme: buildTheme(_theme, Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }

    expect(find.byTooltip('Back'), findsOneWidget); // read out by screen readers
    await tester.tap(find.byTooltip('Back'));
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }

    expect(find.text('home page'), findsOneWidget);
  });
}
