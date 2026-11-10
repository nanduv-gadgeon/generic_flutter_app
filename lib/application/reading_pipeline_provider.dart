import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import 'auth_controller.dart';

part 'reading_pipeline_provider.g.dart';

/// Ties the connected device to the logged-in user: logging in lets a removed device be
/// disconnected, and logging out disconnects it. Watch it only once the config has loaded and the
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
    if (userId == null) {
      live.stop();
    } else {
      live.start(userId);
    }
    return userId;
  }
}
