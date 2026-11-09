import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
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

    /// The last problem; cleared once the device is streaming again.
    LiveFailure? failure,
  }) = _LiveDeviceState;
}

/// Live readings of the saved device [deviceId]. Watching it connects to the device; it
/// disconnects when nothing watches it any more, e.g. when its screen closes.
@riverpod
class LiveDevice extends _$LiveDevice {
  @override
  LiveDeviceState build(int deviceId) {
    final sub = ref.watch(liveReadingsProvider).watch(deviceId).listen(_on);
    ref.onDispose(sub.cancel);
    return const LiveDeviceState();
  }

  /// Disconnects and connects again from the start.
  void retry() => ref.invalidateSelf();

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
      LiveFailure() => state.copyWith(failure: update),
    };
  }
}
