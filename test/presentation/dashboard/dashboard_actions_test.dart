import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/dashboard_settings.dart';
import 'package:generic_flutter_app/domain/transport/device_link.dart';
import 'package:generic_flutter_app/presentation/dashboard/dashboard_actions.dart';

import '../../fixtures/dashboard_harness.dart';
import '../../fixtures/scripted_live_readings.dart';

const _findBand = DeviceAction(
  label: 'Find band',
  command: 'vibrate',
  done: 'The band is vibrating.',
);

/// The device action at the bottom of Live (task 1.3.6, TC-DSH-013 and TC-DSH-014).
void main() {
  late ScriptedLiveReadings live;

  setUp(() => live = ScriptedLiveReadings());

  Future<void> pump(
    WidgetTester tester, {
    DeviceAction? action = _findBand,
    bool connected = true,
    bool cloud = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: dashboardOverrides(
          live: live,
          devices: const [],
          now: DateTime.utc(2026, 11, 12, 9),
          cloud: cloud,
        ),
        child: dashboardApp(
          Scaffold(
            body: DashboardActions(deviceId: 7, action: action, connected: connected),
          ),
        ),
      ),
    );
  }

  testWidgets('TC-DSH-013: sends its command to the device and says it worked', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Find band'));
    await tester.pump();

    expect(live.commands, [(7, 'vibrate')]);
    expect(find.text('The band is vibrating.'), findsOneWidget);
  });

  testWidgets('without its own message it says the action is done', (tester) async {
    await pump(
      tester,
      action: const DeviceAction(label: 'Identify', command: 'blink'),
    );

    await tester.tap(find.text('Identify'));
    await tester.pump();

    expect(find.text('Identify: done.'), findsOneWidget);
  });

  final errors = <String, Object>{
    'refuses it': const CommandFailedForTest(),
    'is no longer connected': const LinkException('not connected'),
  };
  for (final MapEntry(key: name, value: error) in errors.entries) {
    testWidgets('TC-DSH-014: when the device $name, a clear message', (tester) async {
      live.commandError = error;
      await pump(tester);

      await tester.tap(find.text('Find band'));
      await tester.pump();

      expect(find.text("Find band didn't work. Check the device and try again."), findsOneWidget);
      // Usable again.
      await tester.tap(find.text('Find band'));
      await tester.pump();
      expect(live.commands, hasLength(2));
    });
  }

  testWidgets('TC-DSH-014: disabled while not connected; says why to screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, connected: false);

    await tester.tap(find.text('Find band'), warnIfMissed: false);
    await tester.pump();

    expect(live.commands, isEmpty);
    expect(
      find.bySemanticsLabel('Find band, available when the device is connected'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('one button takes the whole width; Sync now joins it with the cloud', (tester) async {
    await pump(tester);
    final alone = tester.getSize(find.byType(OutlinedButton)).width;

    await pump(tester, cloud: true);
    expect(find.byType(OutlinedButton), findsNWidgets(2));
    expect(tester.getSize(find.byType(OutlinedButton).first).width, lessThan(alone));
  });

  testWidgets('no action and no cloud: nothing is shown', (tester) async {
    await pump(tester, action: null);

    expect(find.byType(OutlinedButton), findsNothing);
  });
}

/// Any error from the device that is not a link problem.
class CommandFailedForTest implements Exception {
  const CommandFailedForTest();
}
