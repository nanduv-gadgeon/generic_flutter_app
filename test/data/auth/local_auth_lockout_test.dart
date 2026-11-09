import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/auth/local_auth_service.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/domain/auth/lockout_policy.dart';
import 'package:generic_flutter_app/domain/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/fake_auth.dart';
import '../../fixtures/test_db.dart';

const _email = 'test@example.com';
const _password = 'correct horse';

/// TC-LOG-008: repeated wrong passwords lock the account (lockout_policy.dart).
void main() {
  late AppDatabase db;
  late FakePasswordHasher hasher;
  late MockBiometricAuth biometrics;
  late LocalAuthService auth;
  // Whole seconds: the database stores dates to the second.
  var now = DateTime(2026, 1, 1, 12);

  setUp(() async {
    now = DateTime(2026, 1, 1, 12);
    db = memoryDatabase();
    hasher = FakePasswordHasher();
    biometrics = MockBiometricAuth();
    when(() => biometrics.isAvailable()).thenAnswer((_) async => false);
    when(() => biometrics.canVerifyOwner()).thenAnswer((_) async => true);
    when(() => biometrics.authenticate(any())).thenAnswer((_) async => true);
    auth = LocalAuthService(
      db: db,
      hasher: hasher,
      biometrics: biometrics,
      biometricUser: FakeBiometricUserStore(),
      photos: MockProfilePhotoStore(),
      clock: () => now,
    );
    await auth.register(
      const RegistrationData(
        name: 'Test User',
        email: _email,
        mobile: '+10000000000',
        password: _password,
        termsAccepted: true,
      ),
    );
  });

  Future<List<LoginResult>> failTimes(int n) async => [
    for (var i = 0; i < n; i++) await auth.login(_email, 'wrong'),
  ];

  test('4 wrong passwords are only "incorrect"; the 5th locks for 30 seconds', () async {
    final results = await failTimes(maxFailedLogins);

    expect(results.take(4), everyElement(isA<InvalidCredentials>()));
    expect((results.last as AccountLocked).retryAfter, lockoutDuration);
  });

  test('while locked the right password is refused and not even checked', () async {
    await failTimes(maxFailedLogins);
    hasher.verified.clear();
    now = now.add(const Duration(seconds: 10));

    final result = await auth.login(_email, _password);

    expect((result as AccountLocked).retryAfter, const Duration(seconds: 20));
    expect(hasher.verified, isEmpty);
    expect(await auth.currentUser(), isNull);
  });

  test('after 30 seconds the right password logs in and the count starts again', () async {
    await failTimes(maxFailedLogins);
    now = now.add(lockoutDuration);

    expect(await auth.login(_email, _password), isA<LoginSuccess>());
    final row = (await db.usersDao.findByEmail(_email))!;
    expect(row.failedLoginCount, 0);
    expect(row.lockedUntil, isNull);
  });

  test('wrong passwords after a lock ends need 5 more to lock again', () async {
    await failTimes(maxFailedLogins);
    now = now.add(lockoutDuration);

    final results = await failTimes(maxFailedLogins);

    expect(results.take(4), everyElement(isA<InvalidCredentials>()));
    expect(results.last, isA<AccountLocked>());
  });

  test('a successful login resets the count', () async {
    await failTimes(4);
    await auth.login(_email, _password);
    await auth.logout();

    final results = await failTimes(4);

    expect(results, everyElement(isA<InvalidCredentials>()));
  });

  test('a password reset lifts the lock', () async {
    await failTimes(maxFailedLogins);

    await auth.resetPassword(email: _email, newPassword: 'new-made-up', reason: 'test');

    expect(await auth.login(_email, 'new-made-up'), isA<LoginSuccess>());
  });

  test('an unknown email is never locked', () async {
    final results = [
      for (var i = 0; i < maxFailedLogins + 1; i++) await auth.login('nobody@example.com', 'x'),
    ];

    expect(results, everyElement(isA<InvalidCredentials>()));
  });
}
