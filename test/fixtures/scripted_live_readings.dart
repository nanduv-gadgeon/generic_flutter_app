import 'dart:async';

import 'package:generic_flutter_app/domain/services/live_readings.dart';

/// Live readings the test sends by hand; counts who listens.
class ScriptedLiveReadings implements LiveReadings {
  StreamController<LiveUpdate>? controller;
  int listens = 0;
  int cancels = 0;
  final retried = <int>[];

  @override
  Stream<LiveUpdate> watch(int deviceId) {
    controller = StreamController(onListen: () => listens++, onCancel: () => cancels++);
    return controller!.stream;
  }

  @override
  Stream<ActiveLink?> watchActive() => Stream.value(null);

  @override
  Future<void> retry(int deviceId) async => retried.add(deviceId);

  @override
  Future<void> start(int userId) async {}

  @override
  Future<void> stop() async {}

  void send(LiveUpdate update) => controller!.add(update);
}
