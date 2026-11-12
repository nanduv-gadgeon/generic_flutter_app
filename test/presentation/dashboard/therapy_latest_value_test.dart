import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/user_device.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';
import 'package:generic_flutter_app/presentation/dashboard/live_device_screen.dart';

import '../../fixtures/dashboard_harness.dart';
import '../../fixtures/scripted_live_readings.dart';

final _now = DateTime.utc(2026, 11, 11, 9);

const _therapy = UserDevice(id: 5, name: 'Therapy device 8038', profileId: 'ief_device_v1');
const _sensor = UserDevice(id: 1, name: 'Finger sensor', profileId: 'ppg_motion_v1');

/// The therapy device logs its current every ~15 min and the app fetches the log every 60 s, so
/// most of the time there is nothing new: its Live dashboard keeps showing the newest current,
/// stored or just fetched, never an empty gauge with "No signal".
void main() {
  late ScriptedLiveReadings live;
  late FakeReadingRepository readings;

  setUp(() {
    live = ScriptedLiveReadings();
    readings = FakeReadingRepository();
  });

  Future<void> pump(WidgetTester tester, UserDevice device) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: dashboardOverrides(live: live, devices: [device], now: _now, readings: readings),
        child: dashboardApp(LiveDeviceScreen(deviceId: device.id)),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  }

  Future<void> send(WidgetTester tester, List<LiveUpdate> updates) async {
    updates.forEach(live.send);
    await tester.pump();
  }

  testWidgets('connected, nothing new fetched: the stored current and when it was logged', (
    tester,
  ) async {
    readings.latest[5] = {
      'current': Sample('current', 11.8, _now.subtract(const Duration(hours: 2))),
    };
    await pump(tester, _therapy);
    await send(tester, [const LiveStatusChanged(LiveStatus.streaming)]);

    expect(find.bySemanticsLabel('Current, 11.8 mA, Normal'), findsOneWidget);
    expect(find.text('Last reading 2 h ago'), findsOneWidget);
    expect(find.text('No signal'), findsNothing);
  });

  testWidgets('a fetch of several entries shows the newest current, whatever their order', (
    tester,
  ) async {
    readings.latest[5] = {'current': Sample('current', 9, _now.subtract(const Duration(hours: 1)))};
    await pump(tester, _therapy);
    await send(tester, [
      const LiveStatusChanged(LiveStatus.streaming),
      LiveValue(Sample('current', 12.4, _now.subtract(const Duration(minutes: 2)))),
      LiveValue(Sample('current', 10.1, _now.subtract(const Duration(minutes: 30)))),
    ]);

    // The writer has not stored them yet; the newest by the device's time still wins.
    expect(find.bySemanticsLabel('Current, 12.4 mA, Normal'), findsOneWidget);
  });

  testWidgets('connected with no current ever: an empty gauge, but not "No signal"', (
    tester,
  ) async {
    await pump(tester, _therapy);
    await send(tester, [const LiveStatusChanged(LiveStatus.streaming)]);

    expect(find.bySemanticsLabel(RegExp('^Current, no reading yet')), findsOneWidget);
    expect(find.text('No signal'), findsNothing);
  });

  testWidgets('a streaming sensor with no value still says "No signal"', (tester) async {
    readings.latest[1] = {'spo2': Sample('spo2', 95, _now.subtract(const Duration(hours: 2)))};
    await pump(tester, _sensor);
    await send(tester, [const LiveStatusChanged(LiveStatus.streaming)]);

    // Its stored SpO₂ is old, so it is not shown as live.
    expect(find.bySemanticsLabel(RegExp('^SpO₂, no reading yet')), findsOneWidget);
    expect(find.text('No signal'), findsWidgets);
  });
}
