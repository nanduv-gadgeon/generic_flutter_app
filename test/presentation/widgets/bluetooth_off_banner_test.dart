import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/widgets/bluetooth_off_banner.dart';

import '../../fixtures/bluetooth_fakes.dart';
import '../../fixtures/dashboard_harness.dart';

/// The "Bluetooth is off" banner on home and a Bluetooth device's page (follows TC-1.2-044).
void main() {
  Future<void> pump(
    WidgetTester tester, {
    String? deviceName,
    bool canTurnOn = true,
    Future<bool> Function()? turnOn,
    Brightness brightness = Brightness.light,
    double textScale = 1,
    double width = 390,
  }) async {
    tester.view
      ..physicalSize = Size(width, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: bluetoothOverrides(off: true, canTurnOn: canTurnOn, turnOn: turnOn),
        child: dashboardApp(
          MediaQuery(
            data: MediaQueryData(size: Size(width, 600), textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: BluetoothOffBanner(deviceName: deviceName),
              ),
            ),
          ),
          brightness: brightness,
        ),
      ),
    );
  }

  final texts = <String, (String?, bool, String)>{
    'home, Android': (null, true, 'Turn it on to reconnect your devices.'),
    'home, iOS': (
      null,
      false,
      'Turn it on in Control Center or Settings to reconnect your devices.',
    ),
    'device page, Android': ('Test band', true, 'Turn it on to reconnect Test band.'),
    'device page, iOS': (
      'Test band',
      false,
      'Turn it on in Control Center or Settings to reconnect Test band.',
    ),
  };
  for (final MapEntry(key: where, value: (name, android, hint)) in texts.entries) {
    testWidgets('$where says why and ${android ? 'offers' : 'does not offer'} Turn on', (
      tester,
    ) async {
      await pump(tester, deviceName: name, canTurnOn: android);

      expect(find.text('Bluetooth is off'), findsOneWidget);
      expect(find.text(hint), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth_disabled_rounded), findsOneWidget); // not colour alone
      expect(find.text('Turn on'), android ? findsOneWidget : findsNothing);
    });
  }

  testWidgets('Turn on asks the phone, and has a spoken label', (tester) async {
    final semantics = tester.ensureSemantics();
    var asked = 0;
    await pump(tester, turnOn: () async => ++asked > 0);

    expect(find.bySemanticsLabel('Turn on Bluetooth'), findsOneWidget);
    await tester.tap(find.text('Turn on'));
    await tester.pump();

    expect(asked, 1);
    semantics.dispose();
  });

  testWidgets('screen readers hear it when it appears', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);

    final node = tester.getSemantics(find.bySemanticsLabel(RegExp('Bluetooth is off')));
    expect(node.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits a small phone with double text size (${brightness.name})', (tester) async {
      await pump(tester, deviceName: 'Test band', brightness: brightness, textScale: 2, width: 320);

      expect(tester.takeException(), isNull);
      expect(find.text('Turn on'), findsOneWidget);
    });
  }
}
