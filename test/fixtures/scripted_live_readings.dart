import 'dart:async';

import 'package:generic_flutter_app/domain/services/live_readings.dart';

/// Live readings the test sends by hand to everyone watching; counts who listens.
class ScriptedLiveReadings implements LiveReadings {
  final _controllers = <StreamController<LiveUpdate>>[];
  int listens = 0;
  int cancels = 0;
  final retried = <int>[];

  @override
  Stream<LiveUpdate> watch(int deviceId) {
    final controller = StreamController<LiveUpdate>(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
    _controllers.add(controller);
    return controller.stream;
  }

  @override
  Stream<ActiveLink?> watchActive() => Stream.value(null);

  @override
  Future<void> retry(int deviceId) async => retried.add(deviceId);

  /// Commands sent by device actions, as (device, command id), step by step.
  final commands = <(int, String)>[];

  /// Makes [runAction] throw this.
  Object? commandError;

  @override
  Future<void> runAction(int deviceId, List<ActionStep> steps) async {
    for (final step in steps) {
      commands.add((deviceId, step.command));
    }
    if (commandError case final e?) throw e;
  }

  @override
  Future<void> start(int userId) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> close(int deviceId) async {}

  /// The ids Disconnect device was used on and not connected again.
  final off = <int>{};
  final _offChanges = StreamController<Set<int>>.broadcast();

  /// When set, [disconnect] throws it (after marking the device off, like the real one).
  Object? disconnectError;

  /// When set, [disconnect] waits for it before it finishes.
  Completer<void>? disconnectGate;

  @override
  Future<void> disconnect(int deviceId) async {
    off.add(deviceId);
    _offChanges.add({...off});
    await disconnectGate?.future;
    if (disconnectError case final e?) throw e;
  }

  @override
  Future<void> connect(int deviceId) async {
    off.remove(deviceId);
    _offChanges.add({...off});
  }

  @override
  Stream<Set<int>> watchDisconnected() async* {
    yield {...off};
    yield* _offChanges.stream;
  }

  void send(LiveUpdate update) {
    for (final controller in _controllers) {
      if (!controller.isClosed && controller.hasListener) controller.add(update);
    }
  }
}
