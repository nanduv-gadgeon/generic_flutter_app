import 'package:dio/dio.dart';

import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/lan_address.dart';
import '../../../domain/transport/wifi_provisioner.dart';
import 'provision_reply.dart';

/// Sends Wi‑Fi credentials to a device over its own hotspot, which the phone has already joined.
///
/// [_dio] is only used for local addresses and has no logging interceptors.
class SoftApProvisioner {
  SoftApProvisioner(this._dio);

  final Dio _dio;

  /// Throws [ProvisioningException].
  Future<ProvisionResult> provision(
    SoftApSetup setup,
    WifiCredentials credentials, {
    required Duration timeout,
  }) async {
    if (!isLanHost(setup.address)) {
      throw const ProvisioningException('setup address is not on the local network');
    }
    final Response<List<int>> response;
    try {
      response = await _dio.postUri<List<int>>(
        Uri(scheme: 'http', host: setup.address, port: setup.port, path: setup.path),
        data: encodeCredentials(credentials),
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.bytes,
          receiveTimeout: timeout,
          sendTimeout: timeout,
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      throw ProvisioningException(switch (e.type) {
        DioExceptionType.receiveTimeout => 'device did not answer',
        _ => 'device not reachable – join its Wi‑Fi first',
      });
    }

    // A refusal in the body counts whatever the status; anything else needs a 2xx status.
    final status = response.statusCode ?? 0;
    final result = parseProvisionReply(response.data ?? const []);
    if (result == null || status < 200 || status >= 300) {
      throw ProvisioningException('device answered HTTP $status');
    }
    return result;
  }
}
