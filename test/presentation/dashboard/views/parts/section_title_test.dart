import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/parts/section_title.dart';

import '../../../../fixtures/dashboard_harness.dart';
import '../../../../fixtures/text_fit_checks.dart';

void main() {
  // Real letter widths, so layouts that depend on text fitting behave as on a phone.
  setUpAll(loadRealFont);

  testWidgets('the title is a heading, with its note on the right', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpView(tester, const SectionTitle('All readings', trailing: '7 values · live'));

    expect(
      tester.getSemantics(find.text('All readings')),
      matchesSemantics(label: 'All readings', isHeader: true),
    );
    expect(
      tester.getTopRight(find.text('7 values · live')).dx,
      greaterThan(tester.getTopRight(find.text('All readings')).dx),
    );
    semantics.dispose();
  });

  testWidgets('without a note', (tester) async {
    await pumpView(tester, const SectionTitle('Today’s readings'));
    expect(find.text('Today’s readings'), findsOneWidget);
  });
}
