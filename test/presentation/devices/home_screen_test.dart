import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';

import '../../fixtures/fake_auth.dart';
import '../../fixtures/home_harness.dart';

void main() {
  testWidgets('greets the user by first name', (tester) async {
    await pumpHome(tester, now: DateTime(2026, 1, 1, 18));

    expect(find.text('Good evening,'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
  });

  testWidgets('a very long first name stays on one line (TC-REG-011)', (tester) async {
    final longName = 'T' * 300; // one word, so all of it is the "first name"
    await pumpHome(tester, user: fakeUser.copyWith(name: longName));

    expect(tester.takeException(), isNull);
    final name = tester.renderObject<RenderParagraph>(find.text(longName));
    expect(name.didExceedMaxLines, isTrue); // ends with an ellipsis
  });

  testWidgets('with no devices shows zero totals and the empty card', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHome(tester);

    for (final label in ['0 Devices', '0 Connected', '0 Alerts']) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    expect(find.text('My devices'), findsOneWidget);
    expect(find.text('No devices yet'), findsOneWidget);
    expect(find.text('Add your first device to start monitoring.'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('with devices shows the count and no empty card', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHome(
      tester,
      devices: const [
        UserDevice(id: 1, name: 'Test band', profileId: 'test_device_v1'),
        UserDevice(id: 2, name: 'Test sensor', profileId: 'test_device_v1'),
      ],
    );

    expect(find.bySemanticsLabel('2 Devices'), findsOneWidget);
    expect(find.text('No devices yet'), findsNothing);
    semantics.dispose();
  });

  // Both buttons open Add device: the round + in the header and the one in the empty card.
  final addButtons = <String, Finder Function()>{
    'header +': () => find.byIcon(Icons.add).first,
    'empty card': () => find.widgetWithText(FilledButton, 'Add device'),
  };
  for (final MapEntry(key: name, value: button) in addButtons.entries) {
    testWidgets('$name opens Add device', (tester) async {
      await pumpHome(tester);

      await tester.tap(button());
      await tester.pumpAndSettle();

      expect(find.text('add device page'), findsOneWidget);
    });
  }

  testWidgets('the + button is labelled for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHome(tester);

    expect(find.bySemanticsLabel('Add device'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('works in dark mode', (tester) async {
    await pumpHome(tester, brightness: Brightness.dark);

    expect(tester.takeException(), isNull);
    expect(find.text('No devices yet'), findsOneWidget);
  });

  testWidgets('works on a small phone with double text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpHome(tester, size: const Size(320, 568));

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Add device'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(tester.takeException(), isNull); // no overflow
  });
}
