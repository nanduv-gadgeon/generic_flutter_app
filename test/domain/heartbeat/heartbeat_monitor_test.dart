import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/heartbeat/heartbeat_monitor.dart';
import 'package:generic_flutter_app/domain/models/heartbeat_settings.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 11, 9);

  /// Runs [beats] (seconds after start) for [seconds], and returns each change as
  /// (second, online).
  List<(int, bool)> run(HeartbeatSettings settings, List<int> beats, int seconds) {
    final changes = <(int, bool)>[];
    fakeAsync((async) {
      DateTime now() => t0.add(async.elapsed);
      final monitor = HeartbeatMonitor(
        settings,
        (online, _) => changes.add((async.elapsed.inSeconds, online)),
        now: now,
      )..start();
      for (var s = 0; s <= seconds; s++) {
        if (beats.contains(s)) monitor.beat();
        async.elapse(const Duration(seconds: 1));
      }
      monitor.stop();
    });
    return changes;
  }

  const every60 = HeartbeatSettings();
  const every10x2 = HeartbeatSettings(intervalSeconds: 10, offlineAfterMissed: 2);

  final cases = <String, (HeartbeatSettings, List<int>, int, List<(int, bool)>)>{
    'beats every interval: always online': (every60, [30, 90, 150, 210, 270], 300, []),
    'never heard from: offline after 3 intervals': (every60, [], 200, [(180, false)]),
    'silent after a beat: offline 3 intervals later, checked each interval': (
      every60,
      [10],
      300,
      [(240, false)],
    ),
    'back online on the next beat, offline again after another silence': (
      every10x2,
      [0, 35],
      70,
      [(20, false), (35, true), (60, false)],
    ),
    'reported once while it stays offline': (every10x2, [], 100, [(20, false)]),
  };

  for (final MapEntry(key: name, value: (settings, beats, seconds, expected)) in cases.entries) {
    test(name, () => expect(run(settings, beats, seconds), expected));
  }

  test('passes when it was last heard from', () {
    fakeAsync((async) {
      final calls = <(bool, DateTime?)>[];
      final monitor = HeartbeatMonitor(
        every10x2,
        (online, lastAt) => calls.add((online, lastAt)),
        now: () => t0.add(async.elapsed),
      )..start();
      async.elapse(const Duration(seconds: 5));
      monitor.beat();
      async.elapse(const Duration(seconds: 30));

      expect(calls, [(false, t0.add(const Duration(seconds: 5)))]);
      expect(monitor.online, isFalse);
      expect(monitor.lastAt, t0.add(const Duration(seconds: 5)));
      monitor.stop();
    });
  });

  test('stop ends the checks', () {
    fakeAsync((async) {
      final calls = <bool>[];
      HeartbeatMonitor(every10x2, (online, _) => calls.add(online))
        ..start()
        ..stop();
      async.elapse(const Duration(minutes: 5));

      expect(calls, isEmpty);
    });
  });

  test('settings: the defaults are every 60 s, offline after 3 missed', () {
    final defaults = HeartbeatSettings.fromJson(const {});
    expect(defaults.interval, const Duration(seconds: 60));
    expect(defaults.offlineAfter, const Duration(minutes: 3));
    expect(defaults.setInterval, isNull);
  });
}
