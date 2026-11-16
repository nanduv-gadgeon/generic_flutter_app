import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/history_provider.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:generic_flutter_app/presentation/history/history_screen.dart';
import 'package:generic_flutter_app/presentation/widgets/form_widgets.dart';

import '../../fixtures/history_harness.dart';

const _band = UserDevice(id: 2, name: 'Test band', profileId: 'smart_band_v1');
const _sensor = UserDevice(id: 4, name: 'Test sensor', profileId: 'env_sensor_v1');

/// History's back button: shown only when History was opened from another page (a device's
/// dashboard), and it goes back there.
void main() {
  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HistoryScreen)));

  testWidgets('opened from the bottom bar: no back button', (tester) async {
    await pumpHistory(tester, devices: const [_band]);

    expect(find.byType(CircleBackButton), findsNothing);
  });

  testWidgets('opened from a dashboard: the back button returns there', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHistory(tester, devices: const [_band], openedFrom: '/device/2');
    final container = containerOf(tester);

    expect(find.byType(CircleBackButton), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byType(CircleBackButton));
    await tester.pumpAndSettle();

    expect(find.text('page /device/2'), findsOneWidget);
    expect(container.read(historyControllerProvider).backRoute, isNull);
    semantics.dispose();
  });

  testWidgets("the phone's back returns to the dashboard too", (tester) async {
    await pumpHistory(tester, devices: const [_band], openedFrom: '/device/2');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('page /device/2'), findsOneWidget);
  });

  testWidgets('picking another device drops the way back', (tester) async {
    await pumpHistory(tester, devices: const [_band, _sensor], openedFrom: '/device/2');

    await tester.tap(find.text('Test sensor'));
    await tester.pumpAndSettle();

    expect(find.byType(CircleBackButton), findsNothing);
  });

  testWidgets('fits a small phone at twice the text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpHistory(
      tester,
      devices: const [_band],
      openedFrom: '/device/2',
      size: const Size(320, 568),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(CircleBackButton), findsOneWidget);
  });
}
