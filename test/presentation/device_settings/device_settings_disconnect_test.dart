import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'device_settings_test_app.dart';

/// Disconnect device on Device settings: closes the link, keeps the device; Connect undoes it.
void main() {
  Finder button(String text) => find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate((w) => w is OutlinedButton),
  );

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(button(text));
    await tester.tap(button(text));
    await tester.pumpAndSettle();
  }

  testWidgets('shows Disconnect device next to Remove device', (tester) async {
    await pumpSettings(tester, device: band);

    expect(button('Disconnect device'), findsOneWidget);
    expect(button('Remove device'), findsOneWidget);
  });

  testWidgets('disconnects, keeps the device, says so and offers Connect', (tester) async {
    await pumpSettings(tester, device: band);

    await tap(tester, 'Disconnect device');

    expect(live.off, {band.id});
    verifyNever(() => devices.removeDevice(any(), any())); // still saved
    expect(find.text('Device disconnected. Its history and alerts are kept.'), findsOneWidget);
    expect(button('Connect device'), findsOneWidget);
    expect(find.text('Device settings'), findsOneWidget);
  });

  testWidgets('Connect connects it again', (tester) async {
    await pumpSettings(tester, device: band);
    await tap(tester, 'Disconnect device');

    await tap(tester, 'Connect device');

    expect(live.off, isEmpty);
    expect(find.text('Connecting to the device.'), findsOneWidget);
    expect(button('Disconnect device'), findsOneWidget);
  });

  testWidgets('a labelled spinner while disconnecting', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSettings(tester, device: band);
    final gate = Completer<void>();
    live.disconnectGate = gate;

    await tester.ensureVisible(button('Disconnect device'));
    await tester.tap(button('Disconnect device'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Disconnecting device')), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    semantics.dispose();
  });

  testWidgets('a failed disconnect says so', (tester) async {
    await pumpSettings(tester, device: band);
    live.disconnectError = StateError('link stuck');

    await tap(tester, 'Disconnect device');

    expect(find.text("Couldn't disconnect the device. Try again."), findsOneWidget);
  });

  testWidgets('fits a small phone at twice the text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpSettings(tester, device: band, size: const Size(320, 568));

    await tester.scrollUntilVisible(
      find.text('Disconnect device'),
      200,
      scrollable: find
          .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(button('Disconnect device'), findsOneWidget);
  });
}
