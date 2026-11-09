import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_adapter.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_device_link.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/transport/device_link.dart';
import 'package:mocktail/mocktail.dart';

class MockBleAdapter extends Mock implements BleAdapter {}

// Made-up UUIDs and device id.
const _id = 'AA:BB:CC:00:00:01';
const _service = '11111111-2222-3333-4444-000000000000';
const _notify = '11111111-2222-3333-4444-000000000001';
const _write = '11111111-2222-3333-4444-000000000002';
const _reply = '11111111-2222-3333-4444-000000000003';
const _clock = '11111111-2222-3333-4444-000000000004';
final _battery = fullUuid(batteryServiceUuid);
final _level = fullUuid(batteryLevelUuid);

/// A device that answers on its own characteristic, keeps a clock and has its battery polled.
const _settings = BleSettings(
  serviceUuid: _service,
  notifyUuid: _notify,
  writeUuid: _write,
  replyUuid: _reply,
  timeSync: TimeSync(
    uuid: _clock,
    fields: [TimeField.year16le, TimeField.month, TimeField.day, TimeField.millis16le],
  ),
  batteryPollSeconds: 60,
);

/// The UTC time written to the device: 2026‑11‑03, 250 ms past the second.
const _timeBytes = [0xEA, 0x07, 0x0B, 0x03, 0xFA, 0x00];

void main() {
  late MockBleAdapter adapter;
  late StreamController<Uint8List> notifyValues;
  late StreamController<Uint8List> replyValues;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    adapter = MockBleAdapter();
    notifyValues = StreamController.broadcast();
    replyValues = StreamController.broadcast();
    when(() => adapter.connect(_id)).thenAnswer((_) async {});
    when(() => adapter.disconnect(_id)).thenAnswer((_) async {});
    when(() => adapter.discover(_id)).thenAnswer(
      (_) async => {
        _service: {_notify, _write, _reply, _clock},
        _battery: {_level},
      },
    );
    when(() => adapter.subscribe(_id, any(), any())).thenAnswer((_) async {});
    when(() => adapter.values(_id, _notify)).thenAnswer((_) => notifyValues.stream);
    when(() => adapter.values(_id, _reply)).thenAnswer((_) => replyValues.stream);
    when(() => adapter.values(_id, _level)).thenAnswer((_) => const Stream.empty());
    when(() => adapter.read(_id, _battery, _level))
        .thenAnswer((_) async => Uint8List.fromList([80]));
    when(() => adapter.write(_id, any(), any(), any())).thenAnswer((_) async {});
    when(() => adapter.connection(_id)).thenAnswer((_) => const Stream.empty());
    when(() => adapter.requestMtu(_id, any())).thenAnswer((_) async => 247);
  });

  BleDeviceLink link([BleSettings settings = _settings]) => BleDeviceLink(
    adapter,
    _id,
    settings,
    delay: (_) async {},
    now: () => DateTime.utc(2026, 11, 3, 15, 45, 30, 250),
  );

  test('tags data and replies by the characteristic they arrive on', () async {
    final l = link();
    final packets = <DevicePacket>[];
    l.packets.listen(packets.add);
    await l.connect();

    notifyValues.add(Uint8List.fromList([0x11]));
    replyValues.add(Uint8List.fromList([0x5A, 0x5A]));
    await pumpEventQueue();

    expect([for (final p in packets) p.source], [FrameSource.data, FrameSource.reply]);
    expect(
      [for (final p in packets) p.bytes],
      [
        [0x11],
        [0x5A, 0x5A],
      ],
    );
    verify(() => adapter.subscribe(_id, _service, _reply)).called(1);
  });

  test('writes the UTC time after subscribing', () async {
    await link().connect();

    verifyInOrder([
      () => adapter.subscribe(_id, _service, _reply),
      () => adapter.write(_id, _service, _clock, any(that: equals(_timeBytes))),
    ]);
  });

  test('without reply or clock settings neither is touched', () async {
    await link(const BleSettings(serviceUuid: _service, notifyUuid: _notify, writeUuid: _write))
        .connect();

    verifyNever(() => adapter.subscribe(_id, _service, _reply));
    verifyNever(() => adapter.write(_id, _service, _clock, any()));
  });

  final missing = <String, (Set<String>, String)>{
    'reply': ({_notify, _write, _clock}, 'device has no reply characteristic'),
    'clock': ({_notify, _write, _reply}, 'device has no clock characteristic'),
  };
  for (final MapEntry(key: name, value: (characteristics, message)) in missing.entries) {
    test('a device without the $name characteristic cannot connect', () async {
      when(() => adapter.discover(_id)).thenAnswer((_) async => {_service: characteristics});

      await expectLater(
        link().connect(),
        throwsA(isA<LinkException>().having((e) => e.message, 'message', message)),
      );
    });
  }

  test('reads the battery again every 60 s until disconnected', () {
    fakeAsync((async) {
      final levels = <int>[];
      final l = link();
      l.battery.listen(levels.add);
      l.connect();
      async.flushMicrotasks();
      when(() => adapter.read(_id, _battery, _level))
          .thenAnswer((_) async => Uint8List.fromList([79]));

      async.elapse(const Duration(seconds: 125));
      expect(levels, [80, 79, 79]);

      l.disconnect();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 120));
      expect(levels, hasLength(3));
    });
  });

  test('a failed battery read waits for the next one', () {
    fakeAsync((async) {
      final levels = <int>[];
      final l = link();
      l.battery.listen(levels.add);
      l.connect();
      async.flushMicrotasks();
      var reads = 0;
      when(
        () => adapter.read(_id, _battery, _level),
      ).thenAnswer((_) async => ++reads == 1 ? throw Exception('gone') : Uint8List.fromList([78]));

      async.elapse(const Duration(seconds: 121));
      expect(levels, [80, 78]);
      l.disconnect();
    });
  });
}
