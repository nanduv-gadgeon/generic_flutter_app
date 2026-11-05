import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_adapter.dart';
import 'package:generic_flutter_app/data/transports/wifi/ble_wifi_provisioner.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/transport/wifi_provisioner.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/test_config.dart';

class MockBleAdapter extends Mock implements BleAdapter {}

// Made-up device id and credentials.
const _id = 'AA:BB:CC:00:00:02';
const _credentials = WifiCredentials(ssid: 'TestNet', password: 'not-a-real-password');
final _setup = WifiSettings.fromJson(wifiBlockJson()).bleSetup!;
final _service = fullUuid(_setup.serviceUuid);
final _write = fullUuid(_setup.credentialsUuid);
final _result = fullUuid(_setup.resultUuid);

Uint8List _json(Object value) => Uint8List.fromList(utf8.encode(jsonEncode(value)));

void main() {
  late MockBleAdapter adapter;
  late StreamController<Uint8List> replies;
  late BleWifiProvisioner provisioner;
  late List<Uint8List> written;

  /// The device answers each credentials write with these notifications.
  void answerWith(List<Uint8List> notifications) {
    when(() => adapter.write(_id, _service, _write, any())).thenAnswer((call) async {
      written.add(call.positionalArguments[3] as Uint8List);
      for (final n in notifications) {
        replies.add(n);
      }
    });
  }

  Future<ProvisionResult> provision({Duration timeout = const Duration(seconds: 1)}) =>
      provisioner.provision(_setup, _credentials, _id, timeout: timeout);

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    adapter = MockBleAdapter();
    replies = StreamController.broadcast();
    written = [];
    when(() => adapter.connect(_id)).thenAnswer((_) async {});
    when(() => adapter.pair(_id)).thenAnswer((_) async {});
    when(() => adapter.disconnect(_id)).thenAnswer((_) async {});
    when(() => adapter.discover(_id)).thenAnswer(
      (_) async => {
        _service: {_write, _result},
      },
    );
    when(() => adapter.requestMtu(_id, any())).thenAnswer((_) async => 23);
    when(() => adapter.subscribe(_id, _service, _result)).thenAnswer((_) async {});
    when(() => adapter.values(_id, _result)).thenAnswer((_) => replies.stream);
    provisioner = BleWifiProvisioner(adapter);
  });

  test('pairs, writes the credentials as JSON and returns the reply', () async {
    answerWith([
      _json({'ok': true, 'id': 'tst-0001', 'ip': '192.168.1.20'}),
    ]);

    expect(await provision(), const ProvisionResult(deviceId: 'tst-0001', address: '192.168.1.20'));
    expect(jsonDecode(utf8.decode(written.single)), {
      'ssid': 'TestNet',
      'password': 'not-a-real-password',
    });
    verifyInOrder([
      () => adapter.connect(_id),
      () => adapter.pair(_id),
      () => adapter.subscribe(_id, _service, _result),
      () => adapter.write(_id, _service, _write, any()),
      () => adapter.disconnect(_id),
    ]);
  });

  test('joins a reply split over several notifications', () async {
    final whole = _json({'ok': true, 'id': 'tst-0001', 'ip': '192.168.1.20'});
    answerWith([whole.sublist(0, 20), whole.sublist(20)]);

    expect((await provision()).deviceId, 'tst-0001');
  });

  test('still works when the larger packet size is refused', () async {
    when(() => adapter.requestMtu(_id, any())).thenThrow(Exception('not supported'));
    answerWith([
      _json({'ok': true, 'id': 'tst-0001', 'ip': '192.168.1.20'}),
    ]);

    expect((await provision()).address, '192.168.1.20');
  });

  // Each case ends in a ProvisioningException with this reason, and always disconnects.
  final failures = <String, (void Function(), String)>{
    'a refusal': (
      () => answerWith([
        _json({'ok': false, 'error': 'echo not-a-real-password'}),
      ]),
      'device could not join the network',
    ),
    'a reply address off the local network': (
      () => answerWith([
        _json({'ok': true, 'id': 'tst-0001', 'ip': '8.8.8.8'}),
      ]),
      'device address is not on the local network',
    ),
    'a reply without an id': (
      () => answerWith([
        _json({'ok': true, 'ip': '192.168.1.20'}),
      ]),
      'unexpected reply',
    ),
    'no reply': (() => answerWith([]), 'device did not answer'),
    'an over-long reply': (
      () => answerWith([Uint8List(BleWifiProvisioner.maxReplyBytes + 1)]),
      'unexpected reply',
    ),
    'a device not in setup mode': (
      () => when(() => adapter.discover(_id)).thenAnswer((_) async => {_service: <String>{}}),
      'device is not in Wi‑Fi setup mode',
    ),
    'a failed pairing': (
      () => when(() => adapter.pair(_id)).thenThrow(Exception('rejected')),
      'BLE setup failed: _Exception',
    ),
  };
  for (final MapEntry(key: name, value: (arrange, reason)) in failures.entries) {
    test('fails on $name and disconnects', () async {
      arrange();

      await expectLater(
        provision(timeout: const Duration(milliseconds: 50)),
        throwsA(
          isA<ProvisioningException>()
              .having((e) => e.reason, 'reason', reason)
              .having((e) => e.toString(), 'text', isNot(contains('not-a-real-password'))),
        ),
      );
      verify(() => adapter.disconnect(_id)).called(1);
    });
  }

  test('never shows the password in the credentials text', () {
    expect(_credentials.toString(), isNot(contains('not-a-real-password')));
  });
}
