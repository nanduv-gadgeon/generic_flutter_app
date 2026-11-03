import 'package:drift/drift.dart';

import '../app_database.dart';

part 'devices_dao.g.dart';

@DriftAccessor(tables: [Devices])
class DevicesDao extends DatabaseAccessor<AppDatabase> with _$DevicesDaoMixin {
  DevicesDao(super.attachedDatabase);

  /// The user's devices in their chosen order.
  Stream<List<Device>> watchForUser(int userId) =>
      (select(devices)
            ..where((d) => d.userId.equals(userId))
            ..orderBy([(d) => OrderingTerm.asc(d.sortOrder)]))
          .watch();

  /// Adds a device at the end of the user's list and returns its id.
  Future<int> addDevice(DevicesCompanion device) => transaction(() async {
    final userId = device.userId.value;
    final maxOrder = devices.sortOrder.max();
    final last =
        await (selectOnly(devices)
              ..addColumns([maxOrder])
              ..where(devices.userId.equals(userId)))
            .map((row) => row.read(maxOrder))
            .getSingle();
    return into(devices).insert(device.copyWith(sortOrder: Value((last ?? -1) + 1)));
  });

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
}
