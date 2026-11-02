import 'package:drift/drift.dart';

import '../app_database.dart';

part 'session_dao.g.dart';

/// The single "who is logged in" row.
@DriftAccessor(tables: [Sessions])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(super.attachedDatabase);

  static const _rowId = 1;

  Future<Session?> current() => select(sessions).getSingleOrNull();

  Stream<Session?> watchCurrent() => select(sessions).watchSingleOrNull();

  /// Logs [userId] in, replacing any existing session.
  Future<void> start(int userId) {
    final now = DateTime.now();
    return into(sessions).insertOnConflictUpdate(
      SessionsCompanion.insert(
        id: const Value(_rowId),
        userId: userId,
        startedAt: now,
        lastActiveAt: now,
      ),
    );
  }

  Future<void> touch() =>
      update(sessions).write(SessionsCompanion(lastActiveAt: Value(DateTime.now())));

  Future<void> end() => delete(sessions).go();
}
