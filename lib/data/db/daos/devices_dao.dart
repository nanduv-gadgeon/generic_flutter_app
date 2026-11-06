import 'package:drift/drift.dart';

import '../app_database.dart';

part 'devices_dao.g.dart';

@DriftAccessor(tables: [Devices, DeviceAlerts])
class DevicesDao extends DatabaseAccessor<AppDatabase> with _$DevicesDaoMixin {
  DevicesDao(super.attachedDatabase);

  /// The user's devices in their chosen order.
  Stream<List<Device>> watchForUser(int userId) =>
      (select(devices)
            ..where((d) => d.userId.equals(userId))
            ..orderBy([(d) => OrderingTerm.asc(d.sortOrder)]))
          .watch();

  /// Adds a device at the end of the user's list and returns its id.
  Future<int> addDevice(DevicesCompanion device) => addDeviceWithAlerts(device, const []);

  /// Adds a device at the end of the user's list together with its alert limits, all or nothing,
  /// and returns its id. [alerts] need no `deviceId`; it is filled in here.
  Future<int> addDeviceWithAlerts(DevicesCompanion device, List<DeviceAlertsCompanion> alerts) =>
      transaction(() async {
        final userId = device.userId.value;
        final maxOrder = devices.sortOrder.max();
        final last =
            await (selectOnly(devices)
                  ..addColumns([maxOrder])
                  ..where(devices.userId.equals(userId)))
                .map((row) => row.read(maxOrder))
                .getSingle();
        final id = await into(devices).insert(device.copyWith(sortOrder: Value((last ?? -1) + 1)));
        await _insertAlerts(id, alerts);
        return id;
      });

  /// Whether the user already has a device at [address].
  Future<bool> existsForUser(int userId, String address) async {
    final count = devices.id.count();
    final found =
        await (selectOnly(devices)
              ..addColumns([count])
              ..where(devices.userId.equals(userId) & devices.address.equals(address)))
            .map((row) => row.read(count))
            .getSingle();
    return (found ?? 0) > 0;
  }

  /// Phase 2: stores the key the cloud gave the device.
  Future<void> setDeviceKey(int id, String key) => (update(
    devices,
  )..where((d) => d.id.equals(id))).write(DevicesCompanion(deviceKey: Value(key)));

  /// The device's alert limits, in reading-key order.
  Future<List<DeviceAlert>> alertsFor(int deviceId) =>
      (select(deviceAlerts)
            ..where((a) => a.deviceId.equals(deviceId))
            ..orderBy([(a) => OrderingTerm.asc(a.readingKey)]))
          .get();

  /// Replaces all of the device's alert limits, all or nothing.
  Future<void> replaceAlerts(int deviceId, List<DeviceAlertsCompanion> alerts) =>
      transaction(() async {
        await (delete(deviceAlerts)..where((a) => a.deviceId.equals(deviceId))).go();
        await _insertAlerts(deviceId, alerts);
      });

  Future<void> _insertAlerts(int deviceId, List<DeviceAlertsCompanion> alerts) => batch(
    (b) => b.insertAll(deviceAlerts, [
      for (final alert in alerts) alert.copyWith(deviceId: Value(deviceId)),
    ]),
  );

  Future<void> rename(int id, String name) =>
      (update(devices)..where((d) => d.id.equals(id))).write(DevicesCompanion(name: Value(name)));

  /// Saves the latest status from the device. Only the values given are changed.
  Future<void> updateStatus(
    int id, {
    int? batteryPercent,
    String? firmware,
    DateTime? lastHeartbeatAt,
  }) => (update(devices)..where((d) => d.id.equals(id))).write(
    DevicesCompanion(
      batteryPercent: Value.absentIfNull(batteryPercent),
      firmware: Value.absentIfNull(firmware),
      lastHeartbeatAt: Value.absentIfNull(lastHeartbeatAt),
    ),
  );

  /// Saves a new order: [orderedIds] lists the user's device ids from top to bottom.
  Future<void> reorder(int userId, List<int> orderedIds) => transaction(() async {
    for (final (index, id) in orderedIds.indexed) {
      await (update(devices)..where((d) => d.id.equals(id) & d.userId.equals(userId))).write(
        DevicesCompanion(sortOrder: Value(index)),
      );
    }
  });

  Future<void> deleteDevice(int id) => (delete(devices)..where((d) => d.id.equals(id))).go();

  /// Deletes the user's device at [address] (its alerts go with it) and returns how many rows
  /// were deleted: 0 or 1.
  Future<int> deleteForUser(int userId, String address) =>
      (delete(devices)..where((d) => d.userId.equals(userId) & d.address.equals(address))).go();
}
