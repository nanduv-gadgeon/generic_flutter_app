import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/database.dart';
import '../core/di/services.dart';
import 'app_config_provider.dart';

part 'startup_provider.g.dart';

/// Result of the splash-screen start-up checks.
enum StartupResult { ready, backendUnreachable }

/// The encrypted local database could not be opened (e.g. its key is missing).
class LocalDataException implements Exception {
  const LocalDataException(this.cause);

  final Object cause;

  @override
  String toString() => 'LocalDataException: $cause';
}

/// Loads the config, opens the local database, then checks the backend (always reachable in
/// Phase 1).
///
/// Throws [ConfigException] or [LocalDataException]. Invalidate to retry.
@riverpod
Future<StartupResult> startup(Ref ref) async {
  await ref.watch(appConfigProvider.future);
  try {
    await ref.watch(appDatabaseProvider.future);
  } catch (e) {
    throw LocalDataException(e);
  }
  final reachable = await ref.watch(backendHealthProvider).isReachable();
  return reachable ? StartupResult.ready : StartupResult.backendUnreachable;
}
