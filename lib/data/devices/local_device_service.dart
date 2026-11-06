import '../../domain/services/device_service.dart';
import '../db/app_database.dart';

/// Devices kept in the encrypted local database (both phases).
class LocalDeviceService implements DeviceService {
  LocalDeviceService(this._db);

  final AppDatabase _db;

  @override
  Stream<List<UserDevice>> watchDevices(int userId) => _db.devicesDao
      .watchForUser(userId)
      .map((rows) => [for (final row in rows) _toUserDevice(row)]);

  static UserDevice _toUserDevice(Device row) => UserDevice(
    id: row.id,
    name: row.name,
    profileId: row.profileId,
    batteryPercent: row.batteryPercent,
    lastHeartbeatAt: row.lastHeartbeatAt,
  );
}
