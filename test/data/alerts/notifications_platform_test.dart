import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/alerts/notifications_platform.dart';
import 'package:generic_flutter_app/domain/alerts/alert_notification.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockAndroid extends Mock implements AndroidFlutterLocalNotificationsPlugin {}

/// The real platform: both Android channels pop up as heads-up notifications.
void main() {
  const channels = {
    AlertChannel.readings: (name: 'Reading alerts', description: 'Readings'),
    AlertChannel.device: (name: 'Device alerts', description: 'Devices'),
  };

  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const AndroidNotificationChannel('id', 'name'));
    registerFallbackValue(const NotificationDetails());
  });

  late _MockPlugin plugin;
  late _MockAndroid android;
  late FlutterNotificationsPlatform platform;

  setUp(() async {
    plugin = _MockPlugin();
    android = _MockAndroid();
    when(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(named: 'onDidReceiveNotificationResponse'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>(),
    ).thenReturn(android);
    when(() => android.createNotificationChannel(any())).thenAnswer((_) async {});
    when(
      () => plugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
    platform = FlutterNotificationsPlatform(plugin);
    await platform.initialize(channels: channels, onTap: () {});
  });

  test('both channels are created with high importance', () {
    final created = verify(() => android.createNotificationChannel(captureAny())).captured
        .cast<AndroidNotificationChannel>();

    expect(
      [for (final c in created) (c.id, c.name, c.importance)],
      [
        ('readings', 'Reading alerts', Importance.high),
        ('device', 'Device alerts', Importance.high),
      ],
    );
  });

  final cases = {
    'a reading alert': (title: 'Heart rate above 110 bpm', channel: AlertChannel.readings),
    'a battery alert': (title: 'Battery low (12%)', channel: AlertChannel.device),
  };
  for (final MapEntry(key: name, value: c) in cases.entries) {
    test('$name pops up, in its own channel, with full text on the lock screen', () async {
      await platform.show(7, (title: c.title, body: 'Test band', channel: c.channel));

      final details =
          verify(
                () => plugin.show(
                  id: 7,
                  title: c.title,
                  body: 'Test band',
                  notificationDetails: captureAny(named: 'notificationDetails'),
                  payload: FlutterNotificationsPlatform.payload,
                ),
              ).captured.single
              as NotificationDetails;
      final a = details.android!;
      expect(a.channelId, c.channel.name);
      expect(a.importance, Importance.high);
      expect(a.priority, Priority.high);
      expect(a.visibility, NotificationVisibility.public);
    });
  }
}
