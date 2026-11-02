/// Checks that the cloud backend can be reached before login (requirement 1.4).
///
/// Phase 1 has no backend and always answers true without any network call.
abstract interface class BackendHealth {
  Future<bool> isReachable();
}
