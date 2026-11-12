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

  @override
  Future<void> start(int userId) async {}

  @override
  Future<void> stop() async {}

  void send(LiveUpdate update) {
    for (final controller in _controllers) {
      if (!controller.isClosed && controller.hasListener) controller.add(update);
    }
  }
}
