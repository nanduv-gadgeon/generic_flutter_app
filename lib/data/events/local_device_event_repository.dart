import 'package:drift/drift.dart';

import '../../domain/decoder/decoded_packet.dart';
import '../../domain/services/device_event_repository.dart';
import '../db/app_database.dart';

/// [DeviceEventRepository] over the local database; the same in both phases. Unknown events are
/// not stored.
class LocalDeviceEventRepository implements DeviceEventRepository {
  LocalDeviceEventRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> addAll(int deviceId, List<DeviceEvent> events) => _db.transaction(() async {
    for (final event in events) {
      if (event.kind == DeviceEventKind.unknown) continue;
      await _db.deviceEventsDao.add(
        DeviceEventsCompanion.insert(
          deviceId: deviceId,
          kind: event.kind.name,
          code: Value(event.code),
          atMs: event.at.toUtc().millisecondsSinceEpoch,
        ),
      );
    }
  });

  @override
  Stream<List<DeviceEvent>> watchSince(int deviceId, DateTime from) => _db.deviceEventsDao
      .watchSince(deviceId, from.toUtc().millisecondsSinceEpoch)
      .map((rows) => [for (final row in rows) _toEvent(row)]);

  @override
  Future<int> deleteOlderThan(DateTime cutoff) =>
      _db.deviceEventsDao.deleteOlderThan(cutoff.toUtc().millisecondsSinceEpoch);

  static DeviceEvent _toEvent(DeviceEventRow row) => DeviceEvent(
    DeviceEventKind.values.asNameMap()[row.kind] ?? DeviceEventKind.unknown,
    DateTime.fromMillisecondsSinceEpoch(row.atMs, isUtc: true),
    code: row.code,
  );
}
