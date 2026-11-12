import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/fake_auth.dart';
import '../../fixtures/home_harness.dart';
import '../../fixtures/l10n.dart';

/// Swipe left on a device card to delete it (mockup 07_home_swipe), confirmed in the
/// "Remove {name}?" sheet.
void main() {
  const band = UserDevice(id: 1, name: 'Test band', profileId: 'smart_band_v1');
  const patch = UserDevice(id: 2, name: 'Test patch', profileId: 'ief_device_v1');
  const devices = [band, patch];

  Future<void> swipeLeft(WidgetTester tester, String name) async {
    await tester.ensureVisible(find.text(name));
    await tester.pumpAndSettle();
    await tester.drag(find.text(name), const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('no swipe hint without devices', (tester) async {
    await pumpHome(tester);

    expect(find.text(en.removeDeviceSwipeHint), findsNothing);
  });

  testWidgets('the swipe hint shows with devices', (tester) async {
    await pumpHome(tester, devices: devices);

    expect(find.text(en.removeDeviceSwipeHint), findsOneWidget);
  });

  testWidgets('swiping asks to confirm, naming the device', (tester) async {
    await pumpHome(tester, devices: devices);

    await swipeLeft(tester, band.name);

    expect(find.text(en.removeDeviceRemoveTitle(band.name)), findsOneWidget);
    expect(find.text(en.removeDeviceRemoveBody), findsOneWidget);
  });

  testWidgets('Cancel keeps the device and removes nothing', (tester) async {
    final service = await pumpHome(tester, devices: devices);
    await swipeLeft(tester, band.name);

    await tester.tap(find.text(en.commonCancel));
    await tester.pumpAndSettle();

    expect(find.text(band.name), findsOneWidget);
    verifyNever(() => service.removeById(any(), any()));
  });

  testWidgets('confirming removes the device and its card', (tester) async {
    final service = await pumpHome(tester, devices: devices);
    await swipeLeft(tester, band.name);

    await tester.tap(find.text(en.removeDeviceRemove));
    await tester.pumpAndSettle();

    verify(() => service.removeById(fakeUser.id, band.id)).called(1);
    expect(find.text(band.name), findsNothing);
    expect(find.text(patch.name), findsOneWidget);
    expect(find.text(en.removeDeviceRemoved), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed removal keeps the card and says so', (tester) async {
    final service = await pumpHome(tester, devices: devices);
    when(() => service.removeById(any(), any())).thenThrow(StateError('remove failed'));
    await swipeLeft(tester, band.name);

    await tester.tap(find.text(en.removeDeviceRemove));
    await tester.pumpAndSettle();

    expect(find.text(band.name), findsOneWidget);
    expect(find.text(en.removeDeviceRemoveFailed), findsOneWidget);
  });

  testWidgets('swiping right does nothing', (tester) async {
    await pumpHome(tester, devices: devices);

    await tester.drag(find.text(band.name), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text(en.removeDeviceRemoveTitle(band.name)), findsNothing);
  });

  testWidgets('screen readers get a Delete action on each card', (tester) async {
    final semantics = tester.ensureSemantics();
    final service = await pumpHome(tester, devices: devices);

    final card = find.semantics.byLabel(RegExp('^${band.name},'));
    final action = card.evaluate().single.getSemanticsData().customSemanticsActionIds!.single;
    tester.semantics.performAction(card, SemanticsAction.customAction, args: action);
    await tester.pumpAndSettle();
    expect(find.text(en.removeDeviceRemoveTitle(band.name)), findsOneWidget);

    await tester.tap(find.text(en.removeDeviceRemove));
    await tester.pumpAndSettle();

    verify(() => service.removeById(fakeUser.id, band.id)).called(1);
    expect(find.text(band.name), findsNothing);
    semantics.dispose();
  });

  testWidgets('the sheet fits a small phone at large text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpHome(tester, devices: devices, size: const Size(320, 640));

    await swipeLeft(tester, band.name);

    expect(find.text(en.removeDeviceRemoveTitle(band.name)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('while reordering, rows cannot be swiped and the reorder hint shows', (tester) async {
    await pumpHome(tester, devices: devices);
    await tester.tap(find.text(en.devicesReorder));
    await tester.pumpAndSettle();

    expect(find.text(en.devicesReorderHint), findsOneWidget);
    expect(find.text(en.removeDeviceSwipeHint), findsNothing);
    await tester.drag(find.text(band.name), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text(en.removeDeviceRemoveTitle(band.name)), findsNothing);
  });
}
