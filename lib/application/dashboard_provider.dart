import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/dashboard/event_summary.dart';
import '../domain/decoder/decoded_packet.dart';
import '../domain/models/device_profile.dart';
import 'devices_provider.dart';
import 'live_device_provider.dart';

export '../domain/dashboard/event_summary.dart';

part 'dashboard_provider.g.dart';

/// How far back a gauge's trend line goes.
const trendWindow = Duration(minutes: 30);

/// The start of the local day that [now] is in.
DateTime startOfDay(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// The time now, once a second, so "updated 2 s ago" and today's run time keep up.
@riverpod
Stream<DateTime> dashboardNow(Ref ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => clock());
}

/// The device's [key] readings from the last 30 minutes, oldest first.
@riverpod
Stream<List<Sample>> readingTrend(Ref ref, int deviceId, String key) => ref
    .watch(readingRepositoryProvider)
    .watchRange(deviceId, key, ref.watch(clockProvider)().subtract(trendWindow));

/// The device's [key] readings measured today, oldest first.
@riverpod
Stream<List<Sample>> todayReadings(Ref ref, int deviceId, String key) => ref
    .watch(readingRepositoryProvider)
    .watchRange(deviceId, key, startOfDay(ref.watch(clockProvider)()));

/// The device's events since the start of yesterday: a session started before midnight may still
/// be running.
@riverpod
Stream<List<DeviceEvent>> recentEvents(Ref ref, int deviceId) => ref
    .watch(deviceEventRepositoryProvider)
    .watchSince(deviceId, startOfDay(ref.watch(clockProvider)()).subtract(const Duration(days: 1)));

/// Today's sessions, run time, errors and state of the device, from its stored events. Worked out
/// again whenever an event is stored, and at midnight for the new day.
@riverpod
EventSummary eventSummary(Ref ref, int deviceId) {
  final events = ref.watch(recentEventsProvider(deviceId)).value;
  if (events == null) return EventSummary.empty;
  final now = ref.watch(dashboardNowProvider).value ?? ref.watch(clockProvider)();
  return summarise(events, dayStart: startOfDay(now));
}

/// Whether [profile]'s readings come from logs the app fetches now and then (a `sync` block, e.g.
/// the therapy device), not from a stream. Its newest stored reading stays the latest one between
/// fetches, so the dashboard keeps showing it while connected.
bool readsLogs(DeviceProfile profile) => profile.sync != null;

/// The latest value of each reading of [profile] the dashboard shows:
/// - a streaming device (e.g. the PPG sensor): live values while it streams, so an old value never
///   looks live; otherwise the newest stored ones, so the screen is not empty while connecting or
///   Offline;
/// - a device that [readsLogs]: always the newest of the stored and live values, by the time each
///   was measured, as a fetch brings several entries at once and nothing between fetches;
/// - readings worked out from events, from [summary].
Map<String, double> dashboardValues(
  DeviceProfile profile,
  LiveDeviceState live,
  Map<String, Sample> stored,
  EventSummary summary,
) => {
  for (final MapEntry(:key, value: (value, _)) in _latest(profile, live, stored).entries)
    key: value,
  if (summary.hasEvents)
    for (final reading in profile.readings) reading.key: ?summary.valueFor(reading.source),
};

/// When each value of [dashboardValues] (other than those worked out from events) was measured,
/// where that is known.
Map<String, DateTime> dashboardTimes(
  DeviceProfile profile,
  LiveDeviceState live,
  Map<String, Sample> stored,
) => {
  for (final MapEntry(:key, value: (_, at)) in _latest(profile, live, stored).entries) key: ?at,
};

Map<String, (double, DateTime?)> _latest(
  DeviceProfile profile,
  LiveDeviceState live,
  Map<String, Sample> stored,
) {
  final streaming = live.status == LiveStatus.streaming && live.online;
  final logs = readsLogs(profile);
  final latest = <String, (double, DateTime?)>{
    if (!streaming || logs)
      for (final MapEntry(:key, value: sample) in stored.entries) key: (sample.value, sample.at),
  };
  for (final MapEntry(:key, :value) in live.values.entries) {
    final at = live.times[key];
    final kept = latest[key]?.$2;
    // A live value older than the stored one (an earlier entry of the same fetch) does not win.
    if (logs && at != null && kept != null && at.isBefore(kept)) continue;
    latest[key] = (value, at);
  }
  return latest;
}

/// The last [capacity] of the device's [key] samples, for a waveform, oldest first. Sampled many
/// times a second, so the screen gets a new copy at most every [frame].
@riverpod
class Waveform extends _$Waveform {
  static const frame = Duration(milliseconds: 40);

  final _buffer = <double>[];
  Timer? _timer;
  bool _dirty = false;

  @override
  List<double> build(int deviceId, String key, int capacity) {
    final sub = ref.watch(liveReadingsProvider).watch(deviceId).listen((update) {
      if (update is LiveValue && update.sample.key == key) _add(update.sample.value);
    });
    _timer = Timer.periodic(frame, (_) => _publish());
    ref.onDispose(() {
      sub.cancel();
      _timer?.cancel();
    });
    return const [];
  }

  void _add(double value) {
    _buffer.add(value);
    if (_buffer.length > capacity) _buffer.removeRange(0, _buffer.length - capacity);
    _dirty = true;
  }

  void _publish() {
    if (!_dirty || !ref.mounted) return;
    _dirty = false;
    state = List.unmodifiable(_buffer);
  }
}
