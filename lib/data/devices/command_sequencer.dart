import 'dart:async';

import '../../domain/decoder/decoded_packet.dart';
import '../../domain/decoder/device_codec.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/transport/device_link.dart';

/// A command was not confirmed: no reply in time, or a reply whose first data byte is [code].
class CommandFailedException implements Exception {
  const CommandFailedException(this.commandId, {this.replyId, this.code});

  final String commandId;
  final int? replyId;
  final int? code;

  @override
  String toString() => 'CommandFailedException: $commandId';
}

/// Sends profile commands one at a time over [_link], each waiting for its reply (when the profile
/// gives one) before the next is sent, so replies that share an id cannot be mixed up.
class CommandSequencer {
  CommandSequencer(
    this._link,
    this._codec,
    List<DeviceCommand> commands,
    this._replies, {
    required this._timeout,
    required this._retries,
  }) : _commands = {for (final c in commands) c.id: c};

  final DeviceLink _link;
  final DeviceCodec _codec;
  final Map<String, DeviceCommand> _commands;

  /// Replies decoded from the device, as they arrive.
  final Stream<CommandReply> _replies;
  final Duration _timeout;
  final int _retries;
  Future<void> _last = Future.value();

  /// Sends [commandId] (with [value] for a command that takes one) after any command already
  /// waiting. Throws [CommandFailedException], [LinkException] or [UnsupportedCommandException].
  Future<void> run(String commandId, {int? value}) {
    final done = _last.then((_) => _send(commandId, value));
    _last = done.then((_) {}, onError: (Object _) {});
    return done;
  }

  Future<void> _send(String commandId, int? value) async {
    final command = _commands[commandId] ?? (throw UnsupportedCommandException(commandId));
    final bytes = _codec.encode(commandId, value: value);
    final expect = command.reply;
    if (expect == null) return _link.send(bytes);

    final id = hexByte(expect.id);
    for (var attempt = 0; attempt <= _retries; attempt++) {
      // Listen before sending so a quick reply is not missed.
      final reply = _replies.firstWhere((r) => r.id == id).timeout(_timeout);
      try {
        await _link.send(bytes);
      } catch (_) {
        reply.ignore();
        rethrow;
      }
      final CommandReply answer;
      try {
        answer = await reply;
      } on TimeoutException {
        continue;
      }
      final ok = expect.ok;
      final code = answer.data.firstOrNull;
      if (ok != null && code != hexByte(ok)) {
        throw CommandFailedException(commandId, replyId: id, code: code);
      }
      return;
    }
    throw CommandFailedException(commandId);
  }
}
