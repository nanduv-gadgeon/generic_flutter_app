import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';

import '../../fixtures/home_harness.dart';

/// "Seen N s ago" on a Home card: live while the device is connected, and counting up every
/// second, the same as the dashboard.
void main() {
  final start = DateTime.utc(2026, 11, 23, 9);
  final sensor = UserDevice(
    id: 2,
    name: 'Test sensor',
    profileId: 'ppg_motion_v1',
    lastHeartbeatAt: start.subtract(const Duration(seconds: 12)),
  );

  testWidgets('counts up every second with no new heartbeat', (tester) async {
    var now = start;
    await pumpHome(tester, devices: [sensor], clock: () => now);
    expect(find.text('Seen 12 s ago'), findsOneWidget);

    now = start.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Seen 15 s ago'), findsOneWidget);
  });

  testWidgets('the connected device shows its live heartbeat, not the saved one', (tester) async {
    await pumpHome(
      tester,
      devices: [sensor],
      now: start,
      heartbeats: {sensor.id: start.subtract(const Duration(seconds: 2))},
    );

    expect(find.text('Seen 2 s ago'), findsOneWidget);
  });
}
