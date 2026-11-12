import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/dashboard_provider.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/application/live_device_provider.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';

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

  final cases = <String, (LiveDeviceState, Map<String, Sample>, EventSummary, Map<String, double>)>{
    'streaming: live values only, plus event values': (
      const LiveDeviceState(status: LiveStatus.streaming, values: {'current': 11.8}),
      {'current': s('current', 9), 'battery': s('battery', 50)},
      summary,
      {'current': 11.8, 'run_time': 2.5, 'sessions': 3, 'errors': 1},
    ),
    'connecting: stored values, live ones on top': (
      const LiveDeviceState(values: {'battery': 97}),
      {'current': s('current', 9), 'battery': s('battery', 50)},
      EventSummary.empty,
      {'current': 9, 'battery': 97},
    ),
    'Offline while streaming: stored values come back': (
      const LiveDeviceState(status: LiveStatus.streaming, online: false),
      {'current': s('current', 9)},
      EventSummary.empty,
      {'current': 9},
    ),
  };
  for (final MapEntry(key: name, value: (live, stored, events, expected)) in cases.entries) {
    test('dashboardValues, $name', () {
      expect(dashboardValues(therapy, live, stored, events), expected);
    });
  }

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

  test('eventSummary sums today’s events, with a session still running up to now', () async {
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
      const EventSummary(sessions: 2, runTime: Duration(hours: 2), errors: 0, running: true),
    );
  });

  test('eventSummary before events load: nothing known', () {
    expect(container().read(eventSummaryProvider(5)), EventSummary.empty);
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
