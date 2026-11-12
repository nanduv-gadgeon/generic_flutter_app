import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/dashboard/live_device_screen.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/gauge_view.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/note_view.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/reading_list_view.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/spot_value_view.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/tiles_view.dart';
import 'package:generic_flutter_app/presentation/dashboard/views/waveform_view.dart';

import '../../fixtures/dashboard_harness.dart';
import '../../fixtures/mockup_dashboards.dart';
import '../../fixtures/scripted_live_readings.dart';

/// Each VitaCare profile builds its mockup dashboard (screens 13–21) from config alone, with the
/// mockup's made-up values.
void main() {
  // Views in order, strip cells, and what a screen reader hears for some readings.
  final expected = <String, (List<Type>, List<String>, List<String>)>{
    'smart_band_v1': (
      [GaugeView, TilesView],
      ['Link: Bluetooth', 'Battery: 78%', 'Heartbeat: 12 s ago'],
      ['Heart rate, 72 bpm, Normal', 'Blood pressure, 118/76 mmHg, Normal', 'Steps, 6,482 today'],
    ),
    'env_sensor_v1': (
      [GaugeView, TilesView],
      ['Link: Wi‑Fi', 'Battery: 42%', 'Heartbeat: 45 s ago'],
      ['Temperature, 24.3 °C, Normal', 'CO₂, 1,140 ppm, High'],
    ),
    'wearable_patch_v1': (
      [GaugeView, TilesView],
      ['Battery: 64%', 'Heartbeat: 8 s ago'],
      ['Heart rate, 78 bpm, Normal', 'Active time, 96 min today'],
    ),
    'health_kit_v1': (
      [GaugeView, TilesView],
      ['Battery: 88%', 'Heartbeat: 1 min ago'],
      ['Blood pressure, 126/82 mmHg, High', 'Weight, 72.4 kg, Normal'],
    ),
    'ief_device_v1': (
      [GaugeView, TilesView],
      ['Battery: 97%', 'State: Running'],
      ['Current, 11.8 mA, Normal', 'Run time, 2.0 h', 'Sessions, 3', 'Errors, 1, High'],
    ),
    'thermometer_v1': (
      [SpotValueView, NoteView, ReadingListView],
      ['Link: On demand', 'Battery: 64%', 'Last reading: 08:42'],
      ['Temperature, 37.9 °C, High', '07:10, Temperature, 38.4 °C, Fever'],
    ),
    'ecg_monitor_v1': (
      [GaugeView, TilesView, WaveformView],
      ['Battery: 58%', 'Stream: 250 Hz'],
      ['Heart rate, 76 bpm, Normal', 'R-R interval, 789 ms, Normal', 'Rhythm, Sinus rhythm'],
    ),
    'sensor_hub_v1': (
      [GaugeView, TilesView],
      ['Battery: 81%', 'Channels: 23 live'],
      ['CH01 Boiler inlet, 62.4 °C, Normal', 'CH07 Line A pressure, 8.9 bar, High'],
    ),
    'ppg_motion_v1': (
      [GaugeView, TilesView],
      ['Battery: 85%', 'Heartbeat: 2 s ago'],
      ['SpO₂, 97 %, Normal', 'Heart rate, 65 bpm, Normal', 'PI (Red), 0.098, Normal'],
    ),
  };

  test('covers every offered device type', () {
    expect(expected.keys, [for (final p in vitaCareRegistry.offered) p.id]);
    expect(mockupDashboards.keys, expected.keys);
  });

  for (final MapEntry(key: id, value: (views, strip, spoken)) in expected.entries) {
    testWidgets('$id builds its dashboard from config', (tester) async {
      final mockup = mockupDashboards[id]!;
      tester.view
        ..physicalSize = const Size(390, 4400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final live = ScriptedLiveReadings();
      await tester.pumpWidget(
        ProviderScope(
          overrides: dashboardOverrides(
            live: live,
            devices: [mockup.device],
            now: mockupNow,
            readings: mockup.readings(),
            events: mockup.eventStore(),
          ),
          child: dashboardApp(LiveDeviceScreen(deviceId: mockup.device.id)),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
      mockup.updates().forEach(live.send);
      await tester.pump(const Duration(milliseconds: 50));

      final shown = find.byWidgetPredicate((w) => views.contains(w.runtimeType));
      expect([for (final e in shown.evaluate()) e.widget.runtimeType], views);
      for (final label in [...strip, ...spoken]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      expect(find.text('Connecting…'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the hub channel with no value says No signal', (tester) async {
    final mockup = mockupDashboards['sensor_hub_v1']!;
    tester.view
      ..physicalSize = const Size(390, 4400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final live = ScriptedLiveReadings();
    await tester.pumpWidget(
      ProviderScope(
        overrides: dashboardOverrides(live: live, devices: [mockup.device], now: mockupNow),
        child: dashboardApp(LiveDeviceScreen(deviceId: mockup.device.id)),
      ),
    );
    await tester.pump();
    await tester.pump();
    mockup.updates().forEach(live.send);
    await tester.pump();

    expect(find.bySemanticsLabel('CH21 Store room, no reading yet, No signal'), findsOneWidget);
  });
}
