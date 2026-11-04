import 'dart:async';
import 'dart:typed_data';

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
final _battery = fullUuid(batteryServiceUuid);
final _level = fullUuid(batteryLevelUuid);

const _settings = BleSettings(serviceUuid: _service, notifyUuid: _notify, writeUuid: _write);

/// Lets queued async work run.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockBleAdapter adapter;
  late StreamController<bool> connection;
  late StreamController<Uint8List> notifyValues;
  late StreamController<Uint8List> batteryValues;
  late List<Duration> delays;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    adapter = MockBleAdapter();
    connection = StreamController.broadcast();
    notifyValues = StreamController.broadcast();
    batteryValues = StreamController.broadcast();
    delays = [];
    when(() => adapter.connect(_id)).thenAnswer((_) async {});
    when(() => adapter.disconnect(_id)).thenAnswer((_) async {});
    when(() => adapter.pair(_id)).thenAnswer((_) async {});
    when(() => adapter.discover(_id)).thenAnswer(
      (_) async => {
        _service: {_notify, _write},
        _battery: {_level},
      },
    );
    when(() => adapter.subscribe(_id, any(), any())).thenAnswer((_) async {});
    when(() => adapter.values(_id, _notify)).thenAnswer((_) => notifyValues.stream);
    when(() => adapter.values(_id, _level)).thenAnswer((_) => batteryValues.stream);
    when(() => adapter.read(_id, _battery, _level))
        .thenAnswer((_) async => Uint8List.fromList([80]));
    when(() => adapter.write(_id, any(), any(), any())).thenAnswer((_) async {});
    when(() => adapter.connection(_id)).thenAnswer((_) => connection.stream);
  });

  BleDeviceLink link([BleSettings settings = _settings]) =>
      BleDeviceLink(adapter, _id, settings, delay: (d) async => delays.add(d));

  test('connects, then passes on packets and battery', () async {
    final l = link();
    final packets = <Uint8List>[];
    final levels = <int>[];
    l.packets.listen(packets.add);
    l.battery.listen(levels.add);

    await l.connect();
    notifyValues.add(Uint8List.fromList([0x91]));
    batteryValues.add(Uint8List.fromList([79]));
    await _settle();

    expect(await l.state.first, LinkState.connected);
    expect(packets.single, [0x91]);
    expect(levels, [80, 79]);
    verify(() => adapter.subscribe(_id, _service, _notify)).called(1);
    verifyNever(() => adapter.pair(any()));
  });

  test('pairs before discovering when the profile asks for bonding', () async {
    await link(_settings.copyWith(bond: true)).connect();

    verifyInOrder([
      () => adapter.connect(_id),
      () => adapter.pair(_id),
      () => adapter.discover(_id),
    ]);
  });

  final missing = <String, Map<String, Set<String>>>{
    'data service': {
      _battery: {_level},
    },
    'data characteristic': {
      _service: {_write},
    },
    'command characteristic': {
      _service: {_notify},
    },
  };
  for (final MapEntry(key: name, value: services) in missing.entries) {
    test('fails without the $name and leaves the device disconnected', () async {
      when(() => adapter.discover(_id)).thenAnswer((_) async => services);
      final l = link();

      await expectLater(l.connect(), throwsA(isA<LinkException>()));
      expect(await l.state.first, LinkState.disconnected);
      verify(() => adapter.disconnect(_id)).called(1);
    });
  }

  test('wraps adapter errors in LinkException', () async {
    when(() => adapter.connect(_id)).thenThrow(Exception('radio busy'));

    await expectLater(link().connect(), throwsA(isA<LinkException>()));
  });

  final noBattery = <String, (BleSettings, Map<String, Set<String>>)>{
    'the profile turns it off': (
      _settings.copyWith(batteryService: false),
      {
        _service: {_notify, _write},
        _battery: {_level},
      },
    ),
    'the device has no Battery Service': (
      _settings,
      {
        _service: {_notify, _write},
      },
    ),
  };
  for (final MapEntry(key: name, value: (settings, services)) in noBattery.entries) {
    test('skips battery when $name', () async {
      when(() => adapter.discover(_id)).thenAnswer((_) async => services);

      await link(settings).connect();

      verifyNever(() => adapter.read(any(), any(), any()));
    });
  }

  test('keeps the read battery level when notifications are not allowed', () async {
    when(() => adapter.subscribe(_id, _battery, _level)).thenThrow(Exception('not notifiable'));
    final l = link();
    final levels = <int>[];
    l.battery.listen(levels.add);

    await l.connect();
    await _settle();

    expect(levels, [80]);
    expect(await l.state.first, LinkState.connected);
  });

  group('send', () {
    test('writes the bytes with response', () async {
      final l = link();
      await l.connect();

      await l.send([0x82, 0x00]);

      verify(() => adapter.write(_id, _service, _write, Uint8List.fromList([0x82, 0x00])))
          .called(1);
    });

    test('retries once after 100 ms', () async {
      var calls = 0;
      when(() => adapter.write(_id, any(), any(), any())).thenAnswer((_) async {
        if (calls++ == 0) throw Exception('busy');
      });
      final l = link();
      await l.connect();

      await l.send([0x82, 0x00]);

      expect(calls, 2);
      expect(delays, [BleDeviceLink.writeRetryDelay]);
    });

    test('throws after the retry fails', () async {
      when(() => adapter.write(_id, any(), any(), any())).thenThrow(Exception('busy'));
      final l = link();
      await l.connect();

      await expectLater(l.send([0x82]), throwsA(isA<LinkException>()));
    });

    test('throws when not connected', () async {
      await expectLater(link().send([0x82]), throwsA(isA<LinkException>()));
    });

    test('throws when the device takes no commands', () async {
      final l = link(const BleSettings(serviceUuid: _service, notifyUuid: _notify));
      await l.connect();

      await expectLater(l.send([0x82]), throwsA(isA<LinkException>()));
    });
  });

  group('auto-reconnect', () {
    test('after a drop, retries with 2, 5 and 15 s waits until it connects', () async {
      final l = link();
      final states = <LinkState>[];
      l.state.listen(states.add);
      await l.connect();
      var attempts = 0;
      when(() => adapter.connect(_id)).thenAnswer((_) async {
        if (++attempts < 3) throw Exception('out of range');
      });

      connection.add(false);
      await _settle();

      expect(delays, const [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 15)]);
      expect(states, [
        LinkState.disconnected,
        LinkState.connecting,
        LinkState.connected,
        LinkState.reconnecting,
        LinkState.connected,
      ]);
    });

    test('disconnect() stops the loop', () async {
      final wait = Completer<void>();
      final l = BleDeviceLink(adapter, _id, _settings, delay: (_) => wait.future);
      await l.connect();

      connection.add(false);
      await _settle();
      await l.disconnect();
      wait.complete();
      await _settle();

      verify(() => adapter.connect(_id)).called(1);
      expect(await l.state.first, LinkState.disconnected);
    });

    test('a drop after disconnect() does not reconnect', () async {
      final l = link();
      await l.connect();
      await l.disconnect();

      connection.add(false);
      await _settle();

      expect(delays, isEmpty);
    });
  });
}
