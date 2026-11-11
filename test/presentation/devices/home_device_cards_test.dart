import 'package:flutter/material.dart';
import 'package:generic_flutter_app/core/theme/app_tokens.dart';
import 'package:generic_flutter_app/presentation/devices/home_device_card.dart';
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

      expect(find.text('SpO₂ 97 % · HR 72 bpm'), findsOneWidget);
      expect(find.text('No readings yet'), findsNWidgets(2));
    });

    testWidgets('battery and when it was last seen', (tester) async {
      await pump(tester);

      expect(find.text('81%'), findsNWidgets(2));
      expect(find.text('Seen 12 s ago'), findsOneWidget);
      expect(find.text('Not seen yet'), findsNWidgets(2));
    });

    final links = <String, (ActiveLink?, String, int)>{
      'nothing connected': (null, 'Offline', 0),
      'the sensor connected': ((deviceId: 2, status: LiveStatus.streaming), 'BLE · Connected', 1),
      'the patch connecting': (
        (deviceId: 1, status: LiveStatus.connecting),
        'BLE · Connecting…',
        1,
      ),
      'the sensor out of reach': ((deviceId: 2, status: LiveStatus.waiting), 'Offline', 0),
    };
    for (final MapEntry(key: name, value: (active, text, count)) in links.entries) {
      testWidgets('with $name, says "$text" and counts $count connected', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, active: active);

        expect(find.text(text), findsAtLeastNWidgets(1));
        expect(find.text('Offline'), findsNWidgets(count == 1 ? 2 : 3));
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
          'Test sensor, SpO₂ 97 % · HR 72 bpm, BLE · Connected, Battery 81%, '
          'Seen 12 s ago. Opens the device',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    /// The link chip, battery chip and Seen text of the sensor's card share one line.
    void expectStatusOnOneLine(WidgetTester tester, String link, String battery, String seen) {
      final card = find.ancestor(of: find.text(sensor.name), matching: find.byType(HomeDeviceCard));
      Finder inCard(String text) => find.descendant(of: card, matching: find.text(text));
      final y = tester.getCenter(inCard(link)).dy;
      expect(tester.getCenter(inCard(battery)).dy, moreOrLessEquals(y, epsilon: 1));
      expect(tester.getCenter(inCard(seen)).dy, moreOrLessEquals(y, epsilon: 1));
    }

    testWidgets('link, battery and Seen are on one line', (tester) async {
      await pump(tester, active: (deviceId: 2, status: LiveStatus.streaming));

      expectStatusOnOneLine(tester, 'BLE · Connected', '81%', 'Seen 12 s ago');
    });

    testWidgets('they stay on one line on a small phone with double text size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        active: (deviceId: 2, status: LiveStatus.streaming),
        size: const Size(320, 1400),
      );

      expect(tester.takeException(), isNull);
      expectStatusOnOneLine(tester, 'BLE · Connected', '81%', 'Seen 12 s ago');
    });

    testWidgets('a device that is not connected says Offline in red', (tester) async {
      await pump(tester);

      final offline = find.text('Offline').first;
      final danger = Theme.of(tester.element(offline)).extension<AppTokens>()!.danger;
      expect(tester.widget<Text>(offline).style?.color, danger);
    });

    testWidgets('without quickReadings the first readings show, with short labels', (tester) async {
      await pumpHome(
        tester,
        devices: const [UserDevice(id: 5, name: 'Test band', profileId: 'smart_band_v1')],
        now: now,
        latest: {
          5: {'hr': Sample('hr', 72, now), 'spo2': Sample('spo2', 98, now)},
        },
      );

      expect(find.text('HR 72 bpm · SpO₂ 98 %'), findsOneWidget);
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
