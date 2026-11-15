import 'package:flutter/foundation.dart';

import '../../domain/services/daily_summary_repository.dart';
import '../../domain/services/reading_repository.dart';
import '../db/app_database.dart';

/// [ReadingRepository] over the local database; the same in both phases. Readings from an
/// earlier day (late logs) have that day's summary worked out again in [_summaries].
class LocalReadingRepository implements ReadingRepository {
  LocalReadingRepository(this._db, {this._summaries});

  final AppDatabase _db;
  final DailySummaryRepository? _summaries;

  @override
  Future<void> addAll(int deviceId, List<Sample> samples) async {
    await _db.readingsDao.addAll([
      for (final s in samples)
        ReadingsCompanion.insert(
          deviceId: deviceId,
          key: s.key,
          value: s.value,
          atMs: s.at.toUtc().millisecondsSinceEpoch,
        ),
    ]);
    final summaries = _summaries;
    if (summaries == null || samples.isEmpty) return;
    try {
      await summaries.refreshDaysOf(deviceId, samples.map((s) => s.at));
    } catch (e) {
      // The readings are stored; the daily job works the summaries out again.
      if (kDebugMode) debugPrint('Summaries: refresh failed: ${e.runtimeType}');
    }
  }

  @override
  Stream<List<Sample>> watchRange(int deviceId, String key, DateTime from) => _db.readingsDao
      .watchRange(deviceId, key, from.toUtc().millisecondsSinceEpoch)
      .map((rows) => rows.map(_sample).toList());

  @override
  Stream<Map<String, Sample>> watchLatest(int deviceId) => _db.readingsDao
      .watchLatest(deviceId)
      .map((rows) => {for (final r in rows) r.key: _sample(r)});

  @override
  Future<int> deleteOlderThan(DateTime time) =>
      _db.readingsDao.deleteOlderThan(time.toUtc().millisecondsSinceEpoch);

  static Sample _sample(Reading r) =>
      Sample(r.key, r.value, DateTime.fromMillisecondsSinceEpoch(r.atMs, isUtc: true));
}
