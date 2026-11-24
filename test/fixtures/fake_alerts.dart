import 'dart:async';

import 'package:generic_flutter_app/application/notification_prompt.dart';
import 'package:generic_flutter_app/domain/services/alert_engine.dart';
import 'package:generic_flutter_app/domain/services/alert_notifier.dart';
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
  Future<void> markAllRead(int userId, {Set<AlertKind>? kinds}) async {}

  @override
  Future<void> delete(int userId, int alertId) async {}

  @override
  Future<void> deleteAll(int userId, {Set<AlertKind>? kinds}) async {}

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

/// Shows nothing; the test taps a notification with [tap].
class FakeAlertNotifier implements AlertNotifier {
  final shown = <RaisedAlert>[];
  final _taps = StreamController<void>.broadcast(sync: true);

  void tap() => _taps.add(null);

  @override
  Future<void> show(RaisedAlert alert) async => shown.add(alert);

  @override
  Stream<void> get opened => _taps.stream;
}

/// Asks nothing; counts how often it was asked to, and to sync.
class FakeNotificationPrompt extends NotificationPrompt {
  int calls = 0;
  int syncs = 0;

  @override
  Future<void> maybeAsk() async => calls++;

  @override
  Future<void> sync() async => syncs++;
}
