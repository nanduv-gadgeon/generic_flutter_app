import 'package:generic_flutter_app/domain/services/live_readings.dart';

/// Live readings that connect nothing; records who logged in and out.
class FakeLiveReadings implements LiveReadings {
  final started = <int>[];
  int stops = 0;

  @override
  Stream<LiveUpdate> watch(int deviceId) => const Stream.empty();

  @override
  Stream<ActiveLink?> watchActive() => Stream.value(null);

  @override
  Future<void> retry(int deviceId) async {}

  @override
  Future<void> start(int userId) async => started.add(userId);

  @override
  Future<void> stop() async => stops++;
}
