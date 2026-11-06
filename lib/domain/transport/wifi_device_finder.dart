import '../models/device_profile.dart';

/// Where a Wi‑Fi device listens on the local network.
class WifiEndpoint {
  const WifiEndpoint(this.host, [this.port = defaultPort]);

  /// Used when the device is reached by its last known IP instead of mDNS.
  static const defaultPort = 80;

  final String host;
  final int port;

  @override
  bool operator ==(Object other) =>
      other is WifiEndpoint && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => 'WifiEndpoint($host:$port)';
}

/// Finds a set-up Wi‑Fi device on the local network by mDNS.
abstract interface class WifiDeviceFinder {
  /// Where the device [deviceId] of type [profile] listens, or null when it does not answer within
  /// [timeout]. Only local addresses are returned. The profile must have a `wifi` block.
  Future<WifiEndpoint?> resolve(
    DeviceProfile profile,
    String deviceId, {
    Duration timeout = const Duration(seconds: 5),
  });
}
