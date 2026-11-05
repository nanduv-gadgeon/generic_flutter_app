import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/transports/wifi/http_poll_channel.dart';
import 'package:generic_flutter_app/data/transports/wifi/ws_channel.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/transport/wifi_device_finder.dart';

// A real server on loopback stands in for the device; frames and commands are made-up bytes.
void main() {
  late HttpServer server;
  late WifiEndpoint endpoint;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    endpoint = WifiEndpoint('127.0.0.1', server.port);
  });

  tearDown(() => server.close(force: true));

  group('WsChannel', () {
    late Completer<WebSocket> device;

    setUp(() {
      device = Completer();
      server.listen((request) async {
        if (request.uri.path != '/ws') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        device.complete(await WebSocketTransformer.upgrade(request));
      });
    });

    test('passes on binary messages, skips text, and sends commands', () async {
      final channel = await WsChannel.open(endpoint, '/ws');
      final frames = <Uint8List>[];
      final done = Completer<void>();
      channel.frames.listen(frames.add, onDone: done.complete);
      final socket = await device.future;
      final commands = <dynamic>[];
      socket.listen(commands.add);

      socket
        ..add([0xA5, 0x00, 0x96, 0x50])
        ..add('hello');
      await channel.send(Uint8List.fromList([0xA5, 0x01]));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await socket.close(); // The device drops.
      await done.future;

      expect(frames, [
        [0xA5, 0x00, 0x96, 0x50],
      ]);
      expect(commands, [
        [0xA5, 0x01],
      ]);
      expect(channel.canSend, isTrue);
    });

    test('throws when the device has no WebSocket at the path', () async {
      await expectLater(WsChannel.open(endpoint, '/other'), throwsA(anything));
    });
  });

  group('HttpPollChannel', () {
    late List<List<int>> bodies;
    late List<String> requests;
    late List<Duration> delays;

    WifiStream stream({String? commandPath}) => WifiStream(
      type: WifiStreamType.http,
      path: '/data',
      pollSeconds: 5,
      commandPath: commandPath,
    );

    Future<HttpPollChannel> open({String? commandPath}) => HttpPollChannel.open(
      Dio(),
      endpoint,
      stream(commandPath: commandPath),
      delay: (d) async {
        delays.add(d);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      },
    );

    setUp(() {
      // Each GET answers with the next body; when they run out, the device answers 500.
      bodies = [];
      requests = [];
      delays = [];
      server.listen((request) async {
        final body = await request.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
        requests.add('${request.method} ${request.uri.path} ${body.join(',')}'.trim());
        if (request.method == 'GET') {
          if (bodies.isEmpty) {
            request.response.statusCode = HttpStatus.internalServerError;
          } else {
            request.response.add(bodies.removeAt(0));
          }
        }
        await request.response.close();
      });
    });

    test('polls every pollSeconds, skips empty bodies and ends when the device fails', () async {
      bodies.addAll([
        [1, 2],
        [],
        [3],
      ]);

      final channel = await open();
      final frames = await channel.frames.toList();

      expect(frames, [
        [1, 2],
        [3],
      ]);
      expect(requests, ['GET /data', 'GET /data', 'GET /data', 'GET /data']);
      expect(delays.toSet(), {const Duration(seconds: 5)});
    });

    test('throws on open when the device does not answer', () async {
      await expectLater(open(), throwsA(isA<DioException>()));
    });

    test('posts commands to commandPath', () async {
      bodies.add([1]);
      final channel = await open(commandPath: '/command');

      await channel.send(Uint8List.fromList([0xA5, 0x01]));
      await channel.close();

      expect(channel.canSend, isTrue);
      expect(requests, contains('POST /command 165,1'));
    });

    test('takes no commands without a commandPath', () async {
      bodies.add([1]);
      final channel = await open();
      await channel.close();

      expect(channel.canSend, isFalse);
    });
  });
}
