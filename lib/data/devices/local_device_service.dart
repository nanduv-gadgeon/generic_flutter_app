import 'package:drift/drift.dart';

import '../../domain/models/device_profile.dart';
import '../../domain/services/device_registration.dart';
import '../../domain/services/device_service.dart';
import '../db/app_database.dart';

/// Devices kept in the encrypted local database (both phases). New devices are also passed to
/// [_registration], which only reaches the cloud in Phase 2.
class LocalDeviceService implements DeviceService {
  LocalDeviceService(this._db, this._registration);

  final AppDatabase _db;
  final DeviceRegistration _registration;

  @override
  Stream<List<UserDevice>> watchDevices(int userId) => _db.devicesDao
      .watchForUser(userId)
      .map((rows) => [for (final row in rows) _toUserDevice(row)]);

  @override
  Future<AddedDevice> addDevice(NewDevice device, List<AlertRule> defaults) async {
    final dao = _db.devicesDao;
    if (await dao.existsForUser(device.userId, device.address)) {
      throw const DeviceAlreadyAddedException();
    }
    final id = await dao.addDeviceWithAlerts(
      DevicesCompanion.insert(
        userId: device.userId,
        name: device.name,
        profileId: device.profileId,
        transport: DeviceTransport.values.byName(device.transport.name),
        address: device.address,
        ipAddress: Value(device.ipAddress),
        sortOrder: 0, // set by the DAO
      ),
      _toRows(defaults),
    );
    final added = AddedDevice(id: id, name: device.name, alerts: defaults);

    final cloud = await _registration.register(device);
    if (cloud == null) return added;
    await dao.setDeviceKey(id, cloud.deviceKey);
    if (cloud.alerts.isEmpty) return added.copyWith(deviceKey: cloud.deviceKey);
    await dao.replaceAlerts(id, _toRows(cloud.alerts));
    return added.copyWith(deviceKey: cloud.deviceKey, alerts: cloud.alerts, suggestedAlerts: true);
  }

  @override
  Future<void> rename(int deviceId, String name) => _db.devicesDao.rename(deviceId, name);

  @override
  Future<bool> isAdded(int userId, String address) => _db.devicesDao.existsForUser(userId, address);

  @override
  Future<void> removeDevice(int userId, String address) async {
    if (await _db.devicesDao.deleteForUser(userId, address) == 0) return;
    await _registration.unregister(address);
  }

  static List<DeviceAlertsCompanion> _toRows(List<AlertRule> alerts) => [
    for (final alert in alerts)
      DeviceAlertsCompanion.insert(
        deviceId: 0, // set by the DAO
        readingKey: alert.key,
        above: Value(alert.above),
        below: Value(alert.below),
      ),
  ];

  static UserDevice _toUserDevice(Device row) => UserDevice(
    id: row.id,
    name: row.name,
    profileId: row.profileId,
    transport: Transport.values.byName(row.transport.name),
    batteryPercent: row.batteryPercent,
    lastHeartbeatAt: row.lastHeartbeatAt,
  );
}
