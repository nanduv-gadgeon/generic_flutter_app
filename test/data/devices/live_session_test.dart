import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/devices/live_session.dart';
import 'package:generic_flutter_app/domain/decoder/generic_codec.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';

import '../../fixtures/ppg_motion_link.dart';
import '../../fixtures/ppg_motion_profile.dart';

void main() {
  late ScriptedLink link;
  late StreamController<LiveUpdate> out;
  late List<LiveUpdate> updates;
  late LiveSession session;
  late DateTime now;

  setUp(() {
    link = ScriptedLink();
    out = StreamController(sync: true);
    updates = [];
    out.stream.listen(updates.add);
    now = DateTime.utc(2026, 11, 3, 9);
    final profile = ppgMotionProfile();
    session = LiveSession(profile, link, codecFor(profile), out, now: () => now);
  });
  tearDown(() => out.close());

  List<LiveStatus> statuses() => [
    for (final u in updates)
      if (u is LiveStatusChanged) u.status,
  ];
  List<String> keys() => [
    for (final u in updates)
      if (u is LiveValue) u.sample.key,
  ];
  List<LiveFailure> failures() => updates.whereType<LiveFailure>().toList();

  /// [seconds] of 1.2 Hz pulse frames, 100 ms of samples each, moving the clock on.
  Future<void> stream(int seconds, {double irLevel = 300000}) async {
    for (var f = 0; f < seconds * 10; f++) {
      double wave(int i) => math.sin(2 * math.pi * 1.2 * (f * 10 + i) / 100);
      link.data(ppgFrame((i) => 200000 + 2000 * wave(i), (i) => irLevel + 6000 * wave(i)));
      now = now.add(const Duration(milliseconds: 100));
      await pumpEventQueue();
    }
  }

  test('connects, stops the device, sets channels 1 and 5, then starts it', () async {
    await session.start();

    expect(link.sent, [stopCommand, channelsCommand, startCommand]);
    expect(statuses(), [LiveStatus.connecting, LiveStatus.starting, LiveStatus.streaming]);
    expect(failures(), isEmpty);
  });

  test('passes on the profile readings and battery, never the raw PPG', () async {
    await session.start();
    link.sendBattery(81);
    await stream(10);

    expect(keys().toSet(), {'battery', 'spo2', 'heart_rate', 'pi_red', 'pi_ir'});
    expect(keys().where((k) => k == 'pi_ir'), hasLength(10)); // once a second
  });

  test('a failed connect is reported and nothing is sent', () async {
    link.failConnect = true;
    await session.start();

    expect(failures().single.reason, LiveFailureReason.connectFailed);
    expect(link.sent, isEmpty);
  });

  final startProblems = <String, (int, DeviceProblem)>{
    'low battery': (0x04, DeviceProblem.lowBattery),
    'on the charger': (0x05, DeviceProblem.charging),
    'sensor not responding': (0x03, DeviceProblem.sensorError),
  };
  for (final MapEntry(key: name, value: (code, problem)) in startProblems.entries) {
    test('Start answered with "$name" says why', () async {
      link.answer = (c) =>
          c[3] == 0x20 && c[4] == 0x01 ? [0x5A, 0x5A, 0x02, 0x20, code] : sensorAnswer(c);
      await session.start();

      final failure = failures().single;
      expect((failure.reason, failure.problem), (LiveFailureReason.startFailed, problem));
      expect(statuses(), isNot(contains(LiveStatus.streaming)));
    });
  }

  test('a problem reported while streaming is passed on', () async {
    await session.start();
    link.reply([0x5A, 0x5A, 0x02, 0xCE, 0xF4]);
    await pumpEventQueue();

    final failure = failures().single;
    expect(
      (failure.reason, failure.problem),
      (LiveFailureReason.deviceProblem, DeviceProblem.transferError),
    );
  });

  test('stop stops the device, then disconnects', () async {
    await session.start();
    link.sent.clear();
    await session.stop();

    expect(link.sent, [stopCommand]);
    expect(link.disconnected, isTrue);
  });

  test('stop before streaming only disconnects', () async {
    link.failConnect = true;
    await session.start();
    await session.stop();

    expect(link.sent, isEmpty);
    expect(link.disconnected, isTrue);
  });

  test('after a dropped link, starts the device again', () async {
    await session.start();
    link.sent.clear();
    link.drop();
    link.reconnected();
    await pumpEventQueue();

    expect(statuses().skip(3), [
      LiveStatus.reconnecting,
      LiveStatus.starting,
      LiveStatus.streaming,
    ]);
    expect(link.sent, [stopCommand, channelsCommand, startCommand]);
  });

  test('AGC lowers the IR, then the red LED when the signal stays too bright', () async {
    await session.start();
    link.sent.clear();
    await stream(3, irLevel: 450000);

    expect(link.sent.take(2), [
      [0xA5, 0xA5, 0x02, 0x0E, 0x04],
      [0xA5, 0xA5, 0x02, 0x0A, 0x04],
    ]);
  });

  test('AGC leaves a signal in range alone', () async {
    await session.start();
    link.sent.clear();
    await stream(3);

    expect(link.sent, isEmpty);
  });
}
