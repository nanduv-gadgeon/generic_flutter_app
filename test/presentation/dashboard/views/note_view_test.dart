import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/note_view.dart';

import '../../../fixtures/dashboard_harness.dart';

void main() {
  testWidgets('shows the config text with an info icon, and reads it out', (tester) async {
    await pumpView(tester, const NoteView(text: 'This device sends a reading when used.'));

    expect(find.text('This device sends a reading when used.'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.bySemanticsLabel('This device sends a reading when used.'), findsOneWidget);
  });
}
