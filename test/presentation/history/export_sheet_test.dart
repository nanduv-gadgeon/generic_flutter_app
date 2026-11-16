import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:generic_flutter_app/domain/services/export_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/export_fixtures.dart';
import '../../fixtures/history_harness.dart';

class _MockExportService extends Mock implements ExportService {}

const _band = UserDevice(id: 2, name: 'Test band', profileId: 'smart_band_v1');

/// History's Export button and sheet (requirement 6.6, mockup 33). Local mode only.
void main() {
  setUpAll(() => registerFallbackValue(exportRequest()));

  late _MockExportService service;
  setUp(() => service = _MockExportService());

  Future<void> pump(WidgetTester tester, {bool available = true, Size? size}) => pumpHistory(
    tester,
    devices: const [_band],
    size: size ?? const Size(390, 844),
    overrides: [
      exportAvailableProvider.overrideWithValue(available),
      exportServiceProvider.overrideWithValue(service),
    ],
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
  }

  ExportRequest sent() =>
      verify(() => service.exportAndShare(captureAny())).captured.single as ExportRequest;

  testWidgets('with the cloud on there is no Export button', (tester) async {
    await pump(tester, available: false);

    expect(find.text('Export'), findsNothing);
    expect(find.byIcon(Icons.download), findsNothing);
  });

  testWidgets('the sheet of screen 33, CSV picked first', (tester) async {
    await pump(tester);
    await openSheet(tester);

    expect(find.text('Export history'), findsOneWidget);
    expect(
      find.text(
        'Test band · last 7 days (20–26 Oct). All readings, with days that have missing data '
        'marked.',
      ),
      findsOneWidget,
    );
    for (final text in [
      'CSV file',
      'For Excel or other tools',
      'PDF report',
      'Charts and daily summary, easy to share',
      'Export and share',
      'Cancel',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('Export and share sends a CSV of the picked device, then closes', (tester) async {
    when(() => service.exportAndShare(any())).thenAnswer((_) async {});
    await pump(tester);
    await openSheet(tester);

    await tester.tap(find.text('Export and share'));
    await tester.pumpAndSettle();

    final request = sent();
    expect(request.format, ExportFormat.csv);
    expect((request.deviceId, request.deviceName), (2, 'Test band'));
    expect(request.days, hasLength(7));
    expect(request.readings.map((r) => r.key), contains('bp_dia'));
    expect(request.charted.map((r) => r.key), isNot(contains('bp_dia')));
    expect(request.text.csvDayStatus, 'Day status');
    expect(request.text.units['steps'], 'steps');
    expect(request.text.units['sleep'], 'h');
    expect(find.text('Export history'), findsNothing);
  });

  testWidgets('PDF can be picked', (tester) async {
    when(() => service.exportAndShare(any())).thenAnswer((_) async {});
    await pump(tester);
    await openSheet(tester);

    await tester.tap(find.text('PDF report'));
    await tester.pump();
    await tester.tap(find.text('Export and share'));
    await tester.pumpAndSettle();

    expect(sent().format, ExportFormat.pdf);
  });

  testWidgets('a labelled spinner while the file is made; the sheet stays', (tester) async {
    final semantics = tester.ensureSemantics();
    final done = Completer<void>();
    when(() => service.exportAndShare(any())).thenAnswer((_) => done.future);
    await pump(tester);
    await openSheet(tester);

    await tester.tap(find.text('Export and share'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Making the file'), findsOneWidget);
    done.complete();
    await tester.pumpAndSettle();
    expect(find.text('Export history'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a failure says so and keeps the sheet open', (tester) async {
    when(() => service.exportAndShare(any())).thenThrow(StateError('disk full'));
    await pump(tester);
    await openSheet(tester);

    await tester.tap(find.text('Export and share'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't export the file. Try again."), findsOneWidget);
    expect(find.text('Export history'), findsOneWidget);
  });

  testWidgets('Cancel closes the sheet without exporting', (tester) async {
    await pump(tester);
    await openSheet(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Export history'), findsNothing);
    verifyNever(() => service.exportAndShare(any()));
  });

  testWidgets('fits a small phone at twice the text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, size: const Size(320, 568));

    // Only the icon with large text; its name is the tooltip.
    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Export history'), findsOneWidget);
  });
}
