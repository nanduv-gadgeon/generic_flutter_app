import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/history/local_history_repository.dart';
import '../../domain/services/history_repository.dart';
import 'database.dart';

part 'history.g.dart';

/// What History reads: the local database in both phases (requirement 6.1).
@Riverpod(keepAlive: true)
HistoryRepository historyRepository(Ref ref) =>
    LocalHistoryRepository(ref.watch(appDatabaseProvider).requireValue);
