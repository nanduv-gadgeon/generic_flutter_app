import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/dashboard_provider.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/application/live_device_provider.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';

import '../fixtures/dashboard_harness.dart';
import '../fixtures/scripted_live_readings.dart';

void main() {
  final now = DateTime(2026, 11, 11, 9);
  final therapy = vitaCareRegistry.byId('ief_device_v1');
  const summary = EventSummary(
    sessions: 3,
    runTime: Duration(minutes: 150),
    errors: 1,
    running: true,
  );
  Sample s(String key, double v) => Sample(key, v, now);

  final ppg = vitaCareRegistry.byId('ppg_motion_v1');
  Sample at(String key, double v, Duration ago) => Sample(key, v, now.subtract(ago));
  const streaming = LiveStatus.streaming;
  final events = {'run_time': 2.5, 'sessions': 3.0, 'errors': 1.0};

  // Each case: profile, live state, stored newest values, expected dashboard values.
  final cases =
      <String, (DeviceProfile, LiveDeviceState, Map<String, Sample>, Map<String, double>)>{
        // A streaming device: an old stored value must never look live.
        'PPG streaming: live values only': (
          ppg,
          const LiveDeviceState(status: streaming, values: {'spo2': 97}),
          {'spo2': s('spo2', 95), 'battery': s('battery', 50)},
          {'spo2': 97},
        ),
        'PPG connecting: stored values, live ones on top': (
          ppg,
          const LiveDeviceState(values: {'battery': 97}),
          {'spo2': s('spo2', 95), 'battery': s('battery', 50)},
          {'spo2': 95, 'battery': 97},
        ),
        'PPG Offline while streaming: stored values come back': (
          ppg,
          const LiveDeviceState(status: streaming, online: false),
          {'spo2': s('spo2', 95)},
          {'spo2': 95},
        ),
        // A device that reads logs: its newest reading, stored or just fetched.
        'therapy connected, nothing fetched yet: the stored current': (
          therapy,
          const LiveDeviceState(status: streaming),
          {'current': at('current', 9, const Duration(hours: 2)), 'battery': s('battery', 91)},
          {'current': 9, 'battery': 91, ...events},
        ),
        'therapy: a newer fetched current replaces the stored one': (
          therapy,
          LiveDeviceState(
            status: streaming,
            values: const {'current': 11.8},
            times: {'current': now},
          ),
          {'current': at('current', 9, const Duration(minutes: 15))},
          {'current': 11.8, ...events},
        ),
        'therapy: an older entry of the same fetch does not replace a newer stored one': (
          therapy,
          LiveDeviceState(
            status: streaming,
            values: const {'current': 10},
            times: {'current': now.subtract(const Duration(minutes: 10))},
          ),
          {'current': at('current', 12, const Duration(minutes: 5))},
          {'current': 12, ...events},
        ),
        'therapy: a live value of unknown time counts as the newest': (
          therapy,
          const LiveDeviceState(status: streaming, values: {'current': 11.8}),
          {'current': s('current', 9)},
          {'current': 11.8, ...events},
        ),
        'therapy Offline: the stored current': (
          therapy,
          const LiveDeviceState(status: streaming, online: false),
          {'current': s('current', 9)},
          {'current': 9, ...events},
        ),
      };
  for (final MapEntry(key: name, value: (profile, live, stored, expected)) in cases.entries) {
    test('dashboardValues, $name', () {
      expect(dashboardValues(profile, live, stored, summary), expected);
    });
  }

  test('dashboardTimes: when each shown value was measured', () {
    final stored = {'current': at('current', 9, const Duration(hours: 2))};
    final live = LiveDeviceState(
      status: streaming,
      values: const {'battery': 91},
      times: {'battery': now},
    );

    expect(dashboardTimes(therapy, live, stored), {
      'current': now.subtract(const Duration(hours: 2)),
      'battery': now,
    });
  });

  test('readsLogs: the therapy device does, the PPG sensor streams', () {
    expect(readsLogs(therapy), isTrue);
    expect(readsLogs(ppg), isFalse);
  });

  test('startOfDay is local midnight', () {
    expect(startOfDay(DateTime(2026, 11, 11, 9, 30)), DateTime(2026, 11, 11));
  });

  ProviderContainer container({FakeDeviceEventRepository? events, ScriptedLiveReadings? live}) {
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        dashboardNowProvider.overrideWith((ref) => Stream.value(now)),
        deviceEventRepositoryProvider.overrideWithValue(events ?? FakeDeviceEventRepository()),
        readingRepositoryProvider.overrideWithValue(FakeReadingRepository()),
        liveReadingsProvider.overrideWithValue(live ?? ScriptedLiveReadings()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'eventSummary: first START to last STOP today; a session still running is not counted yet',
    () async {
      DateTime at(int h) => DateTime(2026, 11, 11, h).toUtc();
      final events = FakeDeviceEventRepository()
        ..events[5] = [
          DeviceEvent(DeviceEventKind.start, at(6), code: 0),
          DeviceEvent(DeviceEventKind.stop, at(7), code: 0),
          DeviceEvent(DeviceEventKind.start, at(8), code: 0),
        ];
      final c = container(events: events);
      c.listen(eventSummaryProvider(5), (_, _) {});
      await c.read(recentEventsProvider(5).future);
      await c.read(dashboardNowProvider.future);

      expect(
        c.read(eventSummaryProvider(5)),
        const EventSummary(sessions: 2, runTime: Duration(hours: 1), errors: 0, running: true),
      );
    },
  );

  test('eventSummary before events load: nothing known', () {
    expect(container().read(eventSummaryProvider(5)), EventSummary.empty);
  });

  test(
    'liveDevice keeps when each value was measured; a lost finger clears all but battery',
    () async {
      final live = ScriptedLiveReadings();
      final c = container(live: live);
      c.listen(liveDeviceProvider(7), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final logged = now.subtract(const Duration(minutes: 15));
      live
        ..send(LiveValue(Sample('current', 11.8, logged)))
        ..send(LiveValue(Sample('battery', 91, now)));
      await Future<void>.delayed(Duration.zero);

      expect(c.read(liveDeviceProvider(7)).times, {'current': logged, 'battery': now});

      live.send(const LiveContactChanged(SensorContact.none));
      await Future<void>.delayed(Duration.zero);

      expect(c.read(liveDeviceProvider(7)).times, {'battery': now});
    },
  );

  test('liveDevice keeps the newest value by measured time, not the last to arrive', () async {
    final live = ScriptedLiveReadings();
    final c = container(live: live);
    c.listen(liveDeviceProvider(7), (_, _) {});
    await Future<void>.delayed(Duration.zero);
    // One log fetch: a newer entry, then an older one.
    live
      ..send(LiveValue(Sample('current', 12.4, now.subtract(const Duration(minutes: 2)))))
      ..send(LiveValue(Sample('current', 10.1, now.subtract(const Duration(minutes: 30)))));
    await Future<void>.delayed(Duration.zero);

    expect(c.read(liveDeviceProvider(7)).values['current'], 12.4);
  });

  test('waveform keeps the latest samples of its key, up to its size', () async {
    final live = ScriptedLiveReadings();
    final c = container(live: live);
    c.listen(waveformProvider(7, 'ecg', 3), (_, _) {});
    for (final v in <double>[1, 2, 3, 4]) {
      live.send(LiveValue(Sample('ecg', v, now)));
    }
    live.send(LiveValue(Sample('hr', 70, now)));
    await Future<void>.delayed(Waveform.frame * 2);

    expect(c.read(waveformProvider(7, 'ecg', 3)), [2, 3, 4]);
  });
}
