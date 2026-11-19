import '../alerts/alert.dart';

/// Shows a raised alert to the user as a phone notification.
abstract interface class AlertNotifier {
  Future<void> show(RaisedAlert alert);
}

/// Shows nothing.
// TODO(1.5.4): local notifications.
class NoAlertNotifier implements AlertNotifier {
  const NoAlertNotifier();

  @override
  Future<void> show(RaisedAlert alert) async {}
}
