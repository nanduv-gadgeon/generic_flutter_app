import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/devices/live_session.dart';
import 'package:generic_flutter_app/domain/decoder/generic_codec.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';

import '../../fixtures/ppg_motion_link.dart';
import '../../fixtures/ppg_motion_profile.dart';

/// A profile's `heartbeat.setInterval`: the interval is sent to the device after each connection.
/// The sensor's `led_red` command (takes a value) stands in for a set-interval command.
void main() {
  const setInterval30 = [0xA5, 0xA5, 0x02, 0x0A, 30];

  late ScriptedLink link;
  late List<LiveUpdate> updates;

  LiveSession build(HeartbeatSettings? heartbeat) {
    link = ScriptedLink();
    updates = [];
    final out = StreamController<LiveUpdate>(sync: true)..stream.listen(updates.add);
    final profile = ppgMotionProfile().copyWith(heartbeat: heartbeat);
    return LiveSession(profile, link, codecFor(profile), out);
  }

  test('sends the interval before starting the data', () async {
    final session = build(const HeartbeatSettings(intervalSeconds: 30, setInterval: 'led_red'));
    await session.start();

    expect(link.sent, [setInterval30, stopCommand, channelsCommand, startCommand]);
    expect(updates.whereType<LiveStatusChanged>().last.status, LiveStatus.streaming);
    await session.stop();
  });

  test('sends it again after a reconnect', () async {
    final session = build(const HeartbeatSettings(intervalSeconds: 30, setInterval: 'led_red'));
    await session.start();
    link.sent.clear();

    link
      ..drop()
      ..reconnected();
    await pumpEventQueue();

    expect(link.sent.first, setInterval30);
    await session.stop();
  });

  test('without setInterval nothing extra is sent', () async {
    final session = build(const HeartbeatSettings(intervalSeconds: 30));
    await session.start();

    expect(link.sent, [stopCommand, channelsCommand, startCommand]);
    await session.stop();
  });

  test('a device that does not answer it fails to start', () {
    fakeAsync((async) {
      final session = build(const HeartbeatSettings(setInterval: 'led_red'));
      link.answer = (_) => null;
      unawaited(session.start());
      async.elapse(const Duration(seconds: 10));

      expect(updates.whereType<LiveFailure>().single.reason, LiveFailureReason.startFailed);
      expect(link.sent.every((c) => c[3] == 0x0A), isTrue); // Streaming never started.
      unawaited(session.stop());
      async.flushMicrotasks();
    });
  });
}
