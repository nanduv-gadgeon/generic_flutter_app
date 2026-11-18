import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_adapter.dart';
import 'package:generic_flutter_app/data/transports/ble/ble_device_link.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/transport/ble_scanner.dart';
import 'package:generic_flutter_app/domain/transport/device_link.dart';
import 'package:generic_flutter_app/domain/transport/reconnect_backoff.dart';
import 'package:mocktail/mocktail.dart';

class MockBleAdapter extends Mock implements BleAdapter {}

// Made-up UUIDs and device id.
const _id = 'AA:BB:CC:00:00:01';
const _service = '11111111-2222-3333-4444-000000000000';
const _notify = '11111111-2222-3333-4444-000000000001';

const _settings = BleSettings(serviceUuid: _service, notifyUuid: _notify);

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// TC-1.2-044: the OS sends no disconnect when the phone's Bluetooth is turned off, so the link
/// watches Bluetooth itself, drops the dead link and reconnects once Bluetooth is back.
void main() {
  late MockBleAdapter adapter;
  late StreamController<BleAvailability> bluetooth;
  late StreamController<bool> connection;
  late StreamController<Uint8List> notifyValues;
  late List<Duration> delays;

  setUp(() {
    adapter = MockBleAdapter();
    bluetooth = StreamController.broadcast();
    connection = StreamController.broadcast();
    notifyValues = StreamController.broadcast();
    delays = [];
    when(() => adapter.availability).thenAnswer((_) => bluetooth.stream);
    when(() => adapter.connect(_id)).thenAnswer((_) async {});
    when(() => adapter.disconnect(_id)).thenAnswer((_) async {});
    when(() => adapter.discover(_id)).thenAnswer(
      (_) async => {
        _service: {_notify},
      },
    );
    when(() => adapter.subscribe(_id, any(), any())).thenAnswer((_) async {});
    when(() => adapter.values(_id, _notify)).thenAnswer((_) => notifyValues.stream);
    when(() => adapter.connection(_id)).thenAnswer((_) => connection.stream);
    when(() => adapter.requestMtu(_id, any())).thenAnswer((_) async => 247);
  });

  tearDown(() async {
    await bluetooth.close();
    await connection.close();
    await notifyValues.close();
  });

  BleDeviceLink link() => BleDeviceLink(adapter, _id, _settings, delay: (d) async => delays.add(d));

  Future<(BleDeviceLink, List<LinkState>, List<DevicePacket>)> connected() async {
    final l = link();
    final states = <LinkState>[];
    final packets = <DevicePacket>[];
    l.state.listen(states.add);
    l.packets.listen(packets.add);
    await l.connect();
    await _settle();
    return (l, states, packets);
  }

  test('Bluetooth off while connected: reconnecting, link dropped, no tries while off', () async {
    final (_, states, packets) = await connected();

    bluetooth.add(BleAvailability.off);
    await _settle();
    notifyValues.add(Uint8List.fromList([1, 2, 3]));
    await _settle();

    expect(states.last, LinkState.reconnecting);
    verify(() => adapter.disconnect(_id)).called(1);
    verify(() => adapter.connect(_id)).called(1); // only the first connect
    expect(packets, isEmpty);
    expect(delays, isEmpty);
  });

  test('Bluetooth back on: reconnects after the first wait and data flows again', () async {
    final (_, states, packets) = await connected();
    bluetooth.add(BleAvailability.off);
    await _settle();

    bluetooth.add(BleAvailability.on);
    await _settle();
    notifyValues.add(Uint8List.fromList([1, 2, 3]));
    await _settle();

    expect(delays, [const ReconnectBackoff().delayFor(0)]);
    verify(() => adapter.connect(_id)).called(2);
    expect(states.last, LinkState.connected);
    expect(packets.single.bytes, [1, 2, 3]);
  });

  test('Bluetooth off during the reconnect loop waits, then starts from the first wait', () async {
    // Each wait of the reconnect loop ends only when the test says so.
    final waits = <Completer<void>>[];
    final l = BleDeviceLink(
      adapter,
      _id,
      _settings,
      delay: (d) {
        delays.add(d);
        return (waits..add(Completer())).last.future;
      },
    );
    final states = <LinkState>[];
    l.state.listen(states.add);
    var reachable = true;
    when(() => adapter.connect(_id)).thenAnswer((_) async {
      if (!reachable) throw Exception('refused');
    });
    await l.connect();

    reachable = false;
    connection.add(false); // the link drops; the loop waits 2 s
    await _settle();
    waits[0].complete(); // try 2 fails; the loop waits 5 s
    await _settle();
    bluetooth.add(BleAvailability.off);
    await _settle();
    waits[1].complete(); // Bluetooth is off: no try, the loop waits for it
    await _settle();
    verify(() => adapter.connect(_id)).called(2);

    reachable = true;
    bluetooth.add(BleAvailability.on); // starts again from the 2 s wait
    await _settle();
    waits[2].complete();
    await _settle();

    const backoff = ReconnectBackoff();
    expect(delays, [backoff.delayFor(0), backoff.delayFor(1), backoff.delayFor(0)]);
    verify(() => adapter.connect(_id)).called(1);
    expect(states.last, LinkState.connected);
  });

  test('unauthorized counts as off; unknown keeps the last state', () async {
    final (_, states, _) = await connected();

    bluetooth.add(BleAvailability.unknown);
    await _settle();
    expect(states.last, LinkState.connected);

    bluetooth.add(BleAvailability.unauthorized);
    await _settle();
    expect(states.last, LinkState.reconnecting);
  });

  test('disconnect while Bluetooth is off stops for good', () async {
    final (l, states, _) = await connected();
    bluetooth.add(BleAvailability.off);
    await _settle();

    await l.disconnect();
    bluetooth.add(BleAvailability.on);
    await _settle();

    expect(states.last, LinkState.disconnected);
    verify(() => adapter.connect(_id)).called(1);
    expect(delays, isEmpty);
  });

  test('Bluetooth already on at connect changes nothing', () async {
    final (_, states, _) = await connected();
    bluetooth.add(BleAvailability.on);
    await _settle();

    expect(states.last, LinkState.connected);
    verifyNever(() => adapter.disconnect(_id));
  });
}
