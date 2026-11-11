import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/theme/app_tokens.dart';
import 'package:generic_flutter_app/domain/models/reading.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/parts/status_pill.dart';

import '../../../../fixtures/dashboard_harness.dart';

void main() {
  final cases = <StatusKind?, Color Function(AppTokens)>{
    StatusKind.ok: (t) => t.ok,
    StatusKind.warn: (t) => t.warn,
    StatusKind.danger: (t) => t.danger,
    null: (t) => t.muted,
  };
  for (final MapEntry(key: kind, value: colour) in cases.entries) {
    testWidgets('${kind?.name ?? 'no kind'}: the word in its colour', (tester) async {
      await pumpView(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: StatusPill('Word', kind: kind),
        ),
      );

      final tokens = Theme.of(tester.element(find.text('Word'))).extension<AppTokens>()!;
      expect(tester.widget<Text>(find.text('Word')).style!.color, colour(tokens));
    });
  }

  testWidgets('shrinks to its word instead of filling the row', (tester) async {
    await pumpView(
      tester,
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [StatusPill('High')]),
    );

    expect(tester.getSize(find.byType(StatusPill)).width, lessThan(100));
  });
}
