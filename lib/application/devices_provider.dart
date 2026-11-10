import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/services/device_service.dart';
import '../domain/services/live_readings.dart';
import 'auth_controller.dart';

part 'devices_provider.g.dart';

/// The logged-in user's devices in their order; empty when nobody is logged in.
@riverpod
Stream<List<UserDevice>> myDevices(Ref ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(deviceServiceProvider).watchDevices(user.id);
}

/// The device the phone is linked to now (one at a time), or null.
@riverpod
Stream<ActiveLink?> activeLink(Ref ref) => ref.watch(liveReadingsProvider).watchActive();

/// Whether [link] means the device is linked or getting there, rather than waiting to retry.
bool isLinked(ActiveLink? link) => switch (link?.status) {
  null || LiveStatus.waiting => false,
  _ => true,
};

/// The newest stored reading of each key of the saved device [deviceId].
@riverpod
Stream<Map<String, Sample>> latestReadings(Ref ref, int deviceId) =>
    ref.watch(readingRepositoryProvider).watchLatest(deviceId);

/// The current time, e.g. for the home greeting. Tests override it.
@riverpod
DateTime Function() clock(Ref ref) => DateTime.now;

/// The three totals at the top of the home screen.
typedef HomeSummary = ({int devices, int connected, int alerts});

@riverpod
HomeSummary homeSummary(Ref ref) {
  final devices = ref.watch(myDevicesProvider).value ?? const [];
  return (
    devices: devices.length,
    // One device is linked at a time.
    connected: isLinked(ref.watch(activeLinkProvider).value) ? 1 : 0,
    // 0 until the alerts module stores alerts.
    alerts: 0,
  );
}
