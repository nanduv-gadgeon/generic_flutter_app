import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/alerts/alert_notification.dart';

/// The phone's notifications, as the alert notifier needs them. [FlutterNotificationsPlatform]
/// is the real one; tests use a mock.
abstract interface class NotificationsPlatform {
  /// Sets up the plugin and the Android [channels]; [onTap] runs when a notification is tapped
  /// while the app runs.
  Future<void> initialize({
    required Map<AlertChannel, AlertChannelText> channels,
    required void Function() onTap,
  });

  /// Whether tapping a notification launched the app.
  Future<bool> launchedByTap();

  Future<void> show(int id, AlertNotificationText text);
}

/// [NotificationsPlatform] with `flutter_local_notifications`: two Android channels, both high
/// importance so every alert pops up (decision 2026-11-20), the white bell icon, and on iOS shown
/// while the app is open too. Full text on the lock screen
/// (decision 2026-11-19). Permissions are asked by `PermissionService`, not here.
class FlutterNotificationsPlatform implements NotificationsPlatform {
  FlutterNotificationsPlatform([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Map<AlertChannel, AlertChannelText> _channels = const {};

  static const icon = 'ic_notification';
  static const payload = 'alerts';

  @override
  Future<void> initialize({
    required Map<AlertChannel, AlertChannelText> channels,
    required void Function() onTap,
  }) async {
    _channels = channels;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(icon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => onTap(),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final MapEntry(key: channel, value: text) in channels.entries) {
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          channel.name,
          text.name,
          description: text.description,
          importance: importance,
        ),
      );
    }
  }

  @override
  Future<bool> launchedByTap() async =>
      (await _plugin.getNotificationAppLaunchDetails())?.didNotificationLaunchApp ?? false;

  @override
  Future<void> show(int id, AlertNotificationText text) {
    final channel = _channels[text.channel];
    return _plugin.show(
      id: id,
      title: text.title,
      body: text.body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          text.channel.name,
          channel?.name ?? text.channel.name,
          channelDescription: channel?.description,
          icon: icon,
          importance: importance,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(presentBanner: true, presentList: true),
      ),
    );
  }

  /// Every alert pops up as a heads-up notification. Android keeps a channel's importance once
  /// it exists, so a phone with the old channels needs the app's data cleared.
  static const importance = Importance.high;
}
