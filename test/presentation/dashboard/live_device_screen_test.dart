import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/history_provider.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/domain/models/user_device.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';
import 'package:generic_flutter_app/l10n/app_localizations.dart';
import 'package:generic_flutter_app/presentation/dashboard/live_device_screen.dart';
import 'package:go_router/go_router.dart';

import '../../fixtures/dashboard_harness.dart';
import '../../fixtures/scripted_live_readings.dart';

final _now = DateTime.utc(2026, 11, 11, 9);

const _sensor = UserDevice(id: 1, name: 'Finger sensor', profileId: 'ppg_motion_v1');
const _patch = UserDevice(id: 2, name: 'Patch', profileId: 'ief_device_v1');
const _band = UserDevice(id: 3, name: 'Band', profileId: 'smart_band_v1');

/// The dashboard shell: connecting, statuses, problems, Offline and the finger hint. What each
/// profile's views show is in `dashboard_profiles_test.dart`.
void main() {
  late ScriptedLiveReadings live;
  late FakeReadingRepository readings;
  late ValueNotifier<bool> open;

  setUp(() {
    live = ScriptedLiveReadings();
    readings = FakeReadingRepository();
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
        overrides: dashboardOverrides(
          live: live,
          devices: const [_sensor, _patch, _band],
          now: _now,
          readings: readings,
        ),
        child: dashboardApp(
          ValueListenableBuilder(
            valueListenable: open,
            builder: (_, isOpen, _) =>
                isOpen ? LiveDeviceScreen(deviceId: deviceId) : const Text('closed'),
          ),
          brightness: brightness,
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

  testWidgets('connects when opened: name, type, Connecting… and no values yet', (tester) async {
    await pump(tester);

    expect(live.listens, 1);
    expect(find.text('Finger sensor'), findsOneWidget);
    expect(find.text('PPG + motion sensor'), findsOneWidget);
    expect(find.text('Connecting…'), findsOneWidget);
    expect(find.bySemanticsLabel('Heart rate, no reading yet'), findsOneWidget);
    expect(find.bySemanticsLabel('Battery: –'), findsOneWidget);
    expect(find.bySemanticsLabel('Connecting…'), findsOneWidget);
  });

  testWidgets('streaming: values with units and status words, battery in the strip', (
    tester,
  ) async {
    await pump(tester);
    await send(tester, [
      const LiveStatusChanged(LiveStatus.streaming),
      LiveValue(Sample('heart_rate', 72, _now)),
      LiveValue(Sample('spo2', 97, _now)),
      LiveValue(Sample('pi_red', 0.0981, _now)),
      LiveValue(Sample('pi_ir', 1.4369, _now)),
      LiveValue(Sample('battery', 81, _now)),
    ]);

    expect(find.text('Connecting…'), findsNothing);
    expect(find.bySemanticsLabel('SpO₂, 97 %, Normal'), findsOneWidget);
    expect(find.bySemanticsLabel('Heart rate, 72 bpm, Normal'), findsOneWidget);
    expect(find.bySemanticsLabel('PI (Red), 0.098, Normal'), findsOneWidget);
    expect(find.bySemanticsLabel('PI (IR), 1.437, High'), findsOneWidget);
    expect(find.bySemanticsLabel('Battery: 81%'), findsOneWidget);
    expect(find.text('4 values · live'), findsOneWidget);
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

  final offline = <String, (DateTime?, String)>{
    'heard from 5 min ago': (
      _now.subtract(const Duration(minutes: 5, seconds: 2)),
      'Offline · last heartbeat 5 min ago. Showing last readings.',
    ),
    'never heard from': (null, 'Offline · no data from the device yet. Showing last readings.'),
  };
  for (final MapEntry(key: name, value: (lastAt, text)) in offline.entries) {
    testWidgets('missed heartbeats, $name: Offline in words, in the strip too', (tester) async {
      await pump(tester);
      await send(tester, [
        const LiveStatusChanged(LiveStatus.streaming),
        LiveHeartbeat(online: false, lastAt: lastAt),
      ]);

      // The offline banner (task 1.3.6) says it, with Reconnect.
      expect(find.text(text), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(RegExp.escape(text))), findsOneWidget);
      expect(find.bySemanticsLabel('Reconnect to the device'), findsOneWidget);
      expect(find.bySemanticsLabel('Link: Offline'), findsOneWidget);

      await send(tester, [LiveHeartbeat(online: true, lastAt: _now)]);
      expect(find.text(text), findsNothing);
      expect(find.bySemanticsLabel('Link: Bluetooth'), findsOneWidget);
      expect(find.bySemanticsLabel('Heartbeat: 0 s ago'), findsOneWidget);
    });
  }

  testWidgets('closing the screen stops listening (the device stays connected)', (tester) async {
    await pump(tester);
    open.value = false;
    await tester.pump();

    expect(live.cancels, 1);
  });

  testWidgets('before it connects, the newest stored readings are shown', (tester) async {
    readings.latest[_band.id] = {'hr': Sample('hr', 72, _now), 'spo2': Sample('spo2', 98, _now)};
    await pump(tester, deviceId: _band.id);

    expect(find.bySemanticsLabel('Heart rate, 72 bpm, Normal'), findsOneWidget);
    expect(find.bySemanticsLabel('SpO₂, 98 %, Normal'), findsOneWidget);
    expect(find.text('7 values'), findsOneWidget);
  });

  testWidgets('the History tab opens History on this device, By day and today', (tester) async {
    final router = GoRouter(
      initialLocation: '/device/3',
      routes: [
        GoRoute(path: '/device/:id', builder: (_, _) => const LiveDeviceScreen(deviceId: 3)),
        GoRoute(
          path: '/history',
          builder: (_, _) => Consumer(
            builder: (_, ref, _) => Text('history page ${ref.watch(historyControllerProvider)}'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: dashboardOverrides(live: live, devices: const [_sensor, _band], now: _now),
        child: MaterialApp.router(
          theme: buildTheme(testTheme, Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
    final container = ProviderScope.containerOf(tester.element(find.byType(LiveDeviceScreen)));
    // An earlier visit to History left another device and the summary tab picked.
    container.read(historyControllerProvider.notifier)
      ..pickDevice(1)
      ..pickMode(HistoryMode.summary);

    await tester.tap(find.bySemanticsLabel('History'));
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }

    expect(container.read(historyControllerProvider), const HistorySelection(deviceId: 3));
    expect(find.textContaining('history page'), findsOneWidget);
  });

  final statuses = {LiveStatus.syncing: 'Getting stored readings…'};
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
        LiveValue(Sample('pi_red', 12.3456, _now)),
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

  testWidgets('lifting the finger clears the readings (No signal) but keeps the battery', (
    tester,
  ) async {
    await pump(tester);
    await send(tester, [
      const LiveStatusChanged(LiveStatus.streaming),
      const LiveContactChanged(SensorContact.ok),
      LiveValue(Sample('heart_rate', 72, _now)),
      LiveValue(Sample('battery', 81, _now)),
    ]);
    expect(find.bySemanticsLabel('Heart rate, 72 bpm, Normal'), findsOneWidget);

    await send(tester, [const LiveContactChanged(SensorContact.none)]);

    expect(find.bySemanticsLabel('Heart rate, no reading yet, No signal'), findsOneWidget);
    expect(find.bySemanticsLabel('Battery: 81%'), findsOneWidget);
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
        overrides: dashboardOverrides(live: live, devices: const [_sensor], now: _now),
        child: MaterialApp.router(
          theme: buildTheme(testTheme, Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
