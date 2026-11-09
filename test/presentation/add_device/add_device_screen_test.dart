import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/models/new_device.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/test_config.dart';
import 'add_device_test_app.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(WifiSetupMethod.ble);
    registerFallbackValue(fakeCredentials);
    registerFallbackValue(DeviceProfile.fromJson(validProfileJson()));
  });

  setUp(() => fakes = AddDeviceFakes());

  testWidgets('step 1 lists the config types; one without a protocol is "Coming soon"', (
    tester,
  ) async {
    await pumpAddDevice(tester);

    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('What are you adding?'), findsOneWidget);
    expect(find.text('Test device'), findsOneWidget);
    expect(find.text('Wi‑Fi · BLE'), findsOneWidget);
    expect(find.textContaining('Coming soon'), findsOneWidget);
    expect(isEnabled(tester, 'Continue'), isFalse);

    await tapAndSettle(tester, find.text('Test kit'));
    expect(isEnabled(tester, 'Continue'), isFalse);

    await tapAndSettle(tester, find.text('Test device'));
    expect(isEnabled(tester, 'Continue'), isTrue);
    // The choice is announced, not shown only by the border colour.
    expect(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.selected == true),
      findsOneWidget,
    );
  });

  testWidgets('step 2 picks the only way a type connects and says Wi‑Fi is not supported', (
    tester,
  ) async {
    await pumpAddDevice(tester);
    await tapAndSettle(tester, find.text('Test device'));
    await tapAndSettle(tester, button('Continue'));

    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.text('How does it connect?'), findsOneWidget);
    expect(find.text('Not supported by this device'), findsOneWidget);
    expect(isEnabled(tester, 'Continue'), isTrue);
  });

  testWidgets('Bluetooth: scan, connect, then name the device and go to its dashboard', (
    tester,
  ) async {
    await pumpAddDevice(tester);
    await toScan(tester);
    expect(find.text('Searching nearby…'), findsOneWidget);

    fakes.scanner.results.add(fakeFound);
    await tester.pumpAndSettle();
    expect(find.text('FOUND 2 DEVICES'), findsOneWidget);
    expect(find.text('TST band'), findsOneWidget);
    expect(find.text('Unknown device'), findsOneWidget);
    expect(find.text('…:7B:21 · -52 dBm'), findsOneWidget);

    await tapAndSettle(tester, find.bySemanticsLabel('Connect to TST band'));

    expect(find.text('Step 4 of 4'), findsOneWidget);
    expect(find.text('Device registered'), findsOneWidget);
    expect(find.text('Test device paired over Bluetooth and saved on this phone.'), findsOneWidget);
    expect(find.text('Device key'), findsNothing); // Phase 1
    expect(find.text('Default settings'), findsOneWidget);
    expect(find.text('Current above'), findsOneWidget);
    expect(find.text('25 u'), findsOneWidget);
    expect(find.text('Battery below'), findsOneWidget);
    expect(find.text('15 %'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Test device 7B21'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Bedroom');
    await tapAndSettle(tester, button('Go to dashboard'));

    expect(find.text('dashboard 1'), findsOneWidget);
    expect(find.text('Device added'), findsOneWidget);
    expect(fakes.devices.renamed, [(1, 'Bedroom')]);
  });

  testWidgets('a device already added shows Disconnect, which asks, then removes it', (
    tester,
  ) async {
    await fakes.devices.addDevice(
      NewDevice(
        userId: 1,
        profileId: 'test_device_v1',
        transport: Transport.ble,
        address: fakeFound.first.id,
        name: 'Old',
      ),
      const [],
    );
    await pumpAddDevice(tester);
    await toScan(tester);

    fakes.scanner.results.add(fakeFound);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Disconnect TST band'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget); // the other device

    await tapAndSettle(tester, find.bySemanticsLabel('Disconnect TST band'));
    expect(find.text('Remove TST band?'), findsOneWidget);
    await tapAndSettle(tester, find.text('Cancel'));
    expect(await fakes.devices.isAdded(1, fakeFound.first.id), isTrue);
    expect(find.text('Disconnect'), findsOneWidget);

    await tapAndSettle(tester, find.bySemanticsLabel('Disconnect TST band'));
    await tapAndSettle(tester, find.text('Remove'));
    expect(await fakes.devices.isAdded(1, fakeFound.first.id), isFalse);
    expect(find.text('Disconnect'), findsNothing);
    expect(find.bySemanticsLabel('Connect to TST band'), findsOneWidget);
  });

  testWidgets('a failed connect shows an error with Try again on the scan', (tester) async {
    fakes.linkFails = true;
    await pumpAddDevice(tester);
    await toScan(tester);
    fakes.scanner.results.add(fakeFound);
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.bySemanticsLabel('Connect to TST band'));

    expect(find.text('Step 3 of 4'), findsOneWidget);
    expect(find.text('Could not connect. Keep the device close and try again.'), findsOneWidget);
    await tapAndSettle(tester, find.text('Try again'));
    expect(fakes.scanner.scans, 2);
  });

  testWidgets('the registering checklist says each stage in words', (tester) async {
    fakes.linkGate = Completer();
    await pumpAddDevice(tester);
    await toScan(tester);
    fakes.scanner.results.add(fakeFound);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Connect to TST band'));
    await tester.pump();

    expect(find.text('Registering your device'), findsOneWidget);
    expect(find.bySemanticsLabel('Connected to device, in progress'), findsOneWidget);
    expect(find.bySemanticsLabel('Saved on this phone, waiting'), findsOneWidget);

    fakes.linkGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Device registered'), findsOneWidget);
  });

  testWidgets('back goes a step back, and leaves the flow from step 1', (tester) async {
    await pumpAddDevice(tester);
    await toScan(tester);

    await tapAndSettle(tester, find.byTooltip('Back'));
    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(fakes.scanner.stopped, isTrue);
    await tapAndSettle(tester, find.byTooltip('Back'));
    expect(find.text('Step 1 of 4'), findsOneWidget);
    await tapAndSettle(tester, find.byTooltip('Back'));
    expect(find.text('home page'), findsOneWidget);
  });

  testWidgets('the system back gesture also goes a step back', (tester) async {
    await pumpAddDevice(tester);
    await tapAndSettle(tester, find.text('Test device'));
    await tapAndSettle(tester, button('Continue'));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 4'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits a small phone with double text size (${brightness.name})', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpAddDevice(tester, brightness: brightness, size: const Size(320, 568));
      expect(tester.takeException(), isNull, reason: 'step 1');
      await tapAndSettle(tester, find.text('Test device'));
      await tapAndSettle(tester, button('Continue'));
      expect(tester.takeException(), isNull, reason: 'step 2');
      await tapAndSettle(tester, button('Continue'));
      fakes.scanner.results.add(fakeFound);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'scan');
      await tapAndSettle(tester, find.bySemanticsLabel('Connect to TST band'));

      expect(find.text('Device registered'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
