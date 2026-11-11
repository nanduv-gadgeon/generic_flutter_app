import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/device_profile.dart';
import '../../domain/services/device_registration.dart';
import '../../domain/services/device_service.dart';
import '../../domain/transport/device_pairing.dart';
import '../db/app_database.dart';

/// Devices kept in the encrypted local database (both phases). New devices are also passed to
/// [_registration], which only reaches the cloud in Phase 2. Removed BLE devices are unpaired
/// through [_pairing].
class LocalDeviceService implements DeviceService {
  LocalDeviceService(this._db, this._registration, this._pairing);

  final AppDatabase _db;
  final DeviceRegistration _registration;
  final DevicePairing _pairing;

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
  Stream<DeviceDetails?> watchDevice(int userId, int deviceId) => _db.devicesDao
      .watchDevice(userId, deviceId)
      .map((found) => found == null ? null : _toDetails(found.$1, found.$2));

  @override
  Future<void> rename(int deviceId, String name) => _db.devicesDao.rename(deviceId, name);

  @override
  Future<void> setAlertEnabled(int deviceId, String readingKey, {required bool enabled}) =>
      _db.devicesDao.setAlertEnabled(deviceId, readingKey, enabled: enabled);

  @override
  Future<void> reorder(int userId, List<int> orderedIds) =>
      _db.devicesDao.reorder(userId, orderedIds);

  @override
  Future<bool> isAdded(int userId, String address) => _db.devicesDao.existsForUser(userId, address);

  @override
  Future<void> removeDevice(int userId, String address) async {
    final row = await _db.devicesDao.findForUser(userId, address);
    if (row != null) await _remove(row);
  }

  @override
  Future<void> removeById(int userId, int deviceId) async {
    final row = await _db.devicesDao.byId(deviceId);
    if (row != null && row.userId == userId) await _remove(row);
  }

  /// Deletes the row (its alerts and readings go with it), so a connected device is disconnected
  /// too, then unpairs it and tells the cloud.
  Future<void> _remove(Device row) async {
    await _db.devicesDao.deleteDevice(row.id);
    if (row.transport == DeviceTransport.ble) {
      try {
        await _pairing.unpair(row.address);
      } catch (e) {
        // The device is already gone from the app; a pairing left behind can be removed in the
        // phone's Bluetooth settings.
        if (kDebugMode) debugPrint('Remove device: unpair failed (${e.runtimeType})');
      }
    }
    await _registration.unregister(row.address);
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

  static DeviceDetails _toDetails(Device row, List<DeviceAlert> alerts) => DeviceDetails(
    id: row.id,
    name: row.name,
    profileId: row.profileId,
    transport: Transport.values.byName(row.transport.name),
    address: row.address,
    ipAddress: row.ipAddress,
    firmware: row.firmware,
    batteryPercent: row.batteryPercent,
    lastHeartbeatAt: row.lastHeartbeatAt,
    alerts: [
      for (final a in alerts)
        AlertSetting(
          rule: AlertRule(key: a.readingKey, above: a.above, below: a.below),
          enabled: a.enabled,
        ),
    ],
  );

  static UserDevice _toUserDevice(Device row) => UserDevice(
    id: row.id,
    name: row.name,
    profileId: row.profileId,
    transport: Transport.values.byName(row.transport.name),
    batteryPercent: row.batteryPercent,
    lastHeartbeatAt: row.lastHeartbeatAt,
  );
}
