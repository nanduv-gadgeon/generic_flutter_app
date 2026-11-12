import 'dart:math' as math;

import '../../domain/dashboard/reading_status.dart';
import '../../domain/decoder/decoded_packet.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/services/live_readings.dart';

/// Debug builds only: made-up readings for a dummy device, worked out from its profile alone, so
/// every dashboard can be tried without hardware. Nothing here is real data.
///
/// Each [second] gives one second of data:
/// - readings with a normal range wander around its middle, now and then just outside it;
/// - goals grow from 60 % to 90 % of the goal over ten minutes;
/// - readings with zones send one value a minute, landing in each zone in turn;
/// - coded readings send their first good state once;
/// - battery and a heartbeat every 5 s;
/// - for profiles with event readings: a session starts, stops after 90 s, starts again, and an
///   error is logged every 2 minutes;
/// - on hubs (12 or more ranged readings) one channel never sends, so it shows No signal.
///
/// [wave] gives samples of a made-up ECG-like trace for waveform readings.
class DemoFeed {
  DemoFeed(this.profile, {math.Random? random}) : _random = random ?? math.Random() {
    final waves = {
      for (final v in profile.dashboard?.views ?? const <DashboardView>[])
        if (v.type == DashboardViewType.waveform) ?v.reading,
    };
    final ranged = profile.readings.where((r) => r.normal != null).toList();
    final silent = ranged.length >= 12 ? ranged[ranged.length * 7 ~/ 8].key : null;
    final paired = {for (final r in profile.readings) ?r.pair};
    _sent = [
      for (final r in profile.readings)
        if (!waves.contains(r.key) &&
            r.source == ReadingSource.device &&
            r.key != silent &&
            !paired.contains(r.key))
          r,
    ];
    _hasEvents = profile.readings.any((r) => r.source != ReadingSource.device);
  }

  final DeviceProfile profile;
  final math.Random _random;
  late final List<Reading> _sent;
  late final bool _hasEvents;
  final _values = <String, double>{};
  int _tick = 0;
  bool _running = false;
  double _battery = 86;
  double _phase = 0;

  /// One second of updates at [now].
  List<LiveUpdate> second(DateTime now) {
    final t = _tick++;
    final updates = <LiveUpdate>[];
    void send(String key, double value) => updates.add(LiveValue(Sample(key, value, now)));

    for (final reading in _sent) {
      final value = _next(reading, t);
      if (value == null) continue;
      send(reading.key, value);
      if (reading.pair case final pair?) send(pair, (value * 0.65).roundToDouble());
    }
    if (t % 5 == 0) {
      if (t > 0 && t % 60 == 0) _battery = math.max(5, _battery - 1);
      send(batteryKey, _battery);
      updates.add(LiveHeartbeat(online: true, lastAt: now));
    }
    if (_hasEvents) updates.addAll(_events(t, now));
    return updates;
  }

  /// The next [count] samples of a trace beating 72 times a minute at [sampleHz].
  List<double> wave(int count, int sampleHz) {
    final step = 72 / 60 / sampleHz;
    double bump(double x, double centre, double width, double height) =>
        height * math.exp(-math.pow((x - centre) / width, 2));
    return [
      for (var i = 0; i < count; i++)
        () {
          _phase = (_phase + step) % 1;
          final x = _phase;
          final noise = (_random.nextDouble() - 0.5) * 0.02;
          return bump(x, 0.18, 0.03, 0.12) -
              bump(x, 0.30, 0.008, 0.15) +
              bump(x, 0.33, 0.012, 1.0) -
              bump(x, 0.36, 0.01, 0.25) +
              bump(x, 0.58, 0.05, 0.22) +
              noise;
        }(),
    ];
  }

  double? _next(Reading reading, int t) {
    if (reading.zones.isNotEmpty) return t % 60 == 0 ? _zoneValue(reading, t ~/ 60) : null;
    if (reading.states.isNotEmpty) {
      if (t > 0) return null;
      final good = reading.states.entries.where((e) => e.value.kind == StatusKind.ok);
      return double.tryParse((good.firstOrNull ?? reading.states.entries.first).key);
    }
    if (reading.goal case final goal?) {
      return _round(reading, goal * (0.6 + 0.3 * math.min(1, t / 600)));
    }
    final normal = reading.normal ?? const NormalRange(low: 40, high: 60);
    final scale = scaleOf(reading) ?? NormalRange(low: 0, high: normal.high * 2);
    final span = math.max(normal.high - normal.low, (scale.high - scale.low) * 0.1);
    final mid = (normal.low + normal.high) / 2;
    var v = _values[reading.key] ?? mid;
    v += (_random.nextDouble() - 0.5) * span * 0.08 + (mid - v) * 0.1;
    // Now and then just outside the range, so High and Low show too.
    if (_random.nextDouble() < 0.02) {
      v = _random.nextBool() ? normal.high + span * 0.15 : normal.low - span * 0.15;
    }
    v = v.clamp(scale.low, scale.high);
    _values[reading.key] = v;
    return _round(reading, v);
  }

  double _zoneValue(Reading reading, int n) {
    final scale = reading.scale ?? const NormalRange(low: 0, high: 100);
    final zone = n % reading.zones.length;
    final low = zone == 0 ? scale.low : reading.zones[zone - 1].below!;
    final high = reading.zones[zone].below ?? scale.high;
    return _round(reading, low + (high - low) * (0.3 + 0.4 * _random.nextDouble()));
  }

  List<LiveUpdate> _events(int t, DateTime now) {
    final events = <DeviceEvent>[];
    if (t % 90 == 0) {
      _running = !_running;
      events.add(
        DeviceEvent(_running ? DeviceEventKind.start : DeviceEventKind.stop, now, code: 0),
      );
    }
    if (t % 120 == 60) events.add(DeviceEvent(DeviceEventKind.error, now, code: 0x21));
    return [for (final e in events) LiveEvent(e)];
  }

  static double _round(Reading reading, double v) {
    final f = math.pow(10, reading.decimals);
    return (v * f).round() / f;
  }
}
