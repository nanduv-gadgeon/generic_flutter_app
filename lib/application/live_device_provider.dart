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

    /// Whether a finger is on the sensor; null for profiles that do not check it.
    SensorContact? contact,

    /// The last problem; cleared once the device is streaming again.
    LiveFailure? failure,
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

  /// Disconnects and connects again from the start.
  Future<void> retry() async {
    state = state.copyWith(failure: null);
    await ref.read(liveReadingsProvider).retry(deviceId);
  }

  void _on(LiveUpdate update) {
    if (!ref.mounted) return;
    state = switch (update) {
      LiveStatusChanged(:final status) => state.copyWith(
        status: status,
        failure: status == LiveStatus.streaming ? null : state.failure,
      ),
      LiveValue(:final sample) => state.copyWith(
        values: {...state.values, sample.key: sample.value},
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
      ),
      LiveFailure() => state.copyWith(failure: update),
    };
  }
}
