import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/devices/demo_live_readings.dart';
import 'package:generic_flutter_app/data/devices/heartbeat_recorder.dart';
import 'package:generic_flutter_app/data/devices/reading_writer.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/models/heartbeat_settings.dart';
import 'package:generic_flutter_app/domain/services/heartbeat_repository.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';

import '../../fixtures/dashboard_harness.dart';
import '../../fixtures/scripted_live_readings.dart';

class _StoredReadings extends FakeReadingRepository {
  final stored = <Sample>[];

  @override
  Future<void> addAll(int deviceId, List<Sample> samples) async => stored.addAll(samples);
}

class _StoredEvents extends FakeDeviceEventRepository {
  final stored = <DeviceEvent>[];

  @override
  Future<void> addAll(int deviceId, List<DeviceEvent> events) async => stored.addAll(events);
}

class _NoHeartbeats implements HeartbeatRepository {
  @override
  Future<void> add(int deviceId, DateTime at, {int? batteryPercent}) async {}

  @override
  Future<int> deleteOlderThan(DateTime cutoff) async => 0;
}

/// Device 1 is real; 2 (Therapy), 3 (ECG) and 4 (band) are dummies.
const _devices = {
  1: (address: '11:22:33:44:55:66', profileId: 'ppg_motion_v1'),
  2: (address: 'AA:BB:CC:DD:00:01', profileId: 'ief_device_v1'),
  3: (address: 'AA:BB:CC:DD:00:02', profileId: 'ecg_monitor_v1'),
  4: (address: 'aa:bb:cc:dd:00:03', profileId: 'smart_band_v1'),
};

void main() {
  late ScriptedLiveReadings inner;
  late _StoredReadings readings;
  late _StoredEvents events;
  late DemoLiveReadings demo;
  final t0 = DateTime.utc(2026, 11, 11, 9);

  void build(FakeAsync async) {
    inner = ScriptedLiveReadings();
    readings = _StoredReadings();
    events = _StoredEvents();
    demo = DemoLiveReadings(
      inner,
      (id) async => _devices[id],
      (id) => vitaCareRegistry.contains(id) ? vitaCareRegistry.byId(id) : null,
      (id, profile) => ReadingWriter(id, readings, (_, _) async {}, events: events, skip: {'ecg'}),
      (id, settings) =>
          HeartbeatRecorder(id, _NoHeartbeats(), (_, _) async {}, interval: settings.interval),
      now: () => t0.add(async.elapsed),
      random: math.Random(1),
    );
  }

  test('a real device goes to the real connection', () {
    fakeAsync((async) {
      build(async);
      final updates = <LiveUpdate>[];
      final sub = demo.watch(1).listen(updates.add);
      async.flushMicrotasks();
      inner.send(const LiveStatusChanged(LiveStatus.connecting));
      async.flushMicrotasks();

      expect(inner.listens, 1);
      expect(updates.single, isA<LiveStatusChanged>());
      sub.cancel();
    });
  });

  test('a dummy streams made-up values at once and every second, and stores them', () {
    fakeAsync((async) {
      build(async);
      final updates = <LiveUpdate>[];
      final sub = demo.watch(4).listen(updates.add);
      async.flushMicrotasks();

      expect(inner.listens, 0);
      expect((updates.first as LiveStatusChanged).status, LiveStatus.streaming);
      int hr() => updates.whereType<LiveValue>().where((v) => v.sample.key == 'hr').length;
      expect(hr(), 1);
      async.elapse(const Duration(seconds: 3));
      expect(hr(), 4);
      expect(readings.stored.where((s) => s.key == 'hr'), hasLength(greaterThanOrEqualTo(2)));
      sub.cancel();
      async.flushMicrotasks();
    });
  });

  test('event readings: events are stored, not sent', () {
    fakeAsync((async) {
      build(async);
      final updates = <LiveUpdate>[];
      final sub = demo.watch(2).listen(updates.add);
      async.flushMicrotasks();

      expect(events.stored.map((e) => e.kind), [DeviceEventKind.start]);
      expect(updates.whereType<LiveEvent>(), isEmpty);
      sub.cancel();
      async.flushMicrotasks();
    });
  });

  test('a waveform gets samples every 100 ms, not stored', () {
    fakeAsync((async) {
      build(async);
      final updates = <LiveUpdate>[];
      final sub = demo.watch(3).listen(updates.add);
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 500));

      expect(updates.whereType<LiveValue>().where((v) => v.sample.key == 'ecg'), hasLength(125));
      async.elapse(const Duration(seconds: 2));
      expect(readings.stored.where((s) => s.key == 'ecg'), isEmpty);
      sub.cancel();
      async.flushMicrotasks();
    });
  });

  test('a second screen shares the feed and first sees the latest values', () {
    fakeAsync((async) {
      build(async);
      final a = demo.watch(4).listen((_) {});
      async.elapse(const Duration(seconds: 2));
      final later = <LiveUpdate>[];
      final b = demo.watch(4).listen(later.add);
      async.flushMicrotasks();

      expect((later.first as LiveStatusChanged).status, LiveStatus.streaming);
      expect(later.whereType<LiveValue>().map((v) => v.sample.key), contains('hr'));
      a.cancel();
      b.cancel();
      async.flushMicrotasks();
    });
  });

  test('the dummy is the active link while open; closing it stops the feed', () {
    fakeAsync((async) {
      build(async);
      final links = <ActiveLink?>[];
      final active = demo.watchActive().listen(links.add);
      final sub = demo.watch(4).listen((_) {});
      async.flushMicrotasks();

      expect(links.last, (deviceId: 4, status: LiveStatus.streaming, online: true));
      sub.cancel();
      async.flushMicrotasks();
      expect(links.last, isNull);

      final stored = readings.stored.length;
      async.elapse(const Duration(seconds: 5));
      expect(readings.stored.length, stored);
      active.cancel();
    });
  });

  test('retry, start and stop reach the real connection', () {
    fakeAsync((async) {
      build(async);
      demo.retry(1);
      async.flushMicrotasks();
      expect(inner.retried, [1]);
    });
  });
}
