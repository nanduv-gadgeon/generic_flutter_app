import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/devices/link_state.dart';
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

/// How the saved device [deviceId] looks on home, given the phone's one active [link]: any other
/// device is Offline.
LinkState linkStateFor(ActiveLink? link, int deviceId) => link == null || link.deviceId != deviceId
    ? LinkState.offline
    : linkStateOf(link.status, online: link.online);

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
    // One device is linked at a time; Connecting and Reconnecting do not count yet.
    connected: switch (ref.watch(activeLinkProvider).value) {
      final link? when linkStateFor(link, link.deviceId) == LinkState.connected => 1,
      _ => 0,
    },
    // 0 until the alerts module stores alerts.
    alerts: 0,
  );
}

/// Saves a new order of the logged-in user's devices (Reorder on home): device ids, first to
/// last. Does nothing when nobody is logged in.
@riverpod
Future<void> Function(List<int> orderedIds) saveDeviceOrder(Ref ref) {
  final user = ref.watch(authControllerProvider).value;
  final service = ref.watch(deviceServiceProvider);
  return (orderedIds) async {
    if (user != null) await service.reorder(user.id, orderedIds);
  };
}

/// Removes one of the logged-in user's devices: its readings and alert limits are deleted, it is
/// disconnected and unpaired (Swipe to delete on home).
@riverpod
Future<void> Function(int deviceId) removeDevice(Ref ref) {
  final user = ref.watch(authControllerProvider).value;
  final service = ref.watch(deviceServiceProvider);
  return (deviceId) async {
    if (user != null) await service.removeById(user.id, deviceId);
  };
}
