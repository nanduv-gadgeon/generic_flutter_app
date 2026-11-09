import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_adapter.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_device_link.dart';
import 'package:generic_flutter_app/data/transports/link_support.dart';
import 'package:generic_flutter_app/domain/transport/device_link.dart';
import 'package:mocktail/mocktail.dart';

class MockBleAdapter extends Mock implements BleAdapter {}

// Made-up UUIDs and device id.
const _id = 'AA:BB:CC:00:00:03';
const _service = '33333333-2222-3333-4444-000000000000';
const _notify = '33333333-2222-3333-4444-000000000001';
const _write = '33333333-2222-3333-4444-000000000002';
const _clock = '33333333-2222-3333-4444-000000000004';

void main() {
  late MockBleAdapter adapter;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    adapter = MockBleAdapter();
    when(() => adapter.connect(_id)).thenAnswer((_) async {});
    when(() => adapter.disconnect(_id)).thenAnswer((_) async {});
    when(() => adapter.discover(_id)).thenAnswer(
      (_) async => {
        _service: {_notify, _write, _clock},
      },
    );
    when(() => adapter.subscribe(_id, any(), any())).thenAnswer((_) async {});
    when(() => adapter.values(_id, any())).thenAnswer((_) => const Stream.empty());
    when(() => adapter.connection(_id)).thenAnswer((_) => const Stream.empty());
    when(() => adapter.requestMtu(_id, any())).thenAnswer((_) async => 247);
    when(
      () => adapter.write(_id, any(), any(), any(), withoutResponse: any(named: 'withoutResponse')),
    ).thenAnswer((_) async {});
  });

  BleDeviceLink link({bool withoutResponse = false, bool clock = false}) => BleDeviceLink(
    adapter,
    _id,
    BleSettings(
      serviceUuid: _service,
      notifyUuid: _notify,
      writeUuid: _write,
      batteryService: false,
      writeWithoutResponse: withoutResponse,
      timeSync: clock ? const TimeSync(uuid: _clock, fields: [TimeField.second]) : null,
    ),
    delay: (_) async {},
    now: () => DateTime.utc(2026, 1, 15, 8, 30, 7),
  );

  final cases = {false: 'with response (the default)', true: 'without response'};
  for (final MapEntry(key: withoutResponse, value: name) in cases.entries) {
    test('commands are written $name, as the profile says', () async {
      final l = link(withoutResponse: withoutResponse);
      await l.connect();

      await l.send([0xA5, 0xA5, 0x02, 0x20, 0x02]);

      verify(
        () => adapter.write(
          _id,
          _service,
          _write,
          Uint8List.fromList([0xA5, 0xA5, 0x02, 0x20, 0x02]),
          withoutResponse: withoutResponse,
        ),
      ).called(1);
    });
  }

  for (final MapEntry(key: withoutResponse, value: name) in cases.entries) {
    test('the clock is written $name on connect, as the profile says', () async {
      await link(withoutResponse: withoutResponse, clock: true).connect();

      verify(
        () => adapter.write(
          _id,
          _service,
          _clock,
          Uint8List.fromList([7]),
          withoutResponse: withoutResponse,
        ),
      ).called(1);
    });
  }

  test('a refused write names the cause, not only the error type', () async {
    when(
      () => adapter.write(_id, any(), any(), any(), withoutResponse: any(named: 'withoutResponse')),
    ).thenThrow(StateError('characteristic does not support write withResponse'));
    final l = link();
    await l.connect();

    await expectLater(
      l.send([0x01]),
      throwsA(
        isA<LinkException>().having(
          (e) => e.message,
          'message',
          'write failed: Bad state: characteristic does not support write withResponse',
        ),
      ),
    );
  });

  test('describeError keeps errors short and on one line', () {
    expect(describeError(StateError('a\n  b')), 'Bad state: a b');
    expect(describeError(StateError('x' * 300)), hasLength(201));
  });

  test('the PPG + motion sensor writes commands without response (hardware finding)', () {
    final json = jsonDecode(
      File('assets/config/vitacare/app_config.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final profile = AppConfig.fromJson(json).deviceProfiles
        .firstWhere((p) => p.id == 'ppg_motion_v1');

    expect(profile.ble!.writeWithoutResponse, isTrue);
  });
}
