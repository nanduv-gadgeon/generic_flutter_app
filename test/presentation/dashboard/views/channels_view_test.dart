import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/channels_view.dart';

import '../../../fixtures/dashboard_harness.dart';
import '../../../fixtures/l10n.dart';

/// The PPG sensor's view, as its config sets it (mockup screen 19).
const _view = ChannelsView(
  title: 'Enabled channels',
  text: 'The channels the sensor streams.',
  count: 7,
  enabled: {1, 5},
);

void main() {
  testWidgets('title, how many are on, the text and every channel', (tester) async {
    await pumpView(tester, _view);

    expect(find.text('Enabled channels'), findsOneWidget);
    expect(find.text('2 of 7 on'), findsOneWidget);
    expect(find.text('The channels the sensor streams.'), findsOneWidget);
    for (var n = 1; n <= 7; n++) {
      expect(find.text(en.dashboardChannel(n)), findsOneWidget);
    }
  });

  testWidgets('only the enabled channels are ticked', (tester) async {
    await pumpView(tester, _view);

    expect(find.byIcon(Icons.check), findsNWidgets(2));
    for (final n in [1, 5]) {
      expect(
        find.descendant(of: _option(n), matching: find.byIcon(Icons.check)),
        findsOneWidget,
        reason: 'Channel $n',
      );
    }
    expect(find.descendant(of: _option(2), matching: find.byIcon(Icons.check)), findsNothing);
  });

  testWidgets('read-only: nothing can be tapped, and a tap changes nothing', (tester) async {
    await pumpView(tester, _view);

    expect(
      find.descendant(
        of: find.byType(ChannelsView),
        matching: find.byWidgetPredicate(
          (w) => w is InkWell || w is GestureDetector || w is Checkbox || w is ButtonStyleButton,
        ),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Channel 2'), warnIfMissed: false);
    await tester.tap(find.text('Channel 1'), warnIfMissed: false);
    await tester.pump();

    expect(find.text('2 of 7 on'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(2));
  });

  testWidgets('screen readers hear each channel as a checkbox that cannot be changed', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpView(tester, _view);

    expect(find.bySemanticsLabel('Enabled channels, 2 of 7 on'), findsOneWidget);
    for (final (n, checked) in [(1, true), (5, true), (2, false)]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel('Channel $n')),
        isSemantics(
          label: 'Channel $n',
          hasCheckedState: true,
          isChecked: checked,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
    }
    semantics.dispose();
  });

  testWidgets('fits a small phone at double text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpView(tester, _view, width: 320);

    expect(tester.takeException(), isNull);
  });
}

/// The box of channel [n].
Finder _option(int n) => find.ancestor(
  of: find.text('Channel $n'),
  matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Channel $n'),
);
