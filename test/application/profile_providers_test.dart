import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/application/profile_providers.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/services/app_settings_service.dart';
import 'package:generic_flutter_app/domain/services/auth_service.dart';
import 'package:generic_flutter_app/domain/services/biometric_auth.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/fake_auth.dart';
import '../fixtures/test_config.dart';

class MockAppSettingsService extends Mock implements AppSettingsService {}

ProviderContainer _container({
  AuthUser? user = fakeUser,
  bool faceIdFeature = true,
  MockBiometricAuth? biometrics,
  MockAppSettingsService? settings,
}) {
  final auth = MockAuthService();
  when(() => auth.currentUser()).thenAnswer((_) async => user);
  final json = validConfigJson();
  (json['features'] as Map<String, dynamic>)['faceIdLogin'] = faceIdFeature;
  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(auth),
      appConfigProvider.overrideWith((ref) async => AppConfig.fromJson(json)),
      if (biometrics != null) biometricAuthProvider.overrideWithValue(biometrics),
      if (settings != null) appSettingsServiceProvider.overrideWithValue(settings),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Waits for the user and config the providers below read.
Future<void> _ready(ProviderContainer c) async {
  await c.read(authControllerProvider.future);
  await c.read(appConfigProvider.future);
}

void main() {
  group('notificationsEnabled', () {
    test("follows the logged-in user's setting", () async {
      final settings = MockAppSettingsService();
      when(() => settings.watchNotificationsEnabled(fakeUser.id))
          .thenAnswer((_) => Stream.value(false));
      final c = _container(settings: settings);
      await _ready(c);
      // Listened to first, so the auto-disposed provider stays alive until it has a value.
      c.listen(notificationsEnabledProvider, (_, _) {});

      expect(await c.read(notificationsEnabledProvider.future), isFalse);
    });

    test('is on when nobody is logged in', () async {
      final c = _container(user: null, settings: MockAppSettingsService());
      await _ready(c);
      c.listen(notificationsEnabledProvider, (_, _) {});

      expect(await c.read(notificationsEnabledProvider.future), isTrue);
    });
  });

  group('biometricSetting', () {
    // (feature on, phone has biometrics) -> kind shown, or null = row hidden
    final cases = <(bool, bool), BiometricKind?>{
      (true, true): BiometricKind.fingerprint,
      (true, false): null,
      (false, true): null,
    };
    for (final MapEntry(key: (feature, available), value: expected) in cases.entries) {
      test('feature $feature, phone has biometrics $available -> $expected', () async {
        final biometrics = MockBiometricAuth();
        when(() => biometrics.isAvailable()).thenAnswer((_) async => available);
        when(() => biometrics.kind()).thenAnswer((_) async => BiometricKind.fingerprint);
        final c = _container(faceIdFeature: feature, biometrics: biometrics);
        await _ready(c);
        c.listen(biometricSettingProvider, (_, _) {});

        expect(await c.read(biometricSettingProvider.future), expected);
      });
    }
  });
}
