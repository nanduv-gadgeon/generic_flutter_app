import 'package:generic_flutter_app/domain/services/alert_engine.dart';
import 'package:generic_flutter_app/domain/services/alert_repository.dart';

/// No stored alerts, or [unread] unread ones; nothing is kept.
class FakeAlertRepository implements AlertRepository {
  FakeAlertRepository({this.unread = 0});

  final int unread;

  @override
  Future<int> add(RaisedAlert alert) async => 1;

  @override
  Stream<List<RaisedAlert>> watchAll(int userId) => Stream.value(const []);

  @override
  Stream<int> watchUnreadCount(int userId) => Stream.value(unread);

  @override
  Future<void> markAllRead(int userId) async {}

  @override
  Future<int> deleteOlderThan(DateTime before) async => 0;
}

/// Raises nothing; records who it was started for and how often it was stopped.
class FakeAlertEngine implements AlertEngine {
  final started = <int>[];
  int stops = 0;

  @override
  Future<void> start(int userId) async => started.add(userId);

  @override
  Future<void> stop() async => stops++;
}
