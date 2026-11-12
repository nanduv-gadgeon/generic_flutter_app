import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/parts/dash_card.dart';

import '../../../../fixtures/dashboard_harness.dart';

void main() {
  testWidgets('a bordered card with the config corner radius around its child', (tester) async {
    await pumpView(tester, const DashCard(child: Text('inside')));

    expect(find.text('inside'), findsOneWidget);
    final box = tester.widget<Container>(find.byType(Container).first).decoration! as BoxDecoration;
    expect(box.borderRadius, BorderRadius.circular(testTheme.cornerRadius));
    expect(box.border, isNotNull);
  });
}
