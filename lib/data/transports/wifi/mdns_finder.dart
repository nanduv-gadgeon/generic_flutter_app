import 'dart:async';

import 'package:multicast_dns/multicast_dns.dart';

import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/device_link.dart';
import '../../../domain/transport/lan_address.dart';
import '../../../domain/transport/wifi_device_finder.dart';

/// [WifiDeviceFinder] over `multicast_dns`: PTR for the profile's service, the instance named
/// after the device id, then its SRV (port) and A (IPv4) records.
class MdnsFinder implements WifiDeviceFinder {
  MdnsFinder([this._newClient = MDnsClient.new]);

  /// A fresh client per lookup; replaced in tests.
  final MDnsClient Function() _newClient;

  /// Throws [NotConnectableException] when the profile has no `wifi` block.
  @override
  Future<WifiEndpoint?> resolve(
    DeviceProfile profile,
    String deviceId, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final wifi = profile.wifi ?? (throw NotConnectableException(profile.id));
    final client = _newClient();
    try {
      await client.start();
      return await _lookup(
        client,
        '${wifi.mdnsService}.local',
        deviceId,
        timeout,
      ).timeout(timeout, onTimeout: () => null);
    } catch (_) {
      // No multicast on this network, or the socket failed: the caller falls back to the last IP.
      return null;
    } finally {
      client.stop();
    }
  }

  Future<WifiEndpoint?> _lookup(
    MDnsClient client,
    String service,
    String deviceId,
    Duration timeout,
  ) async {
    final instance = '${deviceId.toLowerCase()}.$service';
    await for (final ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(service),
      timeout: timeout,
    )) {
      if (ptr.domainName.toLowerCase() != instance) continue;
      await for (final srv in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
        timeout: timeout,
      )) {
        await for (final ip in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
          timeout: timeout,
        )) {
          final host = ip.address.address;
          if (isLanHost(host)) return WifiEndpoint(host, srv.port);
        }
      }
    }
    return null;
  }
}
