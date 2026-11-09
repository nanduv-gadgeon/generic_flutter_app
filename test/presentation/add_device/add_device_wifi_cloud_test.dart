import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/transport/wifi_provisioner.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/test_config.dart';
import 'add_device_test_app.dart';

/// Add device over Wi‑Fi, and with the cloud (Phase 2).
void main() {
  setUpAll(() {
    registerFallbackValue(WifiSetupMethod.ble);
    registerFallbackValue(fakeCredentials);
    registerFallbackValue(DeviceProfile.fromJson(validProfileJson()));
  });

  setUp(() => fakes = AddDeviceFakes());
  group('Wi‑Fi', () {
    const result = ProvisionResult(deviceId: 'tst-5c1a', address: '192.168.1.20');

    testWidgets('checks the form, then sets up over the device hotspot', (tester) async {
      when(() => fakes.provisioner.provision(any(), WifiSetupMethod.softap, any()))
          .thenAnswer((_) async => result);
      await pumpAddDevice(tester);
      await toWifiForm(tester);

      expect(find.text('Connect device to Wi‑Fi'), findsOneWidget);
      await tapAndSettle(tester, find.text('Device hotspot'));
      await tapAndSettle(tester, button('Connect device'));
      expect(find.text('Enter the network name (up to 32 characters).'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'TestNet');
      await tester.enterText(find.byType(TextFormField).at(1), 'short');
      await tapAndSettle(tester, button('Connect device'));
      expect(find.text('Wi‑Fi passwords have 8–63 characters, or none.'), findsOneWidget);
      final password = tester.widget<EditableText>(
        find.descendant(of: find.byType(TextFormField).at(1), matching: find.byType(EditableText)),
      );
      expect(password.obscureText, isTrue);

      await tester.enterText(find.byType(TextFormField).at(1), fakeCredentials.password);
      await tapAndSettle(tester, button('Connect device'));
      expect(find.text("Join the device's Wi‑Fi"), findsOneWidget);
      expect(find.text('Join the network whose name starts with "TST-".'), findsOneWidget);

      await tapAndSettle(tester, button("I've joined, continue"));
      expect(find.text('Test sensor paired over Wi‑Fi and saved on this phone.'), findsOneWidget);
      expect(fakes.devices.added.single.$1.ipAddress, '192.168.1.20');
      final sent =
          verify(() => fakes.provisioner.provision(any(), WifiSetupMethod.softap, captureAny()))
                  .captured
                  .single
              as WifiCredentials;
      expect((sent.ssid, sent.password), ('TestNet', fakeCredentials.password));
    });

    testWidgets('a setup error goes back to the form with a message', (tester) async {
      when(() => fakes.provisioner.provision(any(), any(), any()))
          .thenThrow(const ProvisioningException('device not reachable – join its Wi‑Fi first'));
      await pumpAddDevice(tester);
      await toWifiForm(tester);
      await tapAndSettle(tester, find.text('Device hotspot'));
      await tester.enterText(find.byType(TextFormField).at(0), 'TestNet');
      await tapAndSettle(tester, button('Connect device'));
      await tapAndSettle(tester, button("I've joined, continue"));

      expect(find.text('Connect device to Wi‑Fi'), findsOneWidget);
      expect(
        find.text("Could not reach the device. Check your phone is on the device's Wi‑Fi."),
        findsOneWidget,
      );
    });
  });

  group('with the cloud (isCloud true)', () {
    testWidgets('lists the cloud steps and shows the key card waiting for the cloud', (
      tester,
    ) async {
      fakes.linkGate = Completer();
      await pumpAddDevice(tester, isCloud: true);
      await toScan(tester);
      fakes.scanner.results.add(fakeFound);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Connect to TST band'));
      await tester.pump();
      expect(find.text('Device key received'), findsOneWidget);

      fakes.linkGate!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('registered with the cloud.'), findsOneWidget);
      expect(find.text('Device key'), findsOneWidget);
      expect(find.text('Waiting for the cloud'), findsOneWidget);
      expect(find.text('Default settings'), findsOneWidget);
    });

    testWidgets('shows the masked key and the suggested alerts', (tester) async {
      fakes.devices.cloud = (saved) => saved.copyWith(
        deviceKey: 'DK-7F3A-9C2E-4B18-0D51',
        alerts: const [AlertRule(key: 'current', above: 30)],
        suggestedAlerts: true,
      );
      await pumpAddDevice(tester, isCloud: true);
      await toScan(tester);
      fakes.scanner.results.add(fakeFound);
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.bySemanticsLabel('Connect to TST band'));

      expect(find.text('DK-7F3A-••••-••••-0D51'), findsOneWidget);
      expect(find.text('Suggested by cloud AI'), findsOneWidget);
      expect(find.text('30 u'), findsOneWidget);
      expect(find.text('Battery below'), findsNothing);
    });
  });
}
