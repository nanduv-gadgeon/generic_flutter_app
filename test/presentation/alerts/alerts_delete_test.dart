import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/alerts_provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../fixtures/l10n.dart';
import 'alerts_test_app.dart';

/// Deleting alerts: swipe left (with Undo), the screen reader action, and Clear all.
void main() {
  setUpAll(() => initializeDateFormatting('en'));

  final first = mixedAlerts.first;
  const firstTitle = 'Heart rate above 110 bpm';

  Future<void> swipeLeft(WidgetTester tester, String title) async {
    await tester.drag(find.text(title), const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  Finder clearAllButton() => find.widgetWithText(TextButton, en.alertsClearAll);

  /// The "Clear all" in the confirm dialog.
  Finder confirmClear() =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(en.alertsClearAll));

  group('swipe left', () {
    testWidgets('deletes the alert at once and offers Undo', (tester) async {
      final list = StreamController<List<AlertListItem>>();
      addTearDown(list.close);
      list.add(mixedAlerts);
      final calls = await pumpAlerts(tester, stream: list.stream);

      await swipeLeft(tester, firstTitle);

      expect(calls.deleted, [first.alert.id]);
      expect(find.text(firstTitle), findsNothing);
      expect(find.text(en.alertDeleted), findsOneWidget);
      expect(find.text(en.alertDeleteUndo), findsOneWidget);

      // The stored list catches up; the alert stays gone.
      list.add(mixedAlerts.skip(1).toList());
      await tester.pumpAndSettle();
      expect(find.text(firstTitle), findsNothing);
    });

    testWidgets('Undo stores the alert again', (tester) async {
      final calls = await pumpAlerts(tester, items: mixedAlerts);

      await swipeLeft(tester, firstTitle);
      await tester.tap(find.text(en.alertDeleteUndo));
      await tester.pumpAndSettle();

      expect(calls.restored, [first.alert]);
    });

    testWidgets('Undo failing says so', (tester) async {
      await pumpAlerts(tester, items: mixedAlerts, restore: (_) async => throw Exception('db'));

      await swipeLeft(tester, firstTitle);
      await tester.tap(find.text(en.alertDeleteUndo));
      await tester.pumpAndSettle();

      expect(find.text(en.alertRestoreFailed), findsOneWidget);
    });

    testWidgets('a failed delete puts the card back and says so', (tester) async {
      await pumpAlerts(tester, items: mixedAlerts, delete: (_) async => throw Exception('db'));

      await swipeLeft(tester, firstTitle);

      expect(find.text(firstTitle), findsOneWidget);
      expect(find.text(en.alertDeleteFailed), findsOneWidget);
    });

    testWidgets('swiping right does nothing', (tester) async {
      final calls = await pumpAlerts(tester, items: mixedAlerts);

      await tester.drag(find.text(firstTitle), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(calls.deleted, isEmpty);
      expect(find.text(firstTitle), findsOneWidget);
    });
  });

  testWidgets('screen readers get a Delete alert action on each card', (tester) async {
    final semantics = tester.ensureSemantics();
    final calls = await pumpAlerts(tester, items: mixedAlerts);

    final card = find.semantics.byLabel(RegExp('^$firstTitle'));
    final action = card.evaluate().single.getSemanticsData().customSemanticsActionIds!.single;
    expect(CustomSemanticsAction.getAction(action)!.label, en.alertDeleteAction);
    tester.semantics.performAction(card, SemanticsAction.customAction, args: action);
    await tester.pumpAndSettle();

    expect(calls.deleted, [first.alert.id]);
    expect(find.text(firstTitle), findsNothing);
    semantics.dispose();
  });

  group('Clear all', () {
    testWidgets('is off with no alerts', (tester) async {
      await pumpAlerts(tester);

      expect(tester.widget<TextButton>(clearAllButton()).onPressed, isNull);
    });

    testWidgets('asks first; Cancel deletes nothing', (tester) async {
      final calls = await pumpAlerts(tester, items: mixedAlerts);

      await tester.tap(clearAllButton());
      await tester.pumpAndSettle();
      expect(find.text(en.alertsClearAllTitle), findsOneWidget);
      expect(find.text(en.alertsClearAllBody), findsOneWidget);

      await tester.tap(find.text(en.commonCancel));
      await tester.pumpAndSettle();
      expect(calls.cleared, 0);
      expect(find.text(firstTitle), findsOneWidget);
    });

    testWidgets('confirmed: deletes all, whatever the filter, and says so', (tester) async {
      final calls = await pumpAlerts(tester, items: mixedAlerts);
      await tester.tap(find.text(en.alertFilterHealth));
      await tester.pumpAndSettle();

      await tester.tap(clearAllButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmClear());
      await tester.pumpAndSettle();

      expect(calls.cleared, 1);
      expect(find.text(en.alertsCleared), findsOneWidget);
    });

    testWidgets('failing says so', (tester) async {
      await pumpAlerts(tester, items: mixedAlerts, clear: () async => throw Exception('db'));

      await tester.tap(clearAllButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmClear());
      await tester.pumpAndSettle();

      expect(find.text(en.alertsClearFailed), findsOneWidget);
    });
  });
}
