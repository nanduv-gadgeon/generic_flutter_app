import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/alerts/alert_card.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'alerts_test_app.dart';

/// An Alerts card's layout: the icon centred down the card, and how an unread card stands out.
void main() {
  setUpAll(() => initializeDateFormatting('en'));

  /// The card around [title]: its box and where it is.
  (BoxDecoration, Rect) card(WidgetTester tester, String title) {
    final box = find
        .ancestor(
          of: find.text(title),
          matching: find.byWidgetPredicate(
            (w) => w is Container && (w.decoration as BoxDecoration?)?.border != null,
          ),
        )
        .first;
    return (tester.widget<Container>(box).decoration! as BoxDecoration, tester.getRect(box));
  }

  testWidgets('the icon sits in the middle of the card', (tester) async {
    await pumpAlerts(tester, items: mixedAlerts, size: const Size(320, 844));
    const title = 'Missed 3 heartbeats – device offline';
    final (_, rect) = card(tester, title);
    final icon = find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.show_chart),
    );

    expect(tester.getCenter(icon).dy, moreOrLessEquals(rect.center.dy, epsilon: 0.5));
    expect(tester.getCenter(icon).dy - rect.top, greaterThan(40), reason: 'a tall card');
  });

  testWidgets('an unread card is tinted, with a primary border and bar and a bolder title', (
    tester,
  ) async {
    await pumpAlerts(tester, items: mixedAlerts);
    final scheme = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
    const unread = 'Heart rate above 110 bpm';
    const read = 'Missed 3 heartbeats – device offline';
    Finder barOf(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(AlertCard)),
      matching: find.byKey(AlertCard.unreadBarKey),
    );

    final (unreadBox, _) = card(tester, unread);
    final (readBox, _) = card(tester, read);
    expect(
      unreadBox.color,
      Color.alphaBlend(scheme.primary.withValues(alpha: 0.08), readBox.color!),
    );
    expect(unreadBox.border!.top.color, scheme.primary.withValues(alpha: 0.6));
    expect(unreadBox.border!.top.width, 1.5);
    expect(readBox.border!.top.color, isNot(unreadBox.border!.top.color));
    expect(readBox.border!.top.width, 1);
    expect(barOf(unread), findsOneWidget);
    expect(barOf(read), findsNothing);
    expect(tester.getSize(barOf(unread)).width, 4);
    expect(tester.widget<Text>(find.text(unread)).style!.fontWeight, FontWeight.w700);
    expect(tester.widget<Text>(find.text(read)).style!.fontWeight, FontWeight.w600);
  });
}
