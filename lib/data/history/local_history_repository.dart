import 'package:drift/drift.dart';

import '../../domain/services/history_repository.dart';
import '../db/app_database.dart';

/// [HistoryRepository] over the local database; the same in both phases.
// TODO(1.4.3): read the hours with data from the daily summary once it exists, instead of
// scanning the readings.
class LocalHistoryRepository implements HistoryRepository {
  LocalHistoryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Set<DateTime>> dataSlots(int deviceId, DateTime from, DateTime to) async {
    final slotMs = HistoryRepository.slot.inMilliseconds;
    final rows = await _db
        .customSelect(
          // Integer division: the slot number of each reading.
          'SELECT DISTINCT at_ms / ?4 AS slot FROM readings '
          'WHERE device_id = ?1 AND at_ms >= ?2 AND at_ms < ?3',
          variables: [
            Variable.withInt(deviceId),
            Variable.withInt(from.toUtc().millisecondsSinceEpoch),
            Variable.withInt(to.toUtc().millisecondsSinceEpoch),
            Variable.withInt(slotMs),
          ],
          readsFrom: {_db.readings},
        )
        .get();
    return {
      for (final row in rows)
        DateTime.fromMillisecondsSinceEpoch(row.read<int>('slot') * slotMs, isUtc: true),
    };
  }
}
