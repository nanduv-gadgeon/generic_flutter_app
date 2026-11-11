import 'package:drift/drift.dart';

import '../../domain/services/heartbeat_repository.dart';
import '../db/app_database.dart';

/// [HeartbeatRepository] over the local database; the same in both phases.
class LocalHeartbeatRepository implements HeartbeatRepository {
  LocalHeartbeatRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> add(int deviceId, DateTime at, {int? batteryPercent}) => _db.heartbeatsDao.add(
    HeartbeatsCompanion.insert(
      deviceId: deviceId,
      atMs: at.toUtc().millisecondsSinceEpoch,
      batteryPercent: Value(batteryPercent),
    ),
  );

  @override
  Future<int> deleteOlderThan(DateTime cutoff) =>
      _db.heartbeatsDao.deleteOlderThan(cutoff.toUtc().millisecondsSinceEpoch);
}
