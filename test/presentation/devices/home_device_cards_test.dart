import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';

import '../../fixtures/home_harness.dart';

/// One card per added device on My devices (mockup 06_home).
void main() {
  group('device cards', () {
    final now = DateTime.utc(2026, 11, 10, 9);
    const patch = UserDevice(
      id: 1,
      name: 'Test patch',
      profileId: 'ief_device_v1',
      batteryPercent: 64,
    );
    final sensor = UserDevice(
      id: 2,
      name: 'Test sensor',
      profileId: 'ppg_motion_v1',
      batteryPercent: 81,
      lastHeartbeatAt: now.subtract(const Duration(seconds: 12)),
    );
    final second = sensor.copyWith(id: 3, name: 'Test sensor 2', lastHeartbeatAt: null);
    final devices = [patch, sensor, second];
    final latest = {
      2: {
        'spo2': Sample('spo2', 97, now),
        'heart_rate': Sample('heart_rate', 72, now),
        'pi_red': Sample('pi_red', 1.2, now),
      },
    };

    Future<void> pump(WidgetTester tester, {ActiveLink? active, Size? size}) => pumpHome(
      tester,
      devices: devices,
      now: now,
      latest: latest,
      active: active,
      size: size ?? const Size(390, 1400),
    );

    testWidgets('one card per added device, then Add a device', (tester) async {
      await pump(tester);

      for (final d in devices) {
        expect(find.text(d.name), findsOneWidget);
      }
      expect(find.text('Add a device'), findsOneWidget);
      expect(find.text('No devices yet'), findsNothing);
    });

    testWidgets('shows the newest stored readings, or none yet', (tester) async {
      await pump(tester);

      expect(find.text('Heart rate 72 bpm · Blood oxygen 97 %'), findsOneWidget);
      expect(find.text('No readings yet'), findsNWidgets(2));
    });

    testWidgets('battery and when it was last seen', (tester) async {
      await pump(tester);

      expect(find.text('81%'), findsNWidgets(2));
      expect(find.text('Seen 12 s ago'), findsOneWidget);
      expect(find.text('Not seen yet'), findsNWidgets(2));
    });

    final links = <String, (ActiveLink?, String, int)>{
      'nothing connected': (null, 'Not connected', 0),
      'the sensor connected': (
        (deviceId: 2, status: LiveStatus.streaming),
        'Bluetooth · Connected',
        1,
      ),
      'the patch connecting': (
        (deviceId: 1, status: LiveStatus.connecting),
        'Bluetooth · Connecting…',
        1,
      ),
      'the sensor out of reach': ((deviceId: 2, status: LiveStatus.waiting), 'Not connected', 0),
    };
    for (final MapEntry(key: name, value: (active, text, count)) in links.entries) {
      testWidgets('with $name, says "$text" and counts $count connected', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, active: active);

        expect(find.text(text), findsAtLeastNWidgets(1));
        expect(find.text('Not connected'), findsNWidgets(count == 1 ? 2 : 3));
        expect(find.bySemanticsLabel('$count Connected'), findsOneWidget);
        semantics.dispose();
      });
    }

    testWidgets('tapping a card opens that device', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Test sensor 2'));
      await tester.pumpAndSettle();

      expect(find.text('device page 3'), findsOneWidget);
    });

    testWidgets('Add a device opens Add device', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Add a device'));
      await tester.pumpAndSettle();

      expect(find.text('add device page'), findsOneWidget);
    });

    testWidgets('each card is one phrase for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, active: (deviceId: 2, status: LiveStatus.streaming));

      expect(
        find.bySemanticsLabel(
          'Test sensor, Heart rate 72 bpm · Blood oxygen 97 %, Bluetooth · Connected, Battery 81%, '
          'Seen 12 s ago. Opens the device',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    for (final brightness in Brightness.values) {
      testWidgets('cards fit a small phone with double text size (${brightness.name})', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpHome(
          tester,
          devices: devices,
          now: now,
          latest: latest,
          active: (deviceId: 2, status: LiveStatus.streaming),
          brightness: brightness,
          size: const Size(320, 568),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
