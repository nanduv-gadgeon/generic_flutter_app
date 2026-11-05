import 'dart:async';
import 'dart:typed_data';

import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/wifi_provisioner.dart';
import '../ble/ble_adapter.dart';
import 'provision_reply.dart';

/// Sends Wi‑Fi credentials to a device in setup mode over BLE.
///
/// Pairs first so the link is encrypted; iOS pairs when the device asks on the write.
class BleWifiProvisioner {
  BleWifiProvisioner(this._adapter);

  /// A reply longer than this is not a setup reply.
  static const maxReplyBytes = 1024;

  /// Asked for so the credentials and reply fit in single packets; best effort.
  static const preferredMtu = 517;

  final BleAdapter _adapter;

  /// Throws [ProvisioningException]; always disconnects afterwards.
  Future<ProvisionResult> provision(
    BleWifiSetup setup,
    WifiCredentials credentials,
    String deviceId, {
    required Duration timeout,
  }) async {
    final service = fullUuid(setup.serviceUuid);
    final write = fullUuid(setup.credentialsUuid);
    final result = fullUuid(setup.resultUuid);
    final reply = Completer<ProvisionResult>();
    final received = BytesBuilder();
    StreamSubscription<Uint8List>? values;

    try {
      await _adapter.connect(deviceId);
      await _adapter.pair(deviceId);
      final characteristics = (await _adapter.discover(deviceId))[service] ?? const {};
      if (!characteristics.contains(write) || !characteristics.contains(result)) {
        throw const ProvisioningException('device is not in Wi‑Fi setup mode');
      }
      try {
        await _adapter.requestMtu(deviceId, preferredMtu);
      } catch (_) {
        // Best effort: long writes and split replies still work.
      }

      // The reply may come in several notifications; collect until it is whole JSON.
      values = _adapter.values(deviceId, result).listen((value) {
        if (reply.isCompleted) return;
        received.add(value);
        try {
          if (received.length > maxReplyBytes) {
            throw const ProvisioningException('unexpected reply');
          }
          final parsed = parseProvisionReply(received.toBytes());
          if (parsed != null) reply.complete(parsed);
        } on ProvisioningException catch (e) {
          reply.completeError(e);
        }
      });
      await _adapter.subscribe(deviceId, service, result);
      await _adapter.write(deviceId, service, write, encodeCredentials(credentials));
      return await reply.future.timeout(
        timeout,
        onTimeout: () => throw const ProvisioningException('device did not answer'),
      );
    } on ProvisioningException {
      rethrow;
    } catch (e) {
      throw ProvisioningException('BLE setup failed: ${e.runtimeType}');
    } finally {
      await values?.cancel();
      try {
        await _adapter.disconnect(deviceId);
      } catch (_) {
        // Already gone.
      }
    }
  }
}
