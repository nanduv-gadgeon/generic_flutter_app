import '../../domain/services/backend_health.dart';

/// Phase 1: there is no backend, so it is always "reachable" and nothing is called.
class LocalBackendHealth implements BackendHealth {
  const LocalBackendHealth();

  @override
  Future<bool> isReachable() async => true;
}
