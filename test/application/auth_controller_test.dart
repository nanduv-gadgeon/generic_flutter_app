import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/services/auth_service.dart';
import 'package:generic_flutter_app/domain/services/biometric_auth.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/fake_auth.dart';

void main() {
  late MockAuthService service;
  late MockBiometricAuth biometrics;
  late ProviderContainer container;

  setUp(() {
    service = MockAuthService();
    biometrics = MockBiometricAuth();
    when(() => service.currentUser()).thenAnswer((_) async => null);
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(service),
        biometricAuthProvider.overrideWithValue(biometrics),
      ],
    );
    addTearDown(container.dispose);
  });

  AuthController controller() => container.read(authControllerProvider.notifier);

  test('restores a saved session on start', () async {
    when(() => service.currentUser()).thenAnswer((_) async => fakeUser);

    expect(await container.read(authControllerProvider.future), fakeUser);
  });

  test('a password login only switches user after completeLogin', () async {
    await container.read(authControllerProvider.future);
    when(() => service.login(any(), any()))
        .thenAnswer((_) async => const LoginSuccess(fakeUser, offerBiometrics: true));

    final result = await controller().login('test@example.com', 'pw');
    expect(result, isA<LoginSuccess>());
    expect(container.read(authControllerProvider).value, isNull);

    await controller().completeLogin(fakeUser);
    expect(container.read(authControllerProvider).value, fakeUser);
    verifyNever(() => service.setBiometricLogin(enabled: any(named: 'enabled')));
  });

  test('completeLogin can turn on biometrics', () async {
    await container.read(authControllerProvider.future);
    when(() => service.setBiometricLogin(enabled: true)).thenAnswer((_) async => true);

    await controller().completeLogin(fakeUser, enableBiometrics: true);

    verify(() => service.setBiometricLogin(enabled: true)).called(1);
    expect(container.read(authControllerProvider).value?.biometricEnabled, isTrue);
  });

  test('a biometric login switches user straight away', () async {
    await container.read(authControllerProvider.future);
    when(() => service.loginWithBiometrics(reason: 'test reason'))
        .thenAnswer((_) async => const LoginSuccess(fakeUser));

    await controller().loginWithBiometrics(reason: 'test reason');

    expect(container.read(authControllerProvider).value, fakeUser);
  });

  test('a failed biometric login keeps nobody logged in', () async {
    await container.read(authControllerProvider.future);
    when(() => service.loginWithBiometrics(reason: 'test reason'))
        .thenAnswer((_) async => const BiometricFailed());

    await controller().loginWithBiometrics(reason: 'test reason');

    expect(container.read(authControllerProvider).value, isNull);
  });

  group('register', () {
    const data = RegistrationData(
      name: 'Test User',
      email: 'test@example.com',
      mobile: '+10000000000',
      password: 'made-up-pw',
      termsAccepted: true,
    );

    test('creates the account, then logs it in', () async {
      await container.read(authControllerProvider.future);
      when(() => service.register(data)).thenAnswer((_) async => fakeUser);
      when(() => service.login(data.email, data.password))
          .thenAnswer((_) async => const LoginSuccess(fakeUser, offerBiometrics: true));

      await controller().register(data);

      expect(container.read(authControllerProvider).value, fakeUser);
      verifyNever(() => service.setBiometricLogin(enabled: any(named: 'enabled')));
    });

    test('an email already in use throws and keeps nobody logged in', () async {
      await container.read(authControllerProvider.future);
      when(() => service.register(data)).thenThrow(const EmailAlreadyUsedException());

      await expectLater(controller().register(data), throwsA(isA<EmailAlreadyUsedException>()));

      expect(container.read(authControllerProvider).value, isNull);
      verifyNever(() => service.login(any(), any()));
    });
  });

  test('resetPassword passes through and logs nobody in', () async {
    await container.read(authControllerProvider.future);
    when(
      () => service.resetPassword(
        email: 'test@example.com',
        newPassword: 'new-made-up',
        reason: 'test reason',
      ),
    ).thenAnswer((_) async => const ResetSuccess());

    final result = await controller().resetPassword(
      'test@example.com',
      'new-made-up',
      reason: 'test reason',
    );

    expect(result, isA<ResetSuccess>());
    expect(container.read(authControllerProvider).value, isNull);
  });

  test('logout clears the user', () async {
    when(() => service.currentUser()).thenAnswer((_) async => fakeUser);
    when(() => service.logout()).thenAnswer((_) async {});
    await container.read(authControllerProvider.future);

    await controller().logout();

    expect(container.read(authControllerProvider).value, isNull);
  });

  group('profile', () {
    setUpAll(() => registerFallbackValue(const ProfileChanges(name: '', mobile: '')));
    setUp(() => when(() => service.currentUser()).thenAnswer((_) async => fakeUser));

    test('updateProfile switches to the saved user', () async {
      await container.read(authControllerProvider.future);
      const changes = ProfileChanges(name: 'New Name', mobile: '+91 1');
      final saved = fakeUser.copyWith(name: 'New Name');
      when(() => service.updateProfile(changes)).thenAnswer((_) async => saved);

      await controller().updateProfile(changes);

      expect(container.read(authControllerProvider).value, saved);
    });

    test('updateProfile keeps the old user when saving fails', () async {
      await container.read(authControllerProvider.future);
      when(() => service.updateProfile(any())).thenThrow(StateError('save failed'));

      await expectLater(
        controller().updateProfile(const ProfileChanges(name: 'X', mobile: '')),
        throwsStateError,
      );
      expect(container.read(authControllerProvider).value, fakeUser);
    });

    test('setBiometricLogin saves it and updates the user', () async {
      await container.read(authControllerProvider.future);
      when(() => service.setBiometricLogin(enabled: true)).thenAnswer((_) async => true);

      await controller().setBiometricLogin(enabled: true);

      verify(() => service.setBiometricLogin(enabled: true)).called(1);
      expect(container.read(authControllerProvider).value?.biometricEnabled, isTrue);
    });
  });

  group('biometricLogin', () {
    test('is null when no user has turned it on', () async {
      when(() => service.canLoginWithBiometrics()).thenAnswer((_) async => false);

      expect(await container.read(biometricLoginProvider.future), isNull);
    });

    test('gives the kind when it can be used', () async {
      when(() => service.canLoginWithBiometrics()).thenAnswer((_) async => true);
      when(() => biometrics.kind()).thenAnswer((_) async => BiometricKind.face);

      expect(await container.read(biometricLoginProvider.future), BiometricKind.face);
    });
  });
}
