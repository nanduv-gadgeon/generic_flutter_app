import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/transports/wifi/wifi_channel.dart';
import 'package:generic_flutter_app/data/transports/wifi/wifi_device_link.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/transport/device_link.dart';
import 'package:generic_flutter_app/domain/transport/wifi_device_finder.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/test_config.dart';

class MockWifiDeviceFinder extends Mock implements WifiDeviceFinder {}

/// A channel the test drives: [frames] come from [incoming]; closing it is a drop.
class FakeChannel implements WifiChannel {
  FakeChannel({this.canSend = true});

  final incoming = StreamController<Uint8List>();
  final sent = <List<int>>[];
  bool closed = false;

  @override
  final bool canSend;

  @override
  Stream<Uint8List> get frames => incoming.stream;

  @override
  Future<void> send(Uint8List bytes) async => sent.add(bytes);

  @override
  Future<void> close() async => closed = true;
}

// Made-up device id and addresses.
const _id = 'tst-0001';
const _found = WifiEndpoint('192.168.1.20', 8080);

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockWifiDeviceFinder finder;
  late List<WifiEndpoint> opened;
  late List<FakeChannel> channels;
  late List<Duration> delays;
  late bool deviceAnswers;
  final profile = DeviceProfile.fromJson(validWifiProfileJson());

  WifiDeviceLink link({String? lastAddress}) => WifiDeviceLink(
    finder,
    (endpoint, stream) async {
      opened.add(endpoint);
      if (!deviceAnswers) throw Exception('refused');
      return (channels..add(FakeChannel())).last;
    },
    profile,
    _id,
    lastAddress: lastAddress,
    delay: (d) async => delays.add(d),
  );

  setUp(() {
    finder = MockWifiDeviceFinder();
    opened = [];
    channels = [];
    delays = [];
    deviceAnswers = true;
    when(() => finder.resolve(profile, _id)).thenAnswer((_) async => _found);
  });

  test('connects to the address mDNS finds and passes on frames', () async {
    final l = link();
    final states = <LinkState>[];
    l.state.listen(states.add);
    final packets = <Uint8List>[];
    l.packets.listen((p) => packets.add(p.bytes));

    await l.connect();
    channels.single.incoming.add(Uint8List.fromList([1, 2, 3]));
    await _settle();

    expect(opened, [_found]);
    expect(states, [LinkState.disconnected, LinkState.connecting, LinkState.connected]);
    expect(packets, [
      [1, 2, 3],
    ]);
    expect(l.lastAddress, '192.168.1.20');
  });

  test('falls back to the last known IP on port 80 when mDNS finds nothing', () async {
    when(() => finder.resolve(profile, _id)).thenAnswer((_) async => null);

    await link(lastAddress: '192.168.1.21').connect();

    expect(opened, [const WifiEndpoint('192.168.1.21')]);
  });

  final refused = <String, (WifiEndpoint?, String?, String)>{
    'a device mDNS cannot find, with no last IP': (
      null,
      null,
      'device not found on the local network',
    ),
    'an address off the local network': (
      const WifiEndpoint('8.8.8.8'),
      null,
      'not a local network address',
    ),
  };
  for (final MapEntry(key: name, value: (found, last, message)) in refused.entries) {
    test('refuses $name', () async {
      when(() => finder.resolve(profile, _id)).thenAnswer((_) async => found);
      final l = link(lastAddress: last);

      await expectLater(
        l.connect(),
        throwsA(isA<LinkException>().having((e) => e.message, 'message', message)),
      );
      expect(opened, isEmpty);
      expect(await l.state.first, LinkState.disconnected);
    });
  }

  test('reports a device that does not answer as LinkException', () async {
    deviceAnswers = false;
    final l = link();

    await expectLater(l.connect(), throwsA(isA<LinkException>()));
    expect(await l.state.first, LinkState.disconnected);
  });

  test('send writes to the channel, and fails when not connected or not supported', () async {
    final l = link();
    await expectLater(l.send([1]), throwsA(isA<LinkException>()));

    await l.connect();
    await l.send([0xA5, 0x01]);
    expect(channels.single.sent, [
      [0xA5, 0x01],
    ]);

    final readOnly = WifiDeviceLink(
      finder,
      (_, _) async => FakeChannel(canSend: false),
      profile,
      _id,
    );
    await readOnly.connect();
    await expectLater(
      readOnly.send([1]),
      throwsA(isA<LinkException>().having((e) => e.message, 'message', 'device takes no commands')),
    );
  });

  test('reconnects after a drop with 2, 5 and 15 s waits until the device answers', () async {
    final l = link();
    final states = <LinkState>[];
    l.state.listen(states.add);
    await l.connect();

    deviceAnswers = false;
    var failures = 0;
    when(() => finder.resolve(profile, _id)).thenAnswer((_) async {
      if (++failures == 3) deviceAnswers = true;
      return _found;
    });
    await channels.single.incoming.close(); // The device drops.
    await _settle();

    expect(delays, const [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 15)]);
    expect(channels.first.closed, isTrue);
    expect(channels, hasLength(2));
    expect(states.last, LinkState.connected);
    expect(states, contains(LinkState.reconnecting));
  });

  test('disconnect closes the channel and stops reconnecting', () async {
    final l = link();
    await l.connect();

    await l.disconnect();
    await channels.single.incoming.close();
    await _settle();

    expect(channels.single.closed, isTrue);
    expect(delays, isEmpty);
    expect(await l.state.first, LinkState.disconnected);
  });

  test('refuses a profile without a wifi block', () {
    expect(
      () =>
          WifiDeviceLink(finder, (_, _) async => FakeChannel(), profile.copyWith(wifi: null), _id),
      throwsA(isA<NotConnectableException>()),
    );
  });
}
