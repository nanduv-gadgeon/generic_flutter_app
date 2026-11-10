import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/devices/command_sequencer.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/decoder/generic_codec.dart';
import 'package:generic_flutter_app/domain/transport/device_link.dart';

import '../../fixtures/ppg_motion_link.dart';
import '../../fixtures/ppg_motion_profile.dart';

void main() {
  late ScriptedLink link;
  late CommandSequencer commands;

  /// Builds the sequencer inside the current zone (fakeAsync needs that).
  void build() {
    final profile = ppgMotionProfile();
    final codec = codecFor(profile);
    final replies = link.packets
        .expand((p) => codec.feed(p.bytes, source: p.source))
        .where((d) => d is CommandReply)
        .cast<CommandReply>()
        .asBroadcastStream();
    commands = CommandSequencer(
      link,
      codec,
      profile.commands,
      replies,
      timeout: const Duration(milliseconds: 2500),
      retries: 1,
    );
  }

  setUp(() => link = ScriptedLink());

  test('sends commands in order, each after the reply to the one before', () async {
    build();
    await Future.wait([commands.run('stop'), commands.run('set_channels'), commands.run('start')]);
    expect(link.sent, [stopCommand, channelsCommand, startCommand]);
  });

  test('sends a value with a command that takes one', () async {
    build();
    await commands.run('led_ir', value: 7);
    expect(link.sent.single, [0xA5, 0xA5, 0x02, 0x0E, 0x07]);
  });

  test('a wrong reply fails with the device code', () async {
    build();
    link.answer = (c) => [0x5A, 0x5A, 0x02, 0x20, 0x04]; // low battery
    await expectLater(
      commands.run('start'),
      throwsA(
        isA<CommandFailedException>()
            .having((e) => e.replyId, 'replyId', 0x20)
            .having((e) => e.code, 'code', 0x04),
      ),
    );
  });

  test('a reply to another command is not taken for this one', () {
    fakeAsync((async) {
      build();
      link.answer = (_) => [0x5A, 0x5A, 0x02, 0x0A, 0x05];
      Object? error;
      commands.run('start').catchError((Object e) => error = e);
      async.elapse(const Duration(seconds: 6));
      expect(error, isA<CommandFailedException>().having((e) => e.code, 'code', isNull));
    });
  });

  test('tries once more after 2.5 s without a reply', () {
    fakeAsync((async) {
      build();
      var attempts = 0;
      link.answer = (c) => ++attempts == 2 ? sensorAnswer(c) : null;
      var done = false;
      commands.run('start').then((_) => done = true);
      async.elapse(const Duration(milliseconds: 2400));
      expect(link.sent, hasLength(1));
      async.elapse(const Duration(milliseconds: 200));
      expect(link.sent, hasLength(2));
      async.flushMicrotasks();
      expect(done, isTrue);
    });
  });

  test('gives up after the retry', () {
    fakeAsync((async) {
      build();
      link.answer = (_) => null;
      Object? error;
      commands.run('stop').catchError((Object e) => error = e);
      async.elapse(const Duration(seconds: 6));
      expect(link.sent, hasLength(2));
      expect(error, isA<CommandFailedException>());
    });
  });

  test('a failed command does not block the next one', () async {
    build();
    link.answer = (c) => c[3] == 0x20 ? [0x5A, 0x5A, 0x02, 0x20, 0x04] : sensorAnswer(c);
    await expectLater(commands.run('start'), throwsA(isA<CommandFailedException>()));
    await commands.run('set_channels');
    expect(link.sent.last, channelsCommand);
  });

  test('passes on a failed write', () async {
    link = _FailingLink();
    build();
    await expectLater(commands.run('stop'), throwsA(isA<LinkException>()));
  });
}

class _FailingLink extends ScriptedLink {
  @override
  Future<void> send(List<int> bytes) => Future.error(const LinkException('write failed: test'));
}
