import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/alerts/local_notifications_notifier.dart';
import 'package:generic_flutter_app/data/alerts/notifications_platform.dart';
import 'package:generic_flutter_app/domain/alerts/alert_notification.dart';
import 'package:generic_flutter_app/domain/services/alert_notifier.dart';
import 'package:generic_flutter_app/domain/services/permission_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/fake_permissions.dart';

class _MockPlatform extends Mock implements NotificationsPlatform {}

/// Alerts as phone notifications: shown only when the user and the phone allow it.
void main() {
  final at = DateTime.utc(2026, 10, 20, 9);
  const text = (
    title: 'Heart rate above 110 bpm',
    body: 'Test band · now 115 bpm',
    channel: AlertChannel.readings,
  );
  const channels = {
    AlertChannel.readings: (name: 'Reading alerts', description: 'Readings'),
    AlertChannel.device: (name: 'Device alerts', description: 'Devices'),
  };
  final alert = RaisedAlert(
    id: 42,
    deviceId: 1,
    kind: AlertKind.above,
    key: 'hr',
    value: 115,
    limit: 110,
    at: at,
  );

  late _MockPlatform platform;
  late FakePermissionService permissions;
  late bool enabled;
  late bool deviceGone;
  late void Function() tap;

  setUpAll(() => registerFallbackValue(text));

  setUp(() {
    platform = _MockPlatform();
    permissions = FakePermissionService();
    enabled = true;
    deviceGone = false;
    when(
      () => platform.initialize(
        channels: any(named: 'channels'),
        onTap: any(named: 'onTap'),
      ),
    ).thenAnswer((i) async => tap = i.namedArguments[#onTap] as void Function());
    when(platform.launchedByTap).thenAnswer((_) async => false);
    when(() => platform.show(any(), any())).thenAnswer((_) async {});
  });

  LocalNotificationsNotifier notifier() => LocalNotificationsNotifier(
    platform,
    describe: (_) async => deviceGone ? null : (userId: 7, text: text),
    isEnabled: (userId) async => userId == 7 && enabled,
    permissions: permissions,
    channels: channels,
  );

  test('shows the alert with its stored id and words, after setting up both channels', () async {
    await notifier().show(alert);

    verify(
      () => platform.initialize(
        channels: channels,
        onTap: any(named: 'onTap'),
      ),
    ).called(1);
    verify(() => platform.show(42, text)).called(1);
  });

  // why nothing is shown
  final blocked = <String, void Function()>{
    'Notifications off in Profile': () => enabled = false,
    'permission denied': () =>
        permissions.states[AppPermission.notifications] = PermissionState.denied,
    'permission blocked': () =>
        permissions.states[AppPermission.notifications] = PermissionState.permanentlyDenied,
    'the device was removed': () => deviceGone = true,
  };
  for (final MapEntry(key: why, value: arrange) in blocked.entries) {
    test('nothing is shown: $why', () async {
      arrange();
      await notifier().show(alert);
      verifyNever(() => platform.show(any(), any()));
    });
  }

  test('an alert not stored yet (no id) is not shown', () async {
    await notifier().show(alert.copyWith(id: null));
    verifyNever(() => platform.show(any(), any()));
  });

  test('a failing plugin does not throw', () async {
    when(() => platform.show(any(), any())).thenThrow(StateError('plugin gone'));
    await expectLater(notifier().show(alert), completes);
  });

  test('a failed set-up does not throw either', () async {
    when(
      () => platform.initialize(
        channels: any(named: 'channels'),
        onTap: any(named: 'onTap'),
      ),
    ).thenThrow(StateError('no plugin'));
    await expectLater(notifier().show(alert), completes);
  });

  test('a tap while the app runs is passed on', () async {
    final n = notifier();
    final taps = <void>[];
    final sub = n.opened.listen(taps.add);
    await pumpEventQueue();

    tap();
    await pumpEventQueue();

    expect(taps, hasLength(1));
    await sub.cancel();
  });

  test('the tap that launched the app is passed on once', () async {
    when(platform.launchedByTap).thenAnswer((_) async => true);
    final n = notifier();

    final first = <void>[];
    final second = <void>[];
    final a = n.opened.listen(first.add);
    await pumpEventQueue();
    final b = n.opened.listen(second.add);
    await pumpEventQueue();

    expect((first.length, second.length), (1, 0));
    await a.cancel();
    await b.cancel();
  });

  test('NoAlertNotifier shows nothing and is never tapped', () async {
    const none = NoAlertNotifier();
    await none.show(alert);
    expect(await none.opened.isEmpty, isTrue);
  });
}
