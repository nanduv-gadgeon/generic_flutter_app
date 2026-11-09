import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/transports/wifi/softap_provisioner.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/transport/wifi_provisioner.dart';

// Made-up credentials. A real HTTP server on loopback stands in for the device's hotspot.
const _credentials = WifiCredentials(ssid: 'TestNet', password: 'not-a-real-password');

void main() {
  late HttpServer server;
  late SoftApProvisioner provisioner;
  late List<Object?> received;

  /// The device answers every request with [status] and [body].
  void answerWith(int status, Object body) {
    server.listen((request) async {
      received.add(jsonDecode(await utf8.decodeStream(request)));
      request.response
        ..statusCode = status
        ..write(body is String ? body : jsonEncode(body));
      await request.response.close();
    });
  }

  SoftApSetup setup({String address = '127.0.0.1', int? port}) =>
      SoftApSetup(ssidPrefix: 'TST-', address: address, port: port ?? server.port, path: '/setup');

  Future<ProvisionResult> provision(SoftApSetup setup) =>
      provisioner.provision(setup, _credentials, timeout: const Duration(milliseconds: 500));

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    received = [];
    provisioner = SoftApProvisioner(Dio());
  });

  tearDown(() => server.close(force: true));

  test('posts the credentials as JSON and returns the reply', () async {
    answerWith(200, {'ok': true, 'id': 'tst-0001', 'ip': '192.168.1.20'});

    expect(
      await provision(setup()),
      const ProvisionResult(deviceId: 'tst-0001', address: '192.168.1.20'),
    );
    expect(received, [
      {'ssid': 'TestNet', 'password': 'not-a-real-password'},
    ]);
  });

  // Each case ends in a ProvisioningException with this reason.
  final failures = <String, (int, Object, String)>{
    'a refusal': (400, {'ok': false, 'error': 'bad password'}, 'device could not join the network'),
    'a reply address off the local network': (
      200,
      {'ok': true, 'id': 'tst-0001', 'ip': '8.8.8.8'},
      'device address is not on the local network',
    ),
    'an error page': (404, 'Not found', 'device answered HTTP 404'),
    'a success status without a usable reply': (200, 'OK', 'device answered HTTP 200'),
  };
  for (final MapEntry(key: name, value: (status, body, reason)) in failures.entries) {
    test('fails on $name', () async {
      answerWith(status, body);

      await expectLater(
        provision(setup()),
        throwsA(isA<ProvisioningException>().having((e) => e.reason, 'reason', reason)),
      );
    });
  }

  test('says to join the hotspot when the device is not reachable', () async {
    final port = server.port;
    await server.close(force: true);

    await expectLater(
      provision(setup(port: port)),
      throwsA(
        isA<ProvisioningException>().having(
          (e) => e.reason,
          'reason',
          'device not reachable – join its Wi‑Fi first',
        ),
      ),
    );
  });

  test('times out when the device does not answer', () async {
    server.listen((_) {}); // Never answers.

    await expectLater(
      provision(setup()),
      throwsA(
        isA<ProvisioningException>().having((e) => e.reason, 'reason', 'device did not answer'),
      ),
    );
  });

  test('refuses an address off the local network without sending anything', () async {
    await expectLater(
      provision(setup(address: '8.8.8.8')),
      throwsA(
        isA<ProvisioningException>().having(
          (e) => e.reason,
          'reason',
          'setup address is not on the local network',
        ),
      ),
    );
  });
}
