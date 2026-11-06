import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/transports/wifi/mdns_finder.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/transport/device_link.dart';
import 'package:generic_flutter_app/domain/transport/wifi_device_finder.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../../../fixtures/test_config.dart';

class MockMDnsClient extends Mock implements MDnsClient {}

// Made-up device ids, host names and addresses for the test service `_fake._tcp`.
const _service = '_fake._tcp.local';

void main() {
  late MockMDnsClient client;
  late MdnsFinder finder;
  final profile = DeviceProfile.fromJson(validWifiProfileJson());

  /// Answers the PTR query with [instances], each with an SRV and A record.
  void announce(Map<String, (String ip, int port)> instances) {
    when(() => client.lookup<PtrResourceRecord>(any(), timeout: any(named: 'timeout'))).thenAnswer(
      (call) => Stream.fromIterable([
        for (final name in instances.keys) PtrResourceRecord(_service, 0, domainName: name),
      ]),
    );
    when(() => client.lookup<SrvResourceRecord>(any(), timeout: any(named: 'timeout')))
        .thenAnswer((call) {
          final name = (call.positionalArguments.first as ResourceRecordQuery).fullyQualifiedName;
          final (_, port) = instances[name]!;
          return Stream.value(
            SrvResourceRecord(name, 0, target: '$name.host', port: port, priority: 0, weight: 0),
          );
        });
    when(() => client.lookup<IPAddressResourceRecord>(any(), timeout: any(named: 'timeout')))
        .thenAnswer((call) {
          final target = (call.positionalArguments.first as ResourceRecordQuery).fullyQualifiedName;
          final (ip, _) = instances[target.replaceAll('.host', '')]!;
          return Stream.value(IPAddressResourceRecord(target, 0, address: InternetAddress(ip)));
        });
  }

  setUpAll(() {
    registerFallbackValue(ResourceRecordQuery.serverPointer(_service));
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    client = MockMDnsClient();
    when(() => client.start()).thenAnswer((_) async {});
    when(() => client.stop()).thenReturn(null);
    finder = MdnsFinder(() => client);
  });

  test('finds the instance named after the device and returns its IP and port', () async {
    announce({
      'tst-0002.$_service': ('192.168.1.30', 81),
      'TST-0001.$_service': ('192.168.1.20', 8080),
    });

    expect(await finder.resolve(profile, 'tst-0001'), const WifiEndpoint('192.168.1.20', 8080));
    verify(() => client.stop()).called(1);
  });

  final notFound = <String, Map<String, (String, int)>>{
    'no device of that id': {'tst-0002.$_service': ('192.168.1.30', 80)},
    'an address off the local network': {'tst-0001.$_service': ('8.8.8.8', 80)},
  };
  for (final MapEntry(key: name, value: instances) in notFound.entries) {
    test('returns null for $name', () async {
      announce(instances);

      expect(await finder.resolve(profile, 'tst-0001'), isNull);
    });
  }

  test('returns null when multicast is not available', () async {
    when(() => client.start()).thenThrow(const SocketException('no multicast'));

    expect(await finder.resolve(profile, 'tst-0001'), isNull);
    verify(() => client.stop()).called(1);
  });

  test('refuses a profile without a wifi block', () {
    expect(
      () => finder.resolve(profile.copyWith(wifi: null), 'tst-0001'),
      throwsA(isA<NotConnectableException>()),
    );
  });
}
