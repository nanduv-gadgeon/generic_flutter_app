import 'package:drift/drift.dart';

import '../app_database.dart';

part 'heartbeats_dao.g.dart';

/// When devices were heard from.
@DriftAccessor(tables: [Heartbeats])
class HeartbeatsDao extends DatabaseAccessor<AppDatabase> with _$HeartbeatsDaoMixin {
  HeartbeatsDao(super.attachedDatabase);

  Future<void> add(HeartbeatsCompanion row) => into(heartbeats).insert(row);

  /// The device's heartbeats, oldest first.
  Future<List<Heartbeat>> forDevice(int deviceId) =>
      (select(heartbeats)
            ..where((h) => h.deviceId.equals(deviceId))
            ..orderBy([(h) => OrderingTerm.asc(h.atMs)]))
          .get();

  /// Deletes heartbeats from before [beforeMs]; returns how many.
  Future<int> deleteOlderThan(int beforeMs) =>
      (delete(heartbeats)..where((h) => h.atMs.isSmallerThanValue(beforeMs))).go();
}
