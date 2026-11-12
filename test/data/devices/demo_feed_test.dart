import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/devices/demo_feed.dart';
import 'package:generic_flutter_app/domain/dashboard/reading_status.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';

import '../../fixtures/dashboard_harness.dart';

final _t0 = DateTime.utc(2026, 11, 11, 9);

/// [seconds] of demo data for [id], by second.
List<List<LiveUpdate>> _run(String id, int seconds) {
  final feed = DemoFeed(vitaCareRegistry.byId(id), random: math.Random(1));
  return [for (var t = 0; t < seconds; t++) feed.second(_t0.add(Duration(seconds: t)))];
}

Iterable<Sample> _samples(List<List<LiveUpdate>> run) =>
    run.expand((u) => u).whereType<LiveValue>().map((v) => v.sample);

void main() {
  for (final profile in vitaCareRegistry.offered) {
    test('${profile.id}: every value stays on its scale, rounded to its decimals', () {
      for (final sample in _samples(_run(profile.id, 700))) {
        if (sample.key == batteryKey) {
          expect(sample.value, inInclusiveRange(5, 100));
          continue;
        }
        final reading = profile.readingFor(sample.key)!;
        if (scaleOf(reading) case final scale? when reading.goal == null) {
          expect(sample.value, inInclusiveRange(scale.low, scale.high), reason: sample.key);
        }
        final f = math.pow(10, reading.decimals);
        expect((sample.value * f).roundToDouble(), closeTo(sample.value * f, 1e-6));
      }
    });
  }

  test('values wander around the normal range, sometimes outside it', () {
    final hr = _samples(_run('smart_band_v1', 600)).where((s) => s.key == 'hr').toList();
    expect(hr, hasLength(600));
    final inRange = hr.where((s) => s.value >= 60 && s.value <= 100).length;
    expect(inRange, greaterThan(500));
    expect(inRange, lessThan(600));
  });

  test('a pair is sent with its reading', () {
    final first = _run('health_kit_v1', 1).single.whereType<LiveValue>().map((v) => v.sample.key);
    expect(first, containsAll(['bp', 'bp_dia']));
  });

  test('goals grow from 60 % to 90 %', () {
    final steps = _samples(_run('smart_band_v1', 700)).where((s) => s.key == 'steps');
    expect(steps.first.value, 6000);
    expect(steps.last.value, 9000);
  });

  test('zones: one value a minute, in each zone in turn', () {
    final temps = _samples(_run('thermometer_v1', 181)).where((s) => s.key == 'temp').toList();
    final reading = vitaCareRegistry.byId('thermometer_v1').readingFor('temp')!;
    expect(temps, hasLength(4));
    expect(
      [for (final s in temps) zoneOf(reading, s.value)!.label],
      ['Normal', 'High', 'Fever', 'Normal'],
    );
  });

  test('coded readings send their good state once', () {
    final run = _run('ecg_monitor_v1', 5);
    final signal = _samples(run).where((s) => s.key == 'signal').toList();
    expect(signal.map((s) => s.value), [2]);
    expect(_samples(run).where((s) => s.key == 'ecg'), isEmpty);
  });

  test('battery and a heartbeat every 5 s', () {
    final run = _run('ppg_motion_v1', 11);
    expect(_samples(run).where((s) => s.key == batteryKey), hasLength(3));
    expect(run.expand((u) => u).whereType<LiveHeartbeat>(), hasLength(3));
  });

  test('event readings: a session starts, stops after 90 s, and errors are logged', () {
    final events = _run('ief_device_v1', 181).expand((u) => u).whereType<LiveEvent>();
    expect(
      [for (final e in events) (e.event.kind, e.event.at.difference(_t0).inSeconds)],
      [
        (DeviceEventKind.start, 0),
        (DeviceEventKind.error, 60),
        (DeviceEventKind.stop, 90),
        (DeviceEventKind.start, 180),
        (DeviceEventKind.error, 180),
      ],
    );
    final current = _samples(_run('ief_device_v1', 1)).map((s) => s.key);
    expect(current, isNot(contains('sessions')));
  });

  test('profiles without event readings log no events', () {
    expect(_run('smart_band_v1', 200).expand((u) => u).whereType<LiveEvent>(), isEmpty);
  });

  test('a hub leaves one channel silent, so it shows No signal', () {
    final hub = vitaCareRegistry.byId('sensor_hub_v1');
    final sent = _samples(_run('sensor_hub_v1', 3)).map((s) => s.key).toSet();
    final silent = [
      for (final r in hub.readings)
        if (!sent.contains(r.key)) r.key,
    ];
    expect(silent, hasLength(1));
  });

  test('the wave has a beat and stays in range', () {
    final feed = DemoFeed(vitaCareRegistry.byId('ecg_monitor_v1'), random: math.Random(1));
    final samples = feed.wave(250, 250);
    expect(samples, hasLength(250));
    expect(samples.reduce(math.max), greaterThan(0.8));
    expect(samples.every((v) => v > -0.5 && v < 1.2), isTrue);
  });
}
