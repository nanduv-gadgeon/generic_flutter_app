import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/auth/local_auth_service.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/domain/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/fake_auth.dart';
import '../../fixtures/test_db.dart';

const _registration = RegistrationData(
  name: ' Test User ',
  email: 'Test@Example.com',
  mobile: '+10000000000',
  password: 'correct horse',
  termsAccepted: true,
);

/// Prompt text; the screens pass the real one from AuthStrings.
const _reason = 'test reason';

void main() {
  late AppDatabase db;
  late FakePasswordHasher hasher;
  late MockBiometricAuth biometrics;
  late FakeBiometricUserStore biometricUser;
  late LocalAuthService auth;

  setUp(() {
    db = memoryDatabase();
    hasher = FakePasswordHasher();
    biometrics = MockBiometricAuth();
    biometricUser = FakeBiometricUserStore();
    when(() => biometrics.isAvailable()).thenAnswer((_) async => true);
    when(() => biometrics.authenticate(any())).thenAnswer((_) async => true);
    auth = LocalAuthService(
      db: db,
      hasher: hasher,
      biometrics: biometrics,
      biometricUser: biometricUser,
    );
  });

  group('register', () {
    test('creates the account with a hash, trimmed name and lowercased email', () async {
      final user = await auth.register(_registration);

      expect(user.name, 'Test User');
      expect(user.email, 'test@example.com');
      final row = (await db.usersDao.findById(user.id))!;
      expect(row.passwordHash, isNot(_registration.password.codeUnits));
      expect(row.hashParams, 'fake;v1');
    });

    test('does not log in', () async {
      await auth.register(_registration);

      expect(await auth.currentUser(), isNull);
    });

    test('rejects an email that is already used, in any case', () async {
      await auth.register(_registration);

      await expectLater(
        auth.register(_registration.copyWith(email: 'TEST@example.COM')),
        throwsA(isA<EmailAlreadyUsedException>()),
      );
    });
  });

  group('login', () {
    setUp(() => auth.register(_registration));

    final cases = <String, (String email, String password, bool succeeds)>{
      'right email and password': ('test@example.com', 'correct horse', true),
      'email in another case': (' TEST@example.com ', 'correct horse', true),
      'wrong password': ('test@example.com', 'wrong', false),
      'password in another case': ('test@example.com', 'Correct horse', false),
      'unknown email': ('nobody@example.com', 'correct horse', false),
    };
    for (final MapEntry(key: name, value: (email, password, succeeds)) in cases.entries) {
      test(name, () async {
        final result = await auth.login(email, password);

        expect(result, succeeds ? isA<LoginSuccess>() : isA<InvalidCredentials>());
        expect(await auth.currentUser(), succeeds ? isNotNull : isNull);
      });
    }

    test('an unknown email still checks a password, so it takes as long', () async {
      await auth.login('nobody@example.com', 'guess');

      expect(hasher.verified, ['guess']);
    });

    test('offers biometrics when available and not yet on', () async {
      final result = await auth.login('test@example.com', 'correct horse') as LoginSuccess;

      expect(result.offerBiometrics, isTrue);
    });

    test('does not offer biometrics when the phone cannot do it', () async {
      when(() => biometrics.isAvailable()).thenAnswer((_) async => false);

      final result = await auth.login('test@example.com', 'correct horse') as LoginSuccess;

      expect(result.offerBiometrics, isFalse);
    });

    test('re-hashes with the current settings after a successful login', () async {
      hasher.params = 'fake;v2';

      await auth.login('test@example.com', 'correct horse');

      final row = (await db.usersDao.findByEmail('test@example.com'))!;
      expect(row.hashParams, 'fake;v2');
      expect(await auth.login('test@example.com', 'correct horse'), isA<LoginSuccess>());
    });

    test('logout ends the session', () async {
      await auth.login('test@example.com', 'correct horse');

      await auth.logout();

      expect(await auth.currentUser(), isNull);
    });
  });

  group('resetPassword', () {
    setUp(() async {
      await auth.register(_registration);
      when(() => biometrics.canVerifyOwner()).thenAnswer((_) async => true);
    });

    // (screen lock, prompt passes, email) -> result
    final cases = <String, (bool, bool, String, Type)>{
      'verified, known email': (true, true, 'test@example.com', ResetSuccess),
      'email in another case': (true, true, ' TEST@example.com ', ResetSuccess),
      'no screen lock': (false, true, 'test@example.com', NoScreenLock),
      'prompt cancelled': (true, false, 'test@example.com', OwnerNotVerified),
      'unknown email': (true, true, 'nobody@example.com', NoAccountForEmail),
      // The email is only looked up after verification, so it cannot be probed.
      'unknown email, not verified': (true, false, 'nobody@example.com', OwnerNotVerified),
    };
    for (final MapEntry(key: name, value: (lock, passes, email, type)) in cases.entries) {
      test(name, () async {
        when(() => biometrics.canVerifyOwner()).thenAnswer((_) async => lock);
        when(() => biometrics.authenticate(any())).thenAnswer((_) async => passes);

        final result = await auth.resetPassword(
          email: email,
          newPassword: 'new-made-up',
          reason: _reason,
        );

        expect(result.runtimeType, type);
        final changed = type == ResetSuccess;
        expect((await auth.login('test@example.com', 'new-made-up')) is LoginSuccess, changed);
        await auth.logout();
        expect((await auth.login('test@example.com', 'correct horse')) is LoginSuccess, !changed);
      });
    }

    test('does not show the prompt when the phone has no screen lock', () async {
      when(() => biometrics.canVerifyOwner()).thenAnswer((_) async => false);

      await auth.resetPassword(
        email: 'test@example.com',
        newPassword: 'new-made-up',
        reason: _reason,
      );

      verifyNever(() => biometrics.authenticate(any()));
    });

    test('shows the given reason in the prompt and does not log in', () async {
      await auth.resetPassword(
        email: 'test@example.com',
        newPassword: 'new-made-up',
        reason: _reason,
      );

      verify(() => biometrics.authenticate(_reason)).called(1);
      expect(await auth.currentUser(), isNull);
    });

    test('keeps Face ID login on', () async {
      await auth.login('test@example.com', 'correct horse');
      await auth.setBiometricLogin(enabled: true);
      await auth.logout();

      await auth.resetPassword(
        email: 'test@example.com',
        newPassword: 'new-made-up',
        reason: _reason,
      );

      expect(await auth.canLoginWithBiometrics(), isTrue);
    });
  });

  group('biometric login', () {
    setUp(() => auth.register(_registration));

    Future<void> loginAndEnable() async {
      await auth.login('test@example.com', 'correct horse');
      await auth.setBiometricLogin(enabled: true);
      await auth.logout();
    }

    test('is not possible until a user turns it on', () async {
      expect(await auth.canLoginWithBiometrics(), isFalse);
      expect(await auth.loginWithBiometrics(reason: _reason), isA<BiometricFailed>());
      verifyNever(() => biometrics.authenticate(any()));
    });

    test('logs in the user who turned it on', () async {
      await loginAndEnable();

      expect(await auth.canLoginWithBiometrics(), isTrue);
      final result = await auth.loginWithBiometrics(reason: _reason);

      expect(result, isA<LoginSuccess>());
      expect((await auth.currentUser())?.email, 'test@example.com');
      expect((result as LoginSuccess).offerBiometrics, isFalse);
    });

    test('fails when the prompt is cancelled', () async {
      await loginAndEnable();
      when(() => biometrics.authenticate(any())).thenAnswer((_) async => false);

      expect(await auth.loginWithBiometrics(reason: _reason), isA<BiometricFailed>());
      expect(await auth.currentUser(), isNull);
    });

    test('is not offered again once it is on', () async {
      await loginAndEnable();

      final result = await auth.login('test@example.com', 'correct horse') as LoginSuccess;
      expect(result.offerBiometrics, isFalse);
    });

    test('turning it off removes it', () async {
      await loginAndEnable();
      await auth.login('test@example.com', 'correct horse');

      await auth.setBiometricLogin(enabled: false);

      expect(biometricUser.userId, isNull);
      expect(await auth.canLoginWithBiometrics(), isFalse);
    });

    test('a second user turning it on takes it over', () async {
      await loginAndEnable();
      await auth.register(_registration.copyWith(email: 'second@example.com'));
      await auth.login('second@example.com', 'correct horse');

      await auth.setBiometricLogin(enabled: true);
      await auth.logout();

      expect((await db.usersDao.findByEmail('test@example.com'))!.biometricEnabled, isFalse);
      await auth.loginWithBiometrics(reason: _reason);
      expect((await auth.currentUser())?.email, 'second@example.com');
    });

    test('changing the setting needs a logged-in user', () async {
      await expectLater(auth.setBiometricLogin(enabled: true), throwsStateError);
    });
  });
}
