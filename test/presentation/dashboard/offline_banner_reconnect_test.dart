import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/user_device.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';
import 'package:generic_flutter_app/presentation/dashboard/live_device_screen.dart';

import '../../fixtures/dashboard_harness.dart';
import '../../fixtures/scripted_live_readings.dart';

final _now = DateTime.utc(2026, 11, 12, 9);

const _sensor = UserDevice(id: 1, name: 'Finger sensor', profileId: 'ppg_motion_v1');
const _thermometer = UserDevice(id: 4, name: 'Thermometer', profileId: 'thermometer_v1');
const _patch = UserDevice(id: 5, name: 'Patch', profileId: 'ief_device_v1');

const _bannerHeard = 'Offline · last heartbeat 5 min ago. Showing last readings.';
const _bannerNever = 'Offline · no data from the device yet. Showing last readings.';
const _failed = 'Could not reconnect. Check the device is on and nearby.';

/// The offline banner, Reconnect and the bottom buttons (task 1.3.6, TC-DSH-010 to TC-DSH-014).
void main() {
  late ScriptedLiveReadings live;

  setUp(() => live = ScriptedLiveReadings());

  Future<void> pump(
    WidgetTester tester, {
    UserDevice device = _sensor,
    Size size = const Size(390, 1400),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: dashboardOverrides(
          live: live,
          devices: const [_sensor, _thermometer, _patch],
          now: _now,
        ),
        child: dashboardApp(LiveDeviceScreen(deviceId: device.id)),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  }

  Future<void> send(WidgetTester tester, List<LiveUpdate> updates) async {
    updates.forEach(live.send);
    await tester.pump();
  }

  final heard = _now.subtract(const Duration(minutes: 5, seconds: 2));
  final offline = [
    const LiveStatusChanged(LiveStatus.streaming),
    LiveHeartbeat(online: false, lastAt: heard),
  ];

  Future<void> tapReconnect(WidgetTester tester) async {
    await tester.tap(find.text('Reconnect'));
    await tester.pump();
  }

  group('offline banner', () {
    testWidgets('TC-DSH-010: offline shows the last heartbeat; Reconnect connects and it goes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await send(tester, offline);

      expect(find.text(_bannerHeard), findsOneWidget);
      expect(find.bySemanticsLabel('Link: Offline'), findsOneWidget);

      await tapReconnect(tester);
      expect(live.retried, [_sensor.id]);
      // Trying: the banner stays, the button spins and cannot be tapped again.
      expect(find.text(_bannerHeard), findsOneWidget);
      expect(find.bySemanticsLabel('Reconnecting to the device'), findsOneWidget);
      expect(find.text('Reconnect'), findsNothing);

      await send(tester, [
        const LiveStatusChanged(LiveStatus.streaming),
        LiveHeartbeat(online: true, lastAt: _now),
      ]);
      expect(find.textContaining('Offline ·'), findsNothing);
      expect(find.bySemanticsLabel('Link: Bluetooth'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('TC-DSH-011: Reconnect fails: says so, banner stays, button usable again', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await send(tester, offline);
      await tapReconnect(tester);

      await send(tester, [
        const LiveFailure(LiveFailureReason.connectFailed),
        const LiveStatusChanged(LiveStatus.waiting),
      ]);

      expect(find.text(_failed), findsOneWidget);
      expect(find.textContaining('Offline ·'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      // Said once: the banner covers "Could not connect", so no second message or Try again.
      expect(find.textContaining('Could not connect.'), findsNothing);
      expect(find.text('Try again'), findsNothing);

      await tapReconnect(tester);
      expect(live.retried, [_sensor.id, _sensor.id]);
      expect(find.text(_failed), findsNothing); // trying again
      semantics.dispose();
    });

    testWidgets('a device that cannot be reached is Offline at once, without a spinner', (
      tester,
    ) async {
      await pump(tester);
      await send(tester, [const LiveStatusChanged(LiveStatus.waiting)]);

      expect(find.text(_bannerNever), findsOneWidget);
      expect(find.text('Device not found. Trying again…'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a dropped link reconnecting is not Offline yet: no banner', (tester) async {
      await pump(tester);
      await send(tester, [const LiveStatusChanged(LiveStatus.reconnecting)]);

      expect(find.textContaining('Offline ·'), findsNothing);
      expect(find.text('Connection lost. Reconnecting…'), findsOneWidget);
    });

    testWidgets('an on-demand device never shows the banner', (tester) async {
      await pump(tester, device: _thermometer);
      await send(tester, [LiveHeartbeat(online: false, lastAt: heard)]);

      expect(find.text('Reconnect'), findsNothing);
    });

    testWidgets('fits a small phone at double text size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, size: const Size(320, 2400));
      await send(tester, offline);
      await tapReconnect(tester);
      await send(tester, [
        const LiveFailure(LiveFailureReason.connectFailed),
        const LiveStatusChanged(LiveStatus.waiting),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text(_failed), findsOneWidget);
    });
  });

  group('bottom buttons', () {
    Future<void> show(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
    }

    testWidgets('the PPG sensor has no Sync now (nothing stored to fetch), only Identify', (
      tester,
    ) async {
      await pump(tester);
      await send(tester, [const LiveStatusChanged(LiveStatus.streaming)]);

      expect(find.text('Sync now'), findsNothing);
      expect(find.text('Identify sensor'), findsOneWidget);
    });

    testWidgets('the IEF patch: Sync now from its config requests the stored logs', (tester) async {
      await pump(tester, device: _patch);
      await send(tester, [const LiveStatusChanged(LiveStatus.streaming)]);
      await show(tester, find.text('Sync now'));

      await tester.tap(find.text('Sync now'));
      await tester.pump();
      expect(live.commands, [(_patch.id, 'request_logs')]);
      expect(find.text('Fetching the readings stored on the device.'), findsOneWidget);
    });

    testWidgets('PPG sensor: Identify flashes its red LED three times and says so', (tester) async {
      await pump(tester);
      await send(tester, [const LiveStatusChanged(LiveStatus.streaming)]);
      await show(tester, find.text('Identify sensor'));

      await tester.tap(find.text('Identify sensor'));
      await tester.pump();
      expect(live.commands, List.filled(6, (_sensor.id, 'led_red')));
      expect(find.text('The sensor light flashed.'), findsOneWidget);
    });

    testWidgets('TC-DSH-014: the action is disabled while the device is not connected', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await send(tester, offline);
      await show(tester, find.text('Identify sensor'));

      expect(
        find.bySemanticsLabel('Identify sensor, available when the device is connected'),
        findsOneWidget,
      );
      await tester.tap(find.text('Identify sensor'), warnIfMissed: false);
      await tester.pump();
      expect(live.commands, isEmpty);
      semantics.dispose();
    });
  });

  testWidgets('other problems still show while offline, but Reconnect replaces Try again', (
    tester,
  ) async {
    await pump(tester);
    await send(tester, [
      ...offline,
      const LiveFailure(LiveFailureReason.startFailed, problem: DeviceProblem.lowBattery),
    ]);

    expect(find.text('The device battery is low. Charge it, then try again.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Reconnect'), findsOneWidget);
  });
}
