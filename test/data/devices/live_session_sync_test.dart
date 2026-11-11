import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/devices/live_session.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/decoder/generic_codec.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';

import '../../fixtures/ief_profile.dart';
import '../../fixtures/ppg_motion_link.dart';

/// The IEF patch's `sync` block: set the clock, request logs, collect them until `0x91`.
void main() {
  // Tue 2026‑11‑03 15:45:30 UTC, the protocol doc's Set RTC sample.
  final now = DateTime.utc(2026, 11, 3, 15, 45, 30);
  const setClock = [0x81, 0x09, 0x1E, 0x2D, 0x03, 0x03, 0x0B, 0x1A, 0x02, 0x01, 0x00];

  late ScriptedLink link;
  late List<LiveUpdate> updates;
  late LiveSession session;

  void build() {
    link = ScriptedLink()..answer = (_) => null; // The patch only acknowledges writes.
    updates = [];
    final out = StreamController<LiveUpdate>(sync: true)..stream.listen(updates.add);
    final profile = iefProfile();
    session = LiveSession(profile, link, codecFor(profile, now: () => now), out, now: () => now);
  }

  List<LiveStatus> statuses() => [
    for (final u in updates)
      if (u is LiveStatusChanged) u.status,
  ];

  test('sets the clock, then requests the logs, and stays syncing until 0x91', () async {
    build();
    unawaited(session.start()); // Completes when the sync is over.
    await pumpEventQueue();

    expect(link.sent, [setClock, iefRequestLogs]);
    expect(statuses().last, LiveStatus.syncing);

    link.data(iefLogFrame);
    link.data(iefSyncDone);
    await pumpEventQueue();

    expect(statuses(), [
      LiveStatus.connecting,
      LiveStatus.syncing,
      LiveStatus.starting,
      LiveStatus.streaming,
    ]);
    await session.stop();
  });

  test('log readings keep the time the device measured them', () async {
    build();
    unawaited(session.start());
    await pumpEventQueue();
    link.data(iefLogFrame);
    await pumpEventQueue();

    expect(updates.whereType<LiveValue>().map((v) => v.sample), [Sample('current', 30.07, iefT0)]);
    await session.stop();
  });

  test('log events (START / STOP / ERROR) are passed on with the device time', () async {
    build();
    unawaited(session.start());
    await pumpEventQueue();
    link.data(iefLogFrame);
    await pumpEventQueue();

    final events = updates.whereType<LiveEvent>().map((u) => u.event);
    expect(events.map((e) => (e.kind, e.at)), [
      (DeviceEventKind.error, iefT0.add(const Duration(minutes: 1))),
    ]);
    await session.stop();
  });

  test('gives up waiting 30 s after the last frame, keeping what came', () {
    fakeAsync((async) {
      build();
      unawaited(session.start());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 20));
      link.data(iefLogFrame); // restarts the 30 s
      async.elapse(const Duration(seconds: 29));
      expect(statuses().last, LiveStatus.syncing);

      async.elapse(const Duration(seconds: 2));
      expect(statuses().last, LiveStatus.streaming);
      expect(updates.whereType<LiveValue>(), hasLength(1));
      unawaited(session.stop());
      async.flushMicrotasks();
    });
  });

  test('a device with nothing stored (0x92) ends the sync at once', () async {
    build();
    unawaited(session.start());
    await pumpEventQueue();
    link.data(iefNoData);
    await pumpEventQueue();

    expect(statuses().last, LiveStatus.streaming);
    await session.stop();
  });

  test('syncs again after a dropped connection comes back', () async {
    build();
    unawaited(session.start());
    await pumpEventQueue();
    link.data(iefSyncDone);
    await pumpEventQueue();
    link.sent.clear();

    link
      ..drop()
      ..reconnected();
    await pumpEventQueue();

    expect(link.sent, [setClock, iefRequestLogs]);
    expect(statuses().last, LiveStatus.syncing);
    await session.stop();
  });

  test('while connected, asks for new logs every 60 s without setting the clock again', () {
    fakeAsync((async) {
      build();
      unawaited(session.start());
      async.flushMicrotasks();
      link.data(iefSyncDone);
      async.flushMicrotasks();
      link.sent.clear();

      async.elapse(const Duration(seconds: 59));
      expect(link.sent, isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(link.sent, [iefRequestLogs]);

      link.data(iefLogFrame);
      link.data(iefSyncDone);
      async.elapse(const Duration(seconds: 60));
      expect(link.sent, [iefRequestLogs, iefRequestLogs]);
      unawaited(session.stop());
      async.flushMicrotasks();
    });
  });

  test('does not ask again while the last fetch is still running', () {
    fakeAsync((async) {
      build();
      unawaited(session.start());
      async.flushMicrotasks();
      link.data(iefSyncDone);
      async.flushMicrotasks();
      link.sent.clear();

      async.elapse(const Duration(seconds: 60)); // asks; the device keeps sending
      for (var i = 0; i < 4; i++) {
        async.elapse(const Duration(seconds: 20));
        link.data(iefLogFrame);
      }
      expect(link.sent, [iefRequestLogs]);
      unawaited(session.stop());
      async.flushMicrotasks();
    });
  });

  test('stops asking when the connection drops or the session stops', () {
    fakeAsync((async) {
      build();
      unawaited(session.start());
      async.flushMicrotasks();
      link.data(iefSyncDone);
      async.flushMicrotasks();
      link.sent.clear();

      link.drop();
      async.elapse(const Duration(minutes: 5));
      expect(link.sent, isEmpty);
      unawaited(session.stop());
      async.flushMicrotasks();
    });
  });
}
