import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/fake_auth.dart';
import '../../fixtures/home_harness.dart';
import '../../fixtures/l10n.dart';

/// Reorder on My devices (mockup 09_home_reorder): drag ≡ to move a device; every drop is saved.
void main() {
  const band = UserDevice(id: 1, name: 'Test band', profileId: 'smart_band_v1');
  const patch = UserDevice(id: 2, name: 'Test patch', profileId: 'ief_device_v1');
  const sensor = UserDevice(id: 3, name: 'Test sensor', profileId: 'ppg_motion_v1');
  const devices = [band, patch, sensor];

  Future<void> startReordering(WidgetTester tester) async {
    await tester.tap(find.text(en.devicesReorder));
    await tester.pumpAndSettle();
  }

  Finder handle(String name) => find.bySemanticsLabel(en.devicesReorderHandle(name));

  List<int> savedOrder(MockDeviceService service) =>
      verify(() => service.reorder(fakeUser.id, captureAny())).captured.single as List<int>;

  for (final count in [0, 1]) {
    testWidgets('no Reorder with $count device(s)', (tester) async {
      await pumpHome(tester, devices: devices.take(count).toList());

      expect(find.text(en.devicesReorder), findsNothing);
    });
  }

  testWidgets('Reorder shows the hint, a handle per device and Done', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHome(tester, devices: devices);

    expect(find.bySemanticsLabel(en.devicesReorderLabel), findsOneWidget);
    await startReordering(tester);

    expect(find.text(en.devicesReorderHint), findsOneWidget);
    expect(find.bySemanticsLabel(en.devicesDoneLabel), findsOneWidget);
    for (final d in devices) {
      expect(handle(d.name), findsOneWidget);
    }
    semantics.dispose();
  });

  testWidgets('dragging a device saves the new order', (tester) async {
    final semantics = tester.ensureSemantics();
    final service = await pumpHome(tester, devices: devices);
    await startReordering(tester);

    final drag = await tester.startGesture(tester.getCenter(handle(band.name)));
    await tester.pump(kPressTimeout);
    for (var i = 0; i < 10; i++) {
      await drag.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();

    expect(savedOrder(service), [patch.id, sensor.id, band.id]);
    // The list shows the new order straight away.
    expect(
      tester.getTopLeft(find.text(band.name)).dy,
      greaterThan(tester.getTopLeft(find.text(sensor.name)).dy),
    );
    semantics.dispose();
  });

  testWidgets('arrow keys on a focused handle move the device', (tester) async {
    final semantics = tester.ensureSemantics();
    final service = await pumpHome(tester, devices: devices);
    await startReordering(tester);

    await tester.tap(handle(patch.name));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(savedOrder(service), [patch.id, band.id, sensor.id]);
    semantics.dispose();
  });

  testWidgets('arrow up on the first device saves nothing', (tester) async {
    final semantics = tester.ensureSemantics();
    final service = await pumpHome(tester, devices: devices);
    await startReordering(tester);

    await tester.tap(handle(band.name));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    verifyNever(() => service.reorder(any(), any()));
    semantics.dispose();
  });

  testWidgets('while reordering a tap does not open a device; Done brings the cards back', (
    tester,
  ) async {
    await pumpHome(tester, devices: devices);
    await startReordering(tester);

    await tester.tap(find.text(band.name));
    await tester.pumpAndSettle();
    expect(find.textContaining('device page'), findsNothing);

    await tester.tap(find.text(en.devicesDone));
    await tester.pumpAndSettle();
    expect(find.text(en.devicesReorderHint), findsNothing);
    expect(find.text(en.devicesReorder), findsOneWidget);
    await tester.tap(find.text(band.name));
    await tester.pumpAndSettle();
    expect(find.text('device page ${band.id}'), findsOneWidget);
  });

  testWidgets('fits a small phone at large text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpHome(tester, devices: devices, size: const Size(320, 640));
    await tester.ensureVisible(find.text(en.devicesReorder));
    await tester.pumpAndSettle();
    await startReordering(tester);

    expect(tester.takeException(), isNull);
  });
}
