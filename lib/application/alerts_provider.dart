import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/alerts.dart';
import '../domain/models/device_profile.dart';
import '../domain/services/alert_repository.dart';
import 'auth_controller.dart';
import 'device_profiles_provider.dart';
import 'devices_provider.dart';

part 'alerts_provider.g.dart';

/// One card of the Alerts list: the stored alert and what its words need from its device. The
/// text is made where it is shown. [alert] holds health values: never log it.
typedef AlertListItem = ({
  RaisedAlert alert,
  String deviceName,

  /// The alert's reading in the device's profile (label, unit, decimals, icon); null for offline,
  /// for the battery when the profile has no battery reading, or an unknown device type.
  Reading? reading,

  /// The profile's number of missed heartbeats before Offline.
  int offlineAfterMissed,
});

/// The logged-in user's alerts, newest first; empty when nobody is logged in. An alert whose
/// device is no longer in the user's list is left out.
@riverpod
Stream<List<AlertListItem>> alertList(Ref ref) async* {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) {
    yield const [];
    return;
  }
  final profiles = await ref.watch(deviceProfileRegistryProvider.future);
  final devices = {for (final d in await ref.watch(myDevicesProvider.future)) d.id: d};
  yield* ref.watch(alertRepositoryProvider).watchAll(user.id).map((alerts) {
    return [
      for (final alert in alerts)
        if (devices[alert.deviceId] case final device?)
          _item(
            alert,
            device.name,
            profiles.contains(device.profileId) ? profiles.byId(device.profileId) : null,
          ),
    ];
  });
}

AlertListItem _item(RaisedAlert alert, String deviceName, DeviceProfile? profile) => (
  alert: alert,
  deviceName: deviceName,
  reading: alert.key == null ? null : profile?.readingFor(alert.key!),
  offlineAfterMissed: (profile?.heartbeatOrDefault ?? const HeartbeatSettings()).offlineAfterMissed,
);

/// Marks all of the logged-in user's alerts read (Alerts list, "Mark all read"). Does nothing
/// when nobody is logged in.
@riverpod
Future<void> Function() markAllAlertsRead(Ref ref) {
  final user = ref.watch(authControllerProvider).value;
  final repository = ref.watch(alertRepositoryProvider);
  return () async {
    if (user != null) await repository.markAllRead(user.id);
  };
}

/// The time now, and again every minute, so "10 min ago" stays true while a screen is open.
@riverpod
Stream<DateTime> minuteTick(Ref ref) async* {
  final now = ref.watch(clockProvider);
  yield now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => now());
}
