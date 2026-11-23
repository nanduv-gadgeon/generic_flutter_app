import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/alerts/local_alert_engine.dart';
import 'package:generic_flutter_app/domain/services/alert_notifier.dart';
import 'package:generic_flutter_app/domain/services/alert_repository.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/scripted_live_readings.dart';

class _MockAlerts extends Mock implements AlertRepository {}

class _MockNotifier extends Mock implements AlertNotifier {}

/// The engine: live updates of the connected device against its limits, stored and notified.
void main() {
  final at = DateTime.utc(2026, 10, 20, 9);
  const band = 1;

  late ScriptedLiveReadings live;
  late StreamController<Map<int, List<AlertLimit>>> limits;
  late _MockAlerts alerts;
  late _MockNotifier notifier;
  late LocalAlertEngine engine;

  setUpAll(() => registerFallbackValue(RaisedAlert(deviceId: 0, kind: AlertKind.offline, at: at)));

  setUp(() async {
    live = ScriptedLiveReadings();
    limits = StreamController.broadcast(sync: true);
    alerts = _MockAlerts();
    notifier = _MockNotifier();
    when(() => alerts.add(any())).thenAnswer((_) async => 42);
    when(() => notifier.show(any())).thenAnswer((_) async {});
    engine = LocalAlertEngine(live, (_) => limits.stream, alerts, notifier, now: () => at);
    await engine.start(7);
    limits.add({
      band: const [AlertLimit(key: 'hr', above: 110), AlertLimit(key: 'battery', below: 15)],
    });
  });
  tearDown(() async {
    await engine.stop();
    await limits.close();
  });

  Future<void> send(LiveUpdate update, {int device = band}) async {
    live.all.add((device, update));
    await pumpEventQueue();
  }

  List<RaisedAlert> stored() => verify(() => alerts.add(captureAny())).captured.cast<RaisedAlert>();

  test('a crossing is stored once and passed on with its id', () async {
    await send(LiveValue(Sample('hr', 120, at)));
    await send(LiveValue(Sample('hr', 125, at)));

    final alert = stored().single;
    expect((alert.kind, alert.key, alert.value, alert.limit), (AlertKind.above, 'hr', 120, 110));
    verify(() => notifier.show(alert.copyWith(id: 42))).called(1);
  });

  test('low battery and Offline are raised', () async {
    await send(LiveValue(Sample('battery', 12, at)));
    await send(const LiveHeartbeat(online: false));

    expect(stored().map((a) => a.kind), [AlertKind.batteryLow, AlertKind.offline]);
  });

  test('each 1% battery drop below the limit is stored and notified, stacking', () async {
    var nextId = 1;
    when(() => alerts.add(any())).thenAnswer((_) async => nextId++);

    for (final level in <double>[14, 13, 13, 12]) {
      await send(LiveValue(Sample('battery', level, at)));
    }

    expect(stored().map((a) => a.value), [14, 13, 12]);
    final shown = verify(() => notifier.show(captureAny())).captured.cast<RaisedAlert>();
    expect(shown.map((a) => a.id), [1, 2, 3], reason: 'one notification each');
  });

  test('a limit turned off raises nothing', () async {
    limits.add({
      band: const [AlertLimit(key: 'hr', above: 110, enabled: false)],
    });

    await send(LiveValue(Sample('hr', 150, at)));

    verifyNever(() => alerts.add(any()));
  });

  test('an alert raised, its limit turned off and on: raises again while still over', () async {
    await send(LiveValue(Sample('hr', 150, at)));
    limits.add({
      band: const [AlertLimit(key: 'hr', above: 110, enabled: false)],
    });
    await pumpEventQueue();
    // No reading while it is off: turning it off alone ends the open alert.
    limits.add({
      band: const [AlertLimit(key: 'hr', above: 110)],
    });
    await pumpEventQueue();

    await send(LiveValue(Sample('hr', 151, at)));

    expect(stored().map((a) => (a.kind, a.value)), [
      (AlertKind.above, 150),
      (AlertKind.above, 151),
    ]);
  });

  test('an alert raised and its limit left on: nothing more while still over', () async {
    await send(LiveValue(Sample('hr', 150, at)));
    limits.add({
      band: const [AlertLimit(key: 'hr', above: 110), AlertLimit(key: 'battery', below: 15)],
    });
    await pumpEventQueue();

    await send(LiveValue(Sample('hr', 151, at)));

    expect(stored().map((a) => a.value), [150]);
  });

  test('a limit off from the start, then turned on, raises at once', () async {
    limits.add({
      band: const [AlertLimit(key: 'hr', above: 110, enabled: false)],
    });
    await send(LiveValue(Sample('hr', 150, at)));
    limits.add({
      band: const [AlertLimit(key: 'hr', above: 110)],
    });

    await send(LiveValue(Sample('hr', 151, at)));

    expect(stored().map((a) => (a.kind, a.value)), [(AlertKind.above, 151)]);
  });

  test('a device that is not the user\'s (or was removed) raises nothing', () async {
    await send(LiveValue(Sample('hr', 150, at)), device: 99);

    verifyNever(() => alerts.add(any()));
  });

  test('after stop nothing is raised', () async {
    await engine.stop();

    await send(LiveValue(Sample('hr', 150, at)));

    verifyNever(() => alerts.add(any()));
  });

  test('a failed store does not stop the engine', () async {
    when(() => alerts.add(any())).thenThrow(StateError('disk full'));
    await send(LiveValue(Sample('hr', 150, at)));

    when(() => alerts.add(any())).thenAnswer((_) async => 43);
    await send(const LiveHeartbeat(online: false));

    expect(stored().last.kind, AlertKind.offline);
  });
}
