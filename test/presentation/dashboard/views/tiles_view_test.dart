import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/reading_tile.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/tiles_view.dart';

import '../../../fixtures/dashboard_harness.dart';
import '../../../fixtures/dashboard_readings.dart';

void main() {
  testWidgets('"All readings", the count, and two tiles a row of equal height', (tester) async {
    await pumpView(
      tester,
      const TilesView(
        readings: [hrReading, stepsReading, sessionsReading],
        values: {'hr': 72, 'steps': 6482, 'sessions': 3},
        count: 4,
        live: true,
      ),
    );

    expect(find.text('All readings'), findsOneWidget);
    expect(find.text('4 values · live'), findsOneWidget);
    final tiles = find.byType(ReadingTile);
    expect(tiles, findsNWidgets(3));
    expect(tester.getTopLeft(tiles.at(0)).dy, tester.getTopLeft(tiles.at(1)).dy);
    expect(tester.getSize(tiles.at(0)).height, tester.getSize(tiles.at(1)).height);
    expect(tester.getTopLeft(tiles.at(2)).dy, greaterThan(tester.getBottomLeft(tiles.at(0)).dy));
  });

  testWidgets('not live: just the count', (tester) async {
    await pumpView(tester, const TilesView(readings: [hrReading], values: {}, count: 2));
    expect(find.text('2 values'), findsOneWidget);
  });
}
