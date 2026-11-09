import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/transports/wifi/ble_wifi_provisioner.dart';
import 'package:generic_flutter_app/data/transports/wifi/softap_provisioner.dart';
import 'package:generic_flutter_app/data/transports/wifi/wifi_provisioner_impl.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/transport/device_link.dart';
import 'package:generic_flutter_app/domain/transport/wifi_provisioner.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/test_config.dart';

class MockBleWifiProvisioner extends Mock implements BleWifiProvisioner {}

class MockSoftApProvisioner extends Mock implements SoftApProvisioner {}

const _credentials = WifiCredentials(ssid: 'TestNet', password: 'not-a-real-password');
const _result = ProvisionResult(deviceId: 'tst-0001', address: '192.168.1.20');

void main() {
  late MockBleWifiProvisioner ble;
  late MockSoftApProvisioner softAp;
  late WifiProvisionerImpl provisioner;
  final profile = DeviceProfile.fromJson(validWifiProfileJson());
  final wifi = profile.wifi!;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(wifi.softApSetup!);
    registerFallbackValue(_credentials);
  });

  setUp(() {
    ble = MockBleWifiProvisioner();
    softAp = MockSoftApProvisioner();
    provisioner = WifiProvisionerImpl(ble, softAp);
    when(() => ble.provision(wifi.bleSetup!, _credentials, 'dev-1', timeout: wifi.setupTimeout))
        .thenAnswer((_) async => _result);
    when(() => softAp.provision(wifi.softApSetup!, _credentials, timeout: wifi.setupTimeout))
        .thenAnswer((_) async => _result);
  });

  test('uses BLE setup with the chosen device', () async {
    expect(
      await provisioner.provision(profile, WifiSetupMethod.ble, _credentials, bleDeviceId: 'dev-1'),
      _result,
    );
    verifyNever(() => softAp.provision(any(), any(), timeout: any(named: 'timeout')));
  });

  test('uses the device hotspot for SoftAP setup', () async {
    expect(await provisioner.provision(profile, WifiSetupMethod.softap, _credentials), _result);
  });

  final refused = <String, (DeviceProfile, WifiSetupMethod, Matcher)>{
    'a profile without a wifi block': (
      profile.copyWith(wifi: null),
      WifiSetupMethod.softap,
      isA<NotConnectableException>(),
    ),
    'a method the profile does not list': (
      profile.copyWith(wifi: wifi.copyWith(setup: [WifiSetupMethod.ble])),
      WifiSetupMethod.softap,
      isA<ProvisioningException>(),
    ),
    'BLE setup without a chosen device': (
      profile,
      WifiSetupMethod.ble,
      isA<ProvisioningException>().having((e) => e.reason, 'reason', 'no device chosen'),
    ),
  };
  for (final MapEntry(key: name, value: (p, method, matcher)) in refused.entries) {
    test('refuses $name', () async {
      await expectLater(provisioner.provision(p, method, _credentials), throwsA(matcher));
    });
  }
}
