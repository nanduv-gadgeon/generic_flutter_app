import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/add_device/scan_pulse.dart';

import 'add_device_test_app.dart';

void main() {
  Future<void> pumpPulse(WidgetTester tester, {required bool active}) => tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: ScanPulse(
          active: active,
          color: Colors.teal,
          child: const SizedBox.square(dimension: 120),
        ),
      ),
    ),
  );

  testWidgets('pulses while active and stops when not', (tester) async {
    await pumpPulse(tester, active: true);
    await tester.pump(ScanPulse.period ~/ 2);
    expect(tester.hasRunningAnimations, isTrue);

    await pumpPulse(tester, active: false);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('stays still when the phone asks for reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await pumpPulse(tester, active: true);
    await tester.pump(ScanPulse.period);
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('on the scan step', () {
    setUp(() => fakes = AddDeviceFakes());

    testWidgets('pulses while searching and stops on an error', (tester) async {
      await pumpAddDevice(tester, reduceMotion: false);
      await tapAndSettle(tester, find.text('Test device'));
      await tapAndSettle(tester, button('Continue'));
      await tester.tap(button('Continue'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // page transition done

      expect(find.text('Searching nearby…'), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);

      fakes.scanner.results.addError(Exception('scan'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
