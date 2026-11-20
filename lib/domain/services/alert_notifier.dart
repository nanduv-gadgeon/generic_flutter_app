import '../alerts/alert.dart';

export '../alerts/alert.dart';

/// Shows raised alerts to the user as phone notifications.
abstract interface class AlertNotifier {
  /// Shows [alert], when the user has Notifications on and the phone allows it.
  Future<void> show(RaisedAlert alert);

  /// The user tapped an alert notification, also one that opened the app.
  Stream<void> get opened;
}

/// Shows nothing: alerts are turned off in the config (`features.alerts`).
class NoAlertNotifier implements AlertNotifier {
  const NoAlertNotifier();

  @override
  Future<void> show(RaisedAlert alert) async {}

  @override
  Stream<void> get opened => const Stream.empty();
}
