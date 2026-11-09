import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/auth/local_auth_service.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/domain/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/fake_auth.dart';
import '../../fixtures/test_db.dart';

const _email = 'test@example.com';
const _password = 'correct horse';
const _reason = 'test reason';

/// TC-LOG-012: biometric login stops when the phone's faces / fingerprints change.
void main() {
  late AppDatabase db;
  late MockBiometricAuth biometrics;
  late FakeBiometricUserStore biometricUser;
  late LocalAuthService auth;

  setUp(() async {
    db = memoryDatabase();
    biometrics = MockBiometricAuth();
    biometricUser = FakeBiometricUserStore();
    when(() => biometrics.isAvailable()).thenAnswer((_) async => true);
    when(() => biometrics.authenticate(any())).thenAnswer((_) async => true);
    stubUnchangedEnrollment(biometrics);
    auth = LocalAuthService(
      db: db,
      hasher: FakePasswordHasher(),
      biometrics: biometrics,
      biometricUser: biometricUser,
      photos: MockProfilePhotoStore(),
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

  Future<bool> loginAndEnable() async {
    await auth.login(_email, _password);
    final on = await auth.setBiometricLogin(enabled: true);
    await auth.logout();
    return on;
  }

  Future<bool> biometricFlag() async => (await db.usersDao.findByEmail(_email))!.biometricEnabled;

  void enrollmentChanges() =>
      when(() => biometrics.enrollmentChanged()).thenAnswer((_) async => true);

  test('turning it on saves the current enrolment', () async {
    expect(await loginAndEnable(), isTrue);

    verify(() => biometrics.rememberEnrollment()).called(1);
    expect(await auth.canLoginWithBiometrics(), isTrue);
  });

  test('stays off when the phone cannot track enrolment changes', () async {
    when(() => biometrics.rememberEnrollment()).thenAnswer((_) async => false);

    expect(await loginAndEnable(), isFalse);

    expect(await biometricFlag(), isFalse);
    expect(biometricUser.userId, isNull);
    expect(await auth.canLoginWithBiometrics(), isFalse);
  });

  test('a new fingerprint hides the button and turns biometric login off', () async {
    await loginAndEnable();
    enrollmentChanges();

    expect(await auth.canLoginWithBiometrics(), isFalse);

    expect(await biometricFlag(), isFalse);
    expect(biometricUser.userId, isNull);
    verify(() => biometrics.forgetEnrollment()).called(1);
  });

  test('a new fingerprint cannot log in, and the prompt is not even shown', () async {
    await loginAndEnable();
    enrollmentChanges();

    expect(await auth.loginWithBiometrics(reason: _reason), isA<BiometricFailed>());

    verifyNever(() => biometrics.authenticate(any()));
    expect(await auth.currentUser(), isNull);
  });

  test('after a change the password login offers biometrics again', () async {
    await loginAndEnable();
    enrollmentChanges();

    final result = await auth.login(_email, _password) as LoginSuccess;

    expect(result.offerBiometrics, isTrue);
    expect(result.user.biometricEnabled, isFalse);
    expect(await biometricFlag(), isFalse);
  });

  test('turning it on again saves the new enrolment and works', () async {
    await loginAndEnable();
    enrollmentChanges();
    await auth.login(_email, _password); // turns it off
    stubUnchangedEnrollment(biometrics);

    expect(await auth.setBiometricLogin(enabled: true), isTrue);
    await auth.logout();

    expect(await auth.loginWithBiometrics(reason: _reason), isA<LoginSuccess>());
  });

  test('turning it off forgets the saved enrolment', () async {
    await loginAndEnable();
    await auth.login(_email, _password);

    expect(await auth.setBiometricLogin(enabled: false), isFalse);

    verify(() => biometrics.forgetEnrollment()).called(1);
  });
}
