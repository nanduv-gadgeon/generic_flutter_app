import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import 'app_config_provider.dart';

part 'startup_provider.g.dart';

/// Result of the splash-screen start-up checks.
enum StartupResult { ready, backendUnreachable }

/// Loads the config, then checks the backend (always reachable in Phase 1).
///
/// Throws [ConfigException] if the config is missing or invalid. Invalidate to retry.
@riverpod
Future<StartupResult> startup(Ref ref) async {
  await ref.watch(appConfigProvider.future);
  final reachable = await ref.watch(backendHealthProvider).isReachable();
  return reachable ? StartupResult.ready : StartupResult.backendUnreachable;
}
