import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/device_profile.dart';
import 'command_sequencer.dart';

/// Fetches the data a device stored, from the profile's `sync` block: after connecting it sends
/// the `onConnect` commands in order (e.g. set the clock, then request logs), then waits until the
/// device says it has sent everything, or until nothing arrives for `idleTimeoutMs`. What arrived
/// before a timeout is kept. With `everySeconds`, [startPolling] sends the `repeat` commands again
/// on that interval while connected, never while a fetch is still running.
class LogSync {
  LogSync(this._settings, this._commands);

  final SyncSettings _settings;
  final CommandSequencer _commands;
  Completer<void>? _done;
  Timer? _idle;
  Timer? _poll;
  int _frames = 0;

  /// Whether a fetch is running.
  bool get running => _done != null;

  /// The first fetch after connecting. Throws what [CommandSequencer.run] throws.
  Future<void> run() => _fetch(_settings.onConnect);

  /// Fetches again every `everySeconds` until [stopPolling]; does nothing without it.
  void startPolling() {
    stopPolling();
    final seconds = _settings.everySeconds;
    if (seconds == null || _settings.repeat.isEmpty) return;
    _poll = Timer.periodic(Duration(seconds: seconds), (_) {
      if (running) return; // The last fetch is still going.
      _fetch(_settings.repeat).ignore(); // A failed poll waits for the next one.
    });
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  /// A frame arrived from the device: it is still sending.
  void onFrame() {
    if (_done == null) return;
    _frames++;
    _waitIdle();
  }

  /// The device sent everything it had.
  void onBatchEnd() => _finish('done');

  /// The connection ended.
  void cancel() {
    stopPolling();
    _finish('cancelled');
  }

  Future<void> _fetch(List<String> commandIds) async {
    final done = _done = Completer<void>();
    _frames = 0;
    _waitIdle();
    try {
      for (final id in commandIds) {
        await _commands.run(id);
      }
    } catch (_) {
      _finish('failed');
      rethrow;
    }
    return done.future;
  }

  void _waitIdle() {
    _idle?.cancel();
    _idle = Timer(Duration(milliseconds: _settings.idleTimeoutMs), () => _finish('timed out'));
  }

  void _finish(String how) {
    _idle?.cancel();
    _idle = null;
    final done = _done;
    _done = null;
    if (done == null || done.isCompleted) return;
    if (kDebugMode) debugPrint('Log sync: $_frames frames, $how'); // Counts only.
    done.complete();
  }
}
