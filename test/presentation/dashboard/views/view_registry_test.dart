import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/view_registry.dart';

import '../../../fixtures/dashboard_harness.dart';

void main() {
  test('every view type has a widget', () {
    expect(viewRegistry.keys.toSet(), DashboardViewType.values.toSet());
  });

  test('the value count is the main card and the tiles', () {
    DashboardData data(String id) => DashboardData(
      deviceId: 1,
      profile: vitaCareRegistry.byId(id),
      values: const {},
      live: false,
      now: DateTime.utc(2026),
    );

    expect(data('smart_band_v1').valueCount, 7);
    expect(data('ief_device_v1').valueCount, 4);
    expect(data('sensor_hub_v1').valueCount, 24);
    expect(data('thermometer_v1').valueCount, 0);
  });

  testWidgets('a view naming a reading the profile does not have shows nothing', (tester) async {
    final data = DashboardData(
      deviceId: 1,
      profile: vitaCareRegistry.byId('smart_band_v1'),
      values: const {},
      live: false,
      now: DateTime.utc(2026),
    );
    await pumpView(
      tester,
      buildView(data, const DashboardView(type: DashboardViewType.spotValue, reading: 'gone')),
    );

    expect(find.byType(SizedBox), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
