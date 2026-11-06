import 'dart:convert';
import 'dart:typed_data';

import '../../../domain/transport/lan_address.dart';
import '../../../domain/transport/wifi_provisioner.dart';

/// Reads the device's reply to the credentials ("Wi‑Fi setup contract").
///
/// Returns null when [body] is not yet a whole JSON object (more BLE notifications to come).
/// Throws [ProvisioningException] for a refusal or a reply the app cannot use. The device's own
/// error text is not passed on, in case it echoes what it was sent.
ProvisionResult? parseProvisionReply(List<int> body) {
  final Object? reply;
  try {
    reply = jsonDecode(utf8.decode(body));
  } on FormatException {
    return null;
  }
  if (reply is! Map<String, dynamic>) throw const ProvisioningException('unexpected reply');
  if (reply['ok'] != true) throw const ProvisioningException('device could not join the network');

  final id = reply['id'];
  final ip = reply['ip'];
  if (id is! String || id.isEmpty || ip is! String) {
    throw const ProvisioningException('unexpected reply');
  }
  if (!isLanHost(ip)) {
    throw const ProvisioningException('device address is not on the local network');
  }
  return ProvisionResult(deviceId: id, address: ip);
}

/// The credentials as sent to the device; raw bytes, so HTTP clients send them unchanged.
Uint8List encodeCredentials(WifiCredentials credentials) =>
    utf8.encode(jsonEncode(credentials.toJson()));
