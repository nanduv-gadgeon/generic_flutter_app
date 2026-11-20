import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/alerts/alert_notification.dart';
import '../../domain/services/alert_notifier.dart';
import '../../domain/services/permission_service.dart';
import 'notifications_platform.dart';

/// The words for [alert] and whose device raised it; null when the device is gone.
typedef DescribeAlert = Future<({int userId, AlertNotificationText text})?> Function(
  RaisedAlert alert,
);

/// [AlertNotifier] with the phone's local notifications (both phases). Shows an alert only when
/// its user has Notifications on and the phone allows it. Never logs the text: it holds health
/// values.
class LocalNotificationsNotifier implements AlertNotifier {
  LocalNotificationsNotifier(
    this._platform, {
    required this._describe,
    required this._isEnabled,
    required this._permissions,
    required this._channels,
  });

  final NotificationsPlatform _platform;
  final DescribeAlert _describe;
  final Future<bool> Function(int userId) _isEnabled;
  final PermissionService _permissions;
  final Map<AlertChannel, AlertChannelText> _channels;

  final _taps = StreamController<void>.broadcast();
  Future<void>? _ready;
  bool _launchTap = false;

  /// Sets up the plugin and channels, once; [show] and [opened] wait for it.
  Future<void> initialize() => _ready ??= _setUp();

  Future<void> _setUp() async {
    try {
      await _platform.initialize(channels: _channels, onTap: () => _taps.add(null));
      _launchTap = await _platform.launchedByTap();
    } catch (e) {
      if (kDebugMode) debugPrint('Notifications: set-up failed: ${e.runtimeType}');
    }
  }

  @override
  Stream<void> get opened async* {
    await initialize();
    if (_launchTap) {
      _launchTap = false; // The tap that opened the app is handled once.
      yield null;
    }
    yield* _taps.stream;
  }

  @override
  Future<void> show(RaisedAlert alert) async {
    try {
      await initialize();
      final id = alert.id;
      final described = await _describe(alert);
      if (id == null || described == null) return;
      if (!await _isEnabled(described.userId)) return;
      if (await _permissions.check(AppPermission.notifications) != PermissionState.granted) return;
      await _platform.show(id, described.text);
    } catch (e) {
      if (kDebugMode) debugPrint('Notifications: could not show one: ${e.runtimeType}');
    }
  }

  Future<void> dispose() => _taps.close();
}
