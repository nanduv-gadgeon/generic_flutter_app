import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/devices/demo_devices.dart';
import '../domain/devices/demo_history.dart';
import '../domain/models/device_profile.dart';
import '../domain/services/device_service.dart';
import '../domain/services/reading_repository.dart';
import 'device_profiles_provider.dart';
import 'devices_provider.dart';

part 'debug_history_seed.g.dart';

/// The device type the History demo device gets when the config offers it (debug builds only):
/// the PPG + motion sensor, whose day is easiest to read on a chart. Otherwise the first offered
/// type.
const demoHistoryProfileId = 'ppg_motion_v1';

/// Debug builds only (home's hidden long-press on "My devices", with the other test devices): one
/// fake device with a week of made-up
/// readings ([demoHistory]), for trying History without hardware. It is saved like a real device,
/// with a made-up address, so it never connects; its readings are stored like real ones, so the
/// daily summaries are worked out as usual. Release builds never offer this.
class DemoHistorySeed {
  DemoHistorySeed(
    this._devices,
    this._readings,
    this._profile,
    this._name, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DeviceService _devices;
  final ReadingRepository _readings;
  final Future<DeviceProfile> Function() _profile;
  final String Function(String typeLabel) _name;
  final DateTime Function() _now;

  /// Made-up, outside the range of home's test devices (`AA:BB:CC:DD:00:01` on).
  static final address = demoAddress(50);

  /// Readings stored per batch.
  static const batch = 5000;

  /// Whether the device is there.
  Future<bool> isAdded(int userId) => _devices.isAdded(userId, address);

  /// Adds the device with its history, or removes it with its history when it is there. Returns
  /// the new device's id, or null when it was removed.
  Future<int?> toggle(int userId) async {
    if (await _devices.isAdded(userId, address)) {
      await _devices.removeDevice(userId, address);
      return null;
    }
    final profile = await _profile();
    final added = await _devices.addDevice(
      NewDevice(
        userId: userId,
        profileId: profile.id,
        transport: Transport.ble,
        address: address,
        name: _name(profile.label),
      ),
      profile.alerts,
    );
    final stored = [
      for (final r in profile.readings)
        if (r.source == ReadingSource.device) r,
    ];
    final samples = demoHistory(_now(), stored);
    for (var i = 0; i < samples.length; i += batch) {
      final end = i + batch < samples.length ? i + batch : samples.length;
      await _readings.addAll(added.id, samples.sublist(i, end));
    }
    return added.id;
  }
}

/// [DemoHistorySeed] for the app's services and config. [name] comes from the screen's strings.
@riverpod
DemoHistorySeed Function(String Function(String typeLabel) name) demoHistorySeed(Ref ref) {
  final service = ref.watch(deviceServiceProvider);
  final readings = ref.watch(readingRepositoryProvider);
  final clock = ref.watch(clockProvider);
  // Taken now: home reads this provider once without listening.
  final registry = ref.watch(deviceProfileRegistryProvider.future);
  Future<DeviceProfile> profile() async {
    final offered = (await registry).offered;
    return offered.firstWhere((p) => p.id == demoHistoryProfileId, orElse: () => offered.first);
  }

  return (name) => DemoHistorySeed(service, readings, profile, name, now: clock);
}
