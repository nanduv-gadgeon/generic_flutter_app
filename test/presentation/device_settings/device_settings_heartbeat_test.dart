import 'package:flutter_test/flutter_test.dart';

import 'device_settings_test_app.dart';

/// Device settings' "Last heartbeat": live while the device is connected, counting up every
/// second, the same as Home and the dashboard.
void main() {
  Finder lastHeartbeat(String ago) => find.text(ago);

  testWidgets('counts up every second with no new heartbeat', (tester) async {
    var now = testNow; // 12 s after the saved heartbeat
    await pumpSettings(tester, device: band, clock: () => now);
    expect(lastHeartbeat('12 s ago'), findsOneWidget);

    now = testNow.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));

    expect(lastHeartbeat('17 s ago'), findsOneWidget);
  });

  testWidgets('the connected device shows its live heartbeat, not the saved one', (tester) async {
    var now = testNow;
    await pumpSettings(tester, device: band, clock: () => now);
    live.heartbeats[band.id] = testNow.subtract(const Duration(seconds: 1));

    now = testNow.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(lastHeartbeat('2 s ago'), findsOneWidget);
  });
}
