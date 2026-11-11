import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/parts/scale_bar.dart';

import '../../../../fixtures/dashboard_harness.dart';

/// The bar is 358 px wide (390 less 16 px padding each side).
const _width = 358.0;

Rect _rect(WidgetTester tester, Color color) => tester.getRect(
  find.byWidgetPredicate(
    (w) => w is DecoratedBox && (w.decoration as BoxDecoration).color == color,
  ),
);

void main() {
  const band = Color(0xFF00FF00);

  testWidgets('a band from its start to its end, and the marker centred on its value', (
    tester,
  ) async {
    await pumpView(
      tester,
      const ScaleBar(
        bands: [(start: 0.25, end: 0.5, color: band)],
        marker: 0.75,
        markerColor: Colors.red,
      ),
    );

    final bandRect = _rect(tester, band);
    final left = tester.getTopLeft(find.byType(ScaleBar)).dx;
    expect(bandRect.left - left, closeTo(_width * 0.25, 0.5));
    expect(bandRect.width, closeTo(_width * 0.25, 0.5));
    final marker = tester.getRect(
      find.descendant(of: find.byType(ScaleBar), matching: find.byType(Container)),
    );
    expect(marker.center.dx - left, closeTo(_width * 0.75, 0.5));
    expect(tester.getSize(find.byType(ScaleBar)).height, 14);
  });

  testWidgets('a fill from the left for progress, clamped to the bar', (tester) async {
    await pumpView(tester, const ScaleBar(fill: 1.4, fillColor: band));

    expect(_rect(tester, band).width, closeTo(_width, 0.5));
    expect(tester.getSize(find.byType(ScaleBar)).height, 6);
  });

  testWidgets('joined bands meet as one bar, clipped at the ends', (tester) async {
    await pumpView(
      tester,
      const ScaleBar(
        height: 8,
        joined: true,
        bands: [(start: 0, end: 0.5, color: band), (start: 0.5, end: 1, color: Colors.red)],
      ),
    );

    expect(find.byType(ClipRRect), findsOneWidget);
    expect(_rect(tester, band).right, closeTo(_rect(tester, Colors.red).left, 0.5));
  });
}
