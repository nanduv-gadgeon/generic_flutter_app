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
const _id = 'AA:BB:CC:00:00:02';
const _service = '11111111-2222-3333-4444-000000000000';
const _notify = '11111111-2222-3333-4444-000000000001';

const _settings = BleSettings(serviceUuid: _service, notifyUuid: _notify, batteryService: false);

/// A refused connection, as Android reports GATT error 133.
final _refused = Exception('Unknown Error 133');

void main() {
  late MockBleAdapter adapter;
  late List<Duration> delays;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    adapter = MockBleAdapter();
    delays = [];
    when(() => adapter.connect(_id)).thenAnswer((_) async {});
    when(() => adapter.disconnect(_id)).thenAnswer((_) async {});
    when(() => adapter.pair(_id)).thenAnswer((_) async {});
    when(() => adapter.discover(_id)).thenAnswer(
      (_) async => {
        _service: {_notify},
      },
    );
    when(() => adapter.requestMtu(_id, any())).thenAnswer((_) async => 247);
    when(() => adapter.subscribe(_id, any(), any())).thenAnswer((_) async {});
    when(() => adapter.values(_id, any())).thenAnswer((_) => const Stream.empty());
    when(() => adapter.connection(_id)).thenAnswer((_) => const Stream.empty());
  });

  BleDeviceLink link([BleSettings settings = _settings]) =>
      BleDeviceLink(adapter, _id, settings, delay: (d) async => delays.add(d));

  /// [adapter.connect] fails [failures] times with [error], then connects.
  void failConnect(int failures, Object error) {
    var calls = 0;
    when(() => adapter.connect(_id)).thenAnswer((_) async {
      if (calls++ < failures) throw error;
    });
  }

  group('a refused connection', () {
    final cases = <({int failures, bool connects})>[
      (failures: 0, connects: true),
      (failures: 1, connects: true),
      (failures: 2, connects: true),
      (failures: 3, connects: false),
    ];
    for (final c in cases) {
      test('refused ${c.failures} times: ${c.connects ? 'connects' : 'fails'}', () async {
        failConnect(c.failures, _refused);
        final l = link();

        final result = l.connect();

        if (c.connects) {
          await result;
          expect(await l.state.first, LinkState.connected);
        } else {
          await expectLater(result, throwsA(isA<LinkException>()));
          expect(await l.state.first, LinkState.disconnected);
        }
        final retries = c.failures.clamp(0, BleDeviceLink.connectAttempts - 1);
        expect(delays, List.filled(retries, BleDeviceLink.connectRetryDelay));
        verify(() => adapter.connect(_id)).called(c.connects ? c.failures + 1 : c.failures);
      });
    }

    test('is closed before the next try', () async {
      failConnect(1, _refused);

      await link().connect();

      verifyInOrder([
        () => adapter.connect(_id),
        () => adapter.disconnect(_id),
        () => adapter.connect(_id),
      ]);
    });

    test('stops trying when disconnect() is called during the wait', () async {
      failConnect(1, _refused);
      final wait = Completer<void>();
      final l = BleDeviceLink(adapter, _id, _settings, delay: (_) => wait.future);

      final result = l.connect();
      await Future<void>.delayed(Duration.zero);
      await l.disconnect();
      wait.complete();

      await expectLater(result, throwsA(isA<LinkException>()));
      verify(() => adapter.connect(_id)).called(1);
    });
  });

  test('a timeout is not tried again', () async {
    failConnect(1, TimeoutException('no answer'));

    await expectLater(link().connect(), throwsA(isA<LinkException>()));

    verify(() => adapter.connect(_id)).called(1);
    expect(delays, isEmpty);
  });

  group('pairing (bond)', () {
    test('a refused first try still pairs once, before discovering', () async {
      failConnect(1, _refused);
      var pairs = 0;
      when(() => adapter.pair(_id)).thenAnswer((_) async => pairs++);

      await link(_settings.copyWith(bond: true)).connect();

      expect(pairs, 1);
      verifyInOrder([
        () => adapter.connect(_id),
        () => adapter.pair(_id),
        () => adapter.discover(_id),
        () => adapter.subscribe(_id, _service, _notify),
      ]);
    });

    test('a declined pairing fails the connect and disconnects', () async {
      when(() => adapter.pair(_id)).thenThrow(Exception('pairing declined'));
      final l = link(_settings.copyWith(bond: true));

      await expectLater(l.connect(), throwsA(isA<LinkException>()));

      expect(await l.state.first, LinkState.disconnected);
      verify(() => adapter.disconnect(_id)).called(1);
      verifyNever(() => adapter.discover(any()));
    });
  });
}
