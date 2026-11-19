import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/alerts.dart';
import '../core/di/services.dart';
import 'auth_controller.dart';

part 'reading_pipeline_provider.g.dart';

/// Ties the connected device and the alert engine to the logged-in user: logging in lets a
/// removed device be disconnected and starts raising alerts; logging out stops both. Watch it only once the config has loaded and the
/// database is open.
///
/// The app keeps the device connected while it runs in the foreground; background Bluetooth is
/// not set up.
@Riverpod(keepAlive: true)
class ReadingPipeline extends _$ReadingPipeline {
  @override
  int? build() {
    final userId = ref.watch(authControllerProvider).value?.id;
    final live = ref.read(liveReadingsProvider);
    final alerts = ref.read(alertEngineProvider);
    if (userId == null) {
      alerts.stop();
      live.stop();
    } else {
      live.start(userId);
      alerts.start(userId);
    }
    return userId;
  }
}
