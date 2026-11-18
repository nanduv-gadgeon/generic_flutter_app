import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/models/user_device.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';
import 'package:generic_flutter_app/domain/services/permission_service.dart';
import 'package:generic_flutter_app/presentation/dashboard/live_device_screen.dart';

import '../../fixtures/dashboard_harness.dart';
import '../../fixtures/fake_permissions.dart';
import '../../fixtures/scripted_live_readings.dart';

final _now = DateTime.utc(2026, 11, 12, 9);

const _sensor = UserDevice(id: 1, name: 'Finger sensor', profileId: 'ppg_motion_v1');

/// The dashboard of a device the user disconnected, and of one Bluetooth stops. Fake data only.
void main() {
  late ScriptedLiveReadings live;
  late FakePermissionService permissions;

  setUp(() {
    live = ScriptedLiveReadings();
    permissions = FakePermissionService();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...dashboardOverrides(live: live, devices: const [_sensor], now: _now),
          permissionServiceProvider.overrideWithValue(permissions),
        ],
        child: dashboardApp(const LiveDeviceScreen(deviceId: 1)),
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

  testWidgets('disconnected: says so with Connect, and is not Offline', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    await send(tester, [
      const LiveStatusChanged(LiveStatus.streaming),
      LiveHeartbeat(online: false, lastAt: _now), // was offline before the user disconnected
      const LiveStatusChanged(LiveStatus.disconnected),
    ]);

    expect(find.text('Disconnected'), findsWidgets);
    expect(find.textContaining('Offline'), findsNothing);
    expect(find.text('Reconnect'), findsNothing); // no offline banner
    expect(find.bySemanticsLabel('Connect the device again'), findsOneWidget);

    await tester.tap(find.text('Connect'));
    await tester.pump();

    expect(live.retried, [_sensor.id]);
    semantics.dispose();
  });

  // what stops Bluetooth -> message and the way out
  final problems = {
    const PermissionProblem.refused(AppPermission.bluetooth): (
      'Bluetooth permission is needed to find and connect to your devices. Allow it, then try '
          'again.',
      'Try again',
    ),
    const PermissionProblem.refused(AppPermission.bluetooth, blocked: true): (
      "Bluetooth permission is off for this app, so it can't find or connect to your devices. "
          'Turn it on in Settings.',
      'Open Settings',
    ),
    const PermissionProblem.bluetoothOff(): (
      'Bluetooth is off. Turn it on to find and connect to your devices, then try again.',
      'Try again',
    ),
  };
  for (final MapEntry(key: problem, value: (message, action)) in problems.entries) {
    testWidgets('$problem -> "$action"', (tester) async {
      await pump(tester);
      await send(tester, [
        const LiveStatusChanged(LiveStatus.connecting),
        LiveFailure(LiveFailureReason.bluetooth, permission: problem),
      ]);

      expect(find.text(message), findsOneWidget);
      await tester.tap(find.text(action));
      await tester.pump();

      if (problem.blocked) {
        expect(permissions.settingsOpened, 1);
      } else {
        expect(live.retried, [_sensor.id]);
      }
    });
  }
}
