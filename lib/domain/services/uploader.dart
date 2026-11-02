/// Sends readings stored on the phone to the cloud (Phase 2).
///
/// Phase 1 uses a no-op implementation. Chosen once in `core/di` from `isCloud`.
abstract interface class Uploader {
  /// Starts uploads on the Auto sync schedule.
  Future<void> start();

  /// Stops scheduled uploads, e.g. on log out.
  Future<void> stop();

  /// Sends everything not yet sent, now.
  Future<void> syncNow();
}
