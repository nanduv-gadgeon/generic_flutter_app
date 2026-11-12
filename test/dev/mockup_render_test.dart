import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/l10n/app_localizations.dart';
import 'package:generic_flutter_app/presentation/dashboard/live_device_screen.dart';

import '../fixtures/dashboard_harness.dart';
import '../fixtures/mockup_dashboards.dart';
import '../fixtures/scripted_live_readings.dart';

/// Dev only: draws each mockup dashboard at 2× with the real fonts, to compare with
/// `docs/screens/13…21`. Runs only when MOCKUP_DIR is set; the PNGs go there and are not
/// committed:
///
///     MOCKUP_DIR=/tmp/out flutter test test/dev/mockup_render_test.dart
final _shot = GlobalKey();

void main() {
  final out = Platform.environment['MOCKUP_DIR'];

  const theme = ThemeConfig(
    primary: '#0F766E',
    accent: '#2DD4BF',
    font: 'Nunito',
    cornerRadius: 22,
    cornerRadiusSmall: 16,
    mode: ThemeModeSetting.light,
  );

  setUpAll(() async {
    if (out == null) return;
    final nunito = FontLoader('Nunito');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      nunito.addFont(rootBundle.load('assets/fonts/Nunito/Nunito-$weight.ttf'));
    }
    await nunito.load();
    final icons = File(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons)))).load();
  });

  for (final MapEntry(key: id, value: mockup) in mockupDashboards.entries) {
    testWidgets('renders $id', skip: out == null, (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(theme, Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RepaintBoundary(
              key: _shot,
              child: LiveDeviceScreen(deviceId: mockup.device.id),
            ),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
      mockup.updates().forEach(live.send);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Size the phone to the whole page, so one picture shows all of it.
      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      tester.view.physicalSize = Size(390, position.maxScrollExtent + position.viewportDimension);
      await tester.pump(const Duration(milliseconds: 50));
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$id.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    });
  }
}
