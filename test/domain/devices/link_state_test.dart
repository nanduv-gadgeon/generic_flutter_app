import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/devices/link_state.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';

void main() {
  // (status, online) -> state; the home card, the strip, the count and the banner all use this.
  final cases = <(LiveStatus?, bool), LinkState>{
    (LiveStatus.streaming, true): LinkState.connected,
    (LiveStatus.syncing, true): LinkState.connected,
    (LiveStatus.starting, true): LinkState.connected,
    (LiveStatus.connecting, true): LinkState.connecting,
    (LiveStatus.reconnecting, true): LinkState.reconnecting,
    (LiveStatus.waiting, true): LinkState.offline,
    (LiveStatus.streaming, false): LinkState.offline,
    (LiveStatus.reconnecting, false): LinkState.offline,
    (null, true): LinkState.offline,
  };
  for (final MapEntry(key: (status, online), value: expected) in cases.entries) {
    test('${status?.name ?? 'not linked'}, online $online -> ${expected.name}', () {
      expect(linkStateOf(status, online: online), expected);
    });
  }

  test('an on-demand device is never Offline', () {
    expect(linkStateOf(null, online: false, onDemand: true), LinkState.onDemand);
    expect(linkStateOf(LiveStatus.waiting, online: true, onDemand: true), LinkState.onDemand);
  });
}
