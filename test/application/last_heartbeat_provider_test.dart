import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/dashboard_provider.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/core/di/services.dart';

import '../fixtures/fake_live_readings.dart';

/// When a device was last heard from: the live time of the connected device, else the saved one.
void main() {
  final t = DateTime.utc(2026, 11, 23, 9);
  final older = t.subtract(const Duration(seconds: 10));

  // (live, saved) -> shown
  final cases = <(DateTime?, DateTime?), DateTime?>{
    (t, older): t, // live is newer: it wins
    (older, t): t, // the saved one is newer (e.g. live from before a reconnect)
    (null, older): older, // not the connected device
    (t, null): t, // never saved yet
    (null, null): null,
  };
  for (final MapEntry(key: (live, saved), value: shown) in cases.entries) {
    test('live $live, saved $saved -> $shown', () {
      final readings = FakeLiveReadings();
      if (live != null) readings.heartbeats[1] = live;
      final container = ProviderContainer(
        overrides: [
          liveReadingsProvider.overrideWithValue(readings),
          clockProvider.overrideWithValue(() => t),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(lastHeartbeatProvider(1, saved)), shown);
    });
  }

  test('another device\'s live heartbeat is not used', () {
    final readings = FakeLiveReadings()..heartbeats[2] = t;
    final container = ProviderContainer(
      overrides: [
        liveReadingsProvider.overrideWithValue(readings),
        clockProvider.overrideWithValue(() => t),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(lastHeartbeatProvider(1, older)), older);
  });
}
