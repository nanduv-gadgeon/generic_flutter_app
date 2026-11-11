import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/reading_list_view.dart';

import '../../../fixtures/dashboard_harness.dart';
import '../../../fixtures/dashboard_readings.dart';

void main() {
  Sample at(int h, int m, double v) => Sample('temp', v, DateTime(2026, 11, 11, h, m).toUtc());

  testWidgets('newest first, each with its time, value and zone', (tester) async {
    await pumpView(
      tester,
      ReadingListView(reading: tempReading, samples: [at(7, 10, 38.4), at(8, 42, 37.9)]),
    );

    expect(find.text('Today’s readings'), findsOneWidget);
    expect(find.text('2 readings'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('08:42')).dy,
      lessThan(tester.getTopLeft(find.text('07:10')).dy),
    );
    expect(find.text('37.9 °C'), findsOneWidget);
    expect(find.text('Fever'), findsOneWidget);
    expect(find.bySemanticsLabel('08:42, Temperature, 37.9 °C, High'), findsOneWidget);
  });

  testWidgets('one reading', (tester) async {
    await pumpView(tester, ReadingListView(reading: tempReading, samples: [at(8, 0, 36.8)]));
    expect(find.text('1 reading'), findsOneWidget);
  });

  testWidgets('nothing yet', (tester) async {
    await pumpView(tester, const ReadingListView(reading: tempReading, samples: []));

    expect(find.text('0 readings'), findsOneWidget);
    expect(find.text('Nothing to show'), findsOneWidget);
  });
}
