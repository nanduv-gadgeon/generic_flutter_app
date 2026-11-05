import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/device_link.dart';
import '../../../domain/transport/wifi_provisioner.dart';
import 'ble_wifi_provisioner.dart';
import 'softap_provisioner.dart';

/// [WifiProvisioner] that uses the setup method the user chose, with the profile's `wifi` block.
class WifiProvisionerImpl implements WifiProvisioner {
  WifiProvisionerImpl(this._ble, this._softAp);

  final BleWifiProvisioner _ble;
  final SoftApProvisioner _softAp;

  @override
  Future<ProvisionResult> provision(
    DeviceProfile profile,
    WifiSetupMethod method,
    WifiCredentials credentials, {
    String? bleDeviceId,
  }) async {
    final wifi = profile.wifi ?? (throw NotConnectableException(profile.id));
    if (!wifi.setup.contains(method)) {
      throw ProvisioningException('${method.name} setup is not supported by ${profile.id}');
    }
    return switch (method) {
      WifiSetupMethod.ble => _ble.provision(
        wifi.bleSetup!, // checkDeviceProfiles guarantees it for a listed method
        credentials,
        bleDeviceId ?? (throw const ProvisioningException('no device chosen')),
        timeout: wifi.setupTimeout,
      ),
      WifiSetupMethod.softap => _softAp.provision(
        wifi.softApSetup!,
        credentials,
        timeout: wifi.setupTimeout,
      ),
    };
  }
}
