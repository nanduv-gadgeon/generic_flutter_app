import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/dashboard/live_device_screen.dart';
import 'package:generic_flutter_app/presentation/dashboard/status_strip.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/parts/arc_gauge.dart';

import '../../fixtures/dashboard_harness.dart';
import '../../fixtures/mockup_dashboards.dart';
import '../../fixtures/scripted_live_readings.dart';
import '../../fixtures/text_fit_checks.dart';

/// Every VitaCare dashboard on a small phone with double text size: nothing is cut off and no
/// word is broken across lines (regression: "BATTE / RY", "2 h a…", "Demo Wi-…").
void main() {
  setUpAll(loadRealFont);

  /// [id]'s mockup dashboard on a 320 px phone at double text size.
  Future<void> pumpLarge(WidgetTester tester, String id) async {
    final mockup = mockupDashboards[id]!;
    tester.view
      ..physicalSize = const Size(320, 6000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final live = ScriptedLiveReadings();
    await tester.pumpWidget(
      ProviderScope(
        overrides: dashboardOverrides(
          live: live,
          devices: [mockup.device],
          now: mockupNow,
          readings: mockup.readings(),
          events: mockup.eventStore(),
        ),
        child: dashboardApp(LiveDeviceScreen(deviceId: mockup.device.id)),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
    mockup.updates().forEach(live.send);
    await tester.pump(const Duration(milliseconds: 50));
  }

  for (final id in mockupDashboards.keys) {
    testWidgets('$id: no text cut off or broken at 2× text on a 320 px phone', (tester) async {
      await pumpLarge(tester, id);

      expect(cutOrBrokenTexts(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the arc grows with the text, so its number stays inside the ring', (tester) async {
    await pumpLarge(tester, 'env_sensor_v1');

    final arc = tester.getRect(find.byType(ArcGauge));
    expect(arc.width, greaterThan(132 * 1.9));
    final number = tester.getRect(find.text('24.3'));
    // The number's corners stay inside the ring's inner edge (the stroke is under 10% of it).
    for (final corner in [number.topLeft, number.topRight, number.bottomLeft, number.bottomRight]) {
      expect((corner - arc.center).distance, lessThan(arc.width / 2 * 0.9), reason: '$corner');
    }
  });

  testWidgets('a stacked strip row has its label on the left and its value on the right', (
    tester,
  ) async {
    await pumpLarge(tester, 'env_sensor_v1');

    final strip = tester.getRect(find.byType(StatusStrip));
    final label = tester.getRect(find.text('BATTERY'));
    final value = tester.getRect(find.text('42%'));
    expect(label.left - strip.left, lessThan(40));
    expect(strip.right - value.right, lessThan(20));
  });
}
