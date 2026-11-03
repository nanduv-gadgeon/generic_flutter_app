import '../../core/config/config_sections.dart';
import '../../domain/services/backend_health.dart';

/// Phase 2 backend check.
class CloudBackendHealth implements BackendHealth {
  const CloudBackendHealth(this.config);

  final CloudConfig config;

  @override
  Future<bool> isReachable() async {
    // TODO(phase2): GET ${config.baseUrl}/health over HTTPS (TLS 1.2+) and return the result.
    return true;
  }
}
