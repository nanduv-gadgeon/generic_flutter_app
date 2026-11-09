import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/services/device_service.dart';
import 'auth_controller.dart';

part 'devices_provider.g.dart';

/// The logged-in user's devices in their order; empty when nobody is logged in.
@riverpod
Stream<List<UserDevice>> myDevices(Ref ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(deviceServiceProvider).watchDevices(user.id);
}

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
    // 0 until Module 2 provides each device's connection state.
    connected: 0,
    // 0 until the alerts module stores alerts.
    alerts: 0,
  );
}
