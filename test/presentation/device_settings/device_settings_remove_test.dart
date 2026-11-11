import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/fake_auth.dart';
import 'device_settings_test_app.dart';

/// Remove device from Device settings (mockup screen 26).
void main() {
  // OutlinedButton.icon is a private subclass, so match by type check rather than exact type.
  final removeButton = find.ancestor(
    of: find.text('Remove device'),
    matching: find.byWidgetPredicate((w) => w is OutlinedButton),
  );
  final confirmButton = find.widgetWithText(FilledButton, 'Remove device');

  Future<void> openSheet(WidgetTester tester) async {
    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
  }

  testWidgets('asks first, with the history length from the config', (tester) async {
    await pumpSettings(tester, device: band, historyDays: 3);

    await openSheet(tester);

    expect(find.text('Remove Test band?'), findsOneWidget);
    expect(
      find.text(
        'The device will be unpaired and its 3-day history deleted from this phone. '
        'You can add it again later.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('Cancel keeps the device', (tester) async {
    await pumpSettings(tester, device: band);
    await openSheet(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => devices.removeDevice(any(), any()));
    expect(find.text('Remove Test band?'), findsNothing);
    expect(find.text('Device settings'), findsOneWidget);
  });

  testWidgets('confirming removes it, goes home and says so', (tester) async {
    await pumpSettings(tester, device: band);
    await openSheet(tester);

    await tester.tap(confirmButton);
    await tester.pump();
    // The device disappearing is not shown as "not found" on the way out.
    expect(find.text('This device is no longer on this phone.'), findsNothing);
    await tester.pumpAndSettle();

    verify(() => devices.removeDevice(fakeUser.id, 'AA:BB:CC:00:00:01')).called(1);
    expect(find.text('home page'), findsOneWidget);
    expect(find.text('Device removed'), findsOneWidget);
  });

  testWidgets('a failed removal stays on the screen and says so', (tester) async {
    await pumpSettings(tester, device: band);
    when(() => devices.removeDevice(any(), any())).thenThrow(StateError('remove failed'));
    await openSheet(tester);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(find.text('Could not remove the device. Try again.'), findsOneWidget);
    expect(find.text('Device settings'), findsOneWidget);
    expect(find.text('home page'), findsNothing);
  });
}
