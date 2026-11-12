import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/models/device_profile.dart' show batteryKey;
import '../domain/services/live_readings.dart';

export '../domain/services/live_readings.dart';

part 'live_device_provider.freezed.dart';
part 'live_device_provider.g.dart';

/// The latest reading of each key, and how the connection is doing.
@freezed
abstract class LiveDeviceState with _$LiveDeviceState {
  const factory LiveDeviceState({
    @Default(LiveStatus.connecting) LiveStatus status,
    @Default({}) Map<String, double> values,

    /// When each of [values] was measured (the device's time for logged readings).
    @Default({}) Map<String, DateTime> times,

    /// Whether a finger is on the sensor; null for profiles that do not check it.
    SensorContact? contact,

    /// The last problem; cleared once the device is streaming again.
    LiveFailure? failure,

    /// False once the device has missed its profile's number of heartbeats in a row.
    @Default(true) bool online,

    /// When the device was last heard from since it was opened, if it has been.
    DateTime? lastHeartbeatAt,
  }) = _LiveDeviceState;
}

/// Live readings of the saved device [deviceId]. Watching it connects to the device (and
/// disconnects any other); the device stays connected after its screen closes.
@riverpod
class LiveDevice extends _$LiveDevice {
  @override
  LiveDeviceState build(int deviceId) {
    final sub = ref.watch(liveReadingsProvider).watch(deviceId).listen(_on);
    ref.onDispose(sub.cancel);
    return const LiveDeviceState();
  }

  /// Disconnects and connects again from the start (Reconnect). The new connection starts with a
  /// fresh heartbeat, so it counts as online until it misses its heartbeats again.
  Future<void> retry() async {
    state = state.copyWith(failure: null, online: true, status: LiveStatus.connecting);
    await ref.read(liveReadingsProvider).retry(deviceId);
  }

  /// Sends a device action's [steps] to the device (the dashboard's action button). Throws when
  /// the device is not connected, refuses a command or does not answer.
  Future<void> runAction(List<ActionStep> steps) =>
      ref.read(liveReadingsProvider).runAction(deviceId, steps);

  void _on(LiveUpdate update) {
    if (!ref.mounted) return;
    state = switch (update) {
      LiveStatusChanged(:final status) => state.copyWith(
        status: status,
        failure: status == LiveStatus.streaming ? null : state.failure,
      ),
      // A logged entry older than the value already kept (fetched in the same batch) is not newer.
      LiveValue(:final sample) when state.times[sample.key]?.isAfter(sample.at) ?? false => state,
      LiveValue(:final sample) => state.copyWith(
        values: {...state.values, sample.key: sample.value},
        times: {...state.times, sample.key: sample.at},
      ),
      // Without a settled finger the worked-out readings would be noise: keep only the battery.
      LiveContactChanged(:final contact) => state.copyWith(
        contact: contact,
        values: contact == SensorContact.ok
            ? state.values
            : {
                for (final e in state.values.entries)
                  if (e.key == batteryKey) e.key: e.value,
              },
        times: contact == SensorContact.ok
            ? state.times
            : {
                for (final e in state.times.entries)
                  if (e.key == batteryKey) e.key: e.value,
              },
      ),
      LiveFailure() => state.copyWith(failure: update),
      LiveEvent() => state, // Stored; the dashboard reads events from the database.
      LiveHeartbeat(:final online, :final lastAt) => state.copyWith(
        online: online,
        lastHeartbeatAt: lastAt,
      ),
    };
  }
}
