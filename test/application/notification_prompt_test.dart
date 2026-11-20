import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/application/notification_prompt.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/services/app_settings_service.dart';
import 'package:generic_flutter_app/domain/services/permission_service.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/fake_auth.dart';
import '../fixtures/test_config.dart';

class _MockSettings extends Mock implements AppSettingsService {}

/// The phone's state before asking, and its answer when asked.
class _Permissions implements PermissionService {
  _Permissions(this.state, this.answer);

  final PermissionState state;
  final PermissionState answer;
  int requests = 0;

  @override
  Future<PermissionState> check(AppPermission permission) async => state;

  @override
  Future<PermissionState> request(AppPermission permission) async {
    requests++;
    return answer;
  }

  @override
  Future<bool> openSettings() async => true;
}

/// Asking for the notification permission once after login (decision 2026-11-19).
void main() {
  late MockAuthService auth;
  late _MockSettings settings;

  setUp(() {
    auth = MockAuthService();
    settings = _MockSettings();
    when(() => settings.setNotificationsEnabled(any(), enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
  });

  Future<ProviderContainer> containerWith(
    _Permissions permissions, {
    bool setting = true,
    bool alerts = true,
    bool loggedIn = true,
  }) async {
    when(() => auth.currentUser()).thenAnswer((_) async => loggedIn ? fakeUser : null);
    when(() => settings.watchNotificationsEnabled(any())).thenAnswer((_) => Stream.value(setting));
    final json = validConfigJson();
    (json['features'] as Map<String, dynamic>)['alerts'] = alerts;
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        appSettingsServiceProvider.overrideWithValue(settings),
        permissionServiceProvider.overrideWithValue(permissions),
        appConfigProvider.overrideWith((ref) async => AppConfig.fromJson(json)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appConfigProvider.future);
    await container.read(authControllerProvider.future);
    return container;
  }

  final (granted, denied, blocked) = (
    PermissionState.granted,
    PermissionState.denied,
    PermissionState.permanentlyDenied,
  );

  // (setting on, phone state, answer if asked) -> (asked, setting turned off)
  final cases = <(bool, PermissionState, PermissionState), (bool, bool)>{
    (true, denied, granted): (true, false),
    (true, denied, denied): (true, true),
    (true, denied, blocked): (true, true),
    (true, blocked, blocked): (false, true), // blocked earlier: not asked, the setting tells
    (true, granted, granted): (false, false),
    (false, denied, granted): (false, false), // the user turned it off: respected
  };
  for (final MapEntry(key: (setting, state, answer), value: (asked, turnedOff)) in cases.entries) {
    test('setting $setting, phone ${state.name}, answer ${answer.name} -> '
        'asked $asked, turned off $turnedOff', () async {
      final permissions = _Permissions(state, answer);
      final container = await containerWith(permissions, setting: setting);

      await container.read(notificationPromptProvider.notifier).maybeAsk();

      expect(permissions.requests, asked ? 1 : 0);
      if (turnedOff) {
        verify(() => settings.setNotificationsEnabled(fakeUser.id, enabled: false)).called(1);
      } else {
        verifyNever(() => settings.setNotificationsEnabled(any(), enabled: any(named: 'enabled')));
      }
    });
  }

  test('asks only once while the app runs', () async {
    final permissions = _Permissions(denied, denied);
    final container = await containerWith(permissions);
    final prompt = container.read(notificationPromptProvider.notifier);

    await prompt.maybeAsk();
    await prompt.maybeAsk();

    expect(permissions.requests, 1);
  });

  test('nobody logged in, or alerts off in the config: nothing is asked', () async {
    for (final (loggedIn, alerts) in [(false, true), (true, false)]) {
      final permissions = _Permissions(denied, granted);
      final container = await containerWith(permissions, loggedIn: loggedIn, alerts: alerts);

      await container.read(notificationPromptProvider.notifier).maybeAsk();

      expect(permissions.requests, 0, reason: 'logged in $loggedIn, alerts $alerts');
    }
  });

  group("sync: off in the phone's Settings turns the setting off", () {
    // (setting on, phone state) -> setting saved, or null for no write
    final cases = <(bool, PermissionState), bool?>{
      (true, denied): false, // turned off in the phone's Settings
      (true, blocked): false,
      (true, granted): null,
      (false, granted): null, // off in Profile stays off
      (false, denied): null,
    };
    for (final MapEntry(key: (setting, state), value: saved) in cases.entries) {
      test('setting $setting, phone ${state.name} -> saved $saved; never asks', () async {
        final permissions = _Permissions(state, granted);
        final container = await containerWith(permissions, setting: setting);

        await container.read(notificationPromptProvider.notifier).sync();

        expect(permissions.requests, 0);
        if (saved == null) {
          verifyNever(
            () => settings.setNotificationsEnabled(any(), enabled: any(named: 'enabled')),
          );
        } else {
          verify(() => settings.setNotificationsEnabled(fakeUser.id, enabled: saved)).called(1);
        }
      });
    }

    test('nobody logged in: nothing is saved', () async {
      final container = await containerWith(_Permissions(denied, denied), loggedIn: false);

      await container.read(notificationPromptProvider.notifier).sync();

      verifyNever(() => settings.setNotificationsEnabled(any(), enabled: any(named: 'enabled')));
    });
  });
}
