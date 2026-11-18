import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/auth/local_biometric_auth.dart';
import 'package:generic_flutter_app/domain/services/biometric_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  late MockLocalAuthentication plugin;
  late LocalBiometricAuth auth;

  setUp(() {
    plugin = MockLocalAuthentication();
    auth = LocalBiometricAuth(plugin);
  });

  final availability = <String, (bool supported, List<BiometricType> enrolled, bool expected)>{
    'supported with a face enrolled': (true, [BiometricType.face], true),
    'supported but nothing enrolled': (true, [], false),
    'not supported': (false, [BiometricType.fingerprint], false),
  };
  for (final MapEntry(key: name, value: (supported, enrolled, expected)) in availability.entries) {
    test('isAvailable: $name', () async {
      when(() => plugin.isDeviceSupported()).thenAnswer((_) async => supported);
      when(() => plugin.getAvailableBiometrics()).thenAnswer((_) async => enrolled);

      expect(await auth.isAvailable(), expected);
    });
  }

  for (final supported in [true, false]) {
    test('canVerifyOwner: screen lock set up $supported', () async {
      when(() => plugin.isDeviceSupported()).thenAnswer((_) async => supported);

      expect(await auth.canVerifyOwner(), supported);
    });
  }

  test('canVerifyOwner returns false instead of throwing', () async {
    when(() => plugin.isDeviceSupported())
        .thenThrow(const LocalAuthException(code: LocalAuthExceptionCode.noCredentialsSet));

    expect(await auth.canVerifyOwner(), isFalse);
  });

  final kinds = <List<BiometricType>, BiometricKind>{
    [BiometricType.face, BiometricType.fingerprint]: BiometricKind.face,
    [BiometricType.fingerprint]: BiometricKind.fingerprint,
    [BiometricType.strong]: BiometricKind.other,
  };
  for (final MapEntry(key: types, value: kind) in kinds.entries) {
    test('kind: $types -> ${kind.name}', () async {
      when(() => plugin.getAvailableBiometrics()).thenAnswer((_) async => types);

      expect(await auth.kind(), kind);
    });
  }

  void pluginAuthenticates(Future<bool> Function() answer) => when(
    () => plugin.authenticate(
      localizedReason: any(named: 'localizedReason'),
      persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
    ),
  ).thenAnswer((_) => answer());

  // plugin result -> outcome
  final results = <bool, BiometricOutcome>{
    true: BiometricOutcome.success,
    false: BiometricOutcome.failed,
  };
  for (final MapEntry(key: ok, value: outcome) in results.entries) {
    test('authenticate: plugin says $ok -> ${outcome.name}', () async {
      pluginAuthenticates(() async => ok);

      expect(await auth.authenticate('reason'), outcome);
    });
  }

  // local_auth error -> what the user is told (never thrown)
  final errors = <LocalAuthExceptionCode, BiometricOutcome>{
    LocalAuthExceptionCode.userCanceled: BiometricOutcome.cancelled,
    LocalAuthExceptionCode.systemCanceled: BiometricOutcome.cancelled,
    LocalAuthExceptionCode.timeout: BiometricOutcome.cancelled,
    LocalAuthExceptionCode.userRequestedFallback: BiometricOutcome.cancelled,
    LocalAuthExceptionCode.noBiometricsEnrolled: BiometricOutcome.notEnrolled,
    LocalAuthExceptionCode.noCredentialsSet: BiometricOutcome.notEnrolled,
    LocalAuthExceptionCode.noBiometricHardware: BiometricOutcome.notAvailable,
    LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable: BiometricOutcome.notAvailable,
    LocalAuthExceptionCode.uiUnavailable: BiometricOutcome.notAvailable,
    LocalAuthExceptionCode.temporaryLockout: BiometricOutcome.lockedOut,
    LocalAuthExceptionCode.biometricLockout: BiometricOutcome.permanentlyLockedOut,
    LocalAuthExceptionCode.authInProgress: BiometricOutcome.failed,
    LocalAuthExceptionCode.deviceError: BiometricOutcome.failed,
    LocalAuthExceptionCode.unknownError: BiometricOutcome.failed,
  };
  test('every local_auth error is mapped', () {
    expect(errors.keys.toSet(), LocalAuthExceptionCode.values.toSet());
  });
  for (final MapEntry(key: code, value: outcome) in errors.entries) {
    test('authenticate: ${code.name} -> ${outcome.name}', () async {
      pluginAuthenticates(() async => throw LocalAuthException(code: code));

      expect(await auth.authenticate('reason'), outcome);
    });
  }

  test('authenticate: a PlatformException is a failure, not a crash', () async {
    pluginAuthenticates(() async => throw PlatformException(code: 'NotAvailable'));

    expect(await auth.authenticate('reason'), BiometricOutcome.failed);
  });

  // (supported, has hardware, enrolled) -> availability
  final availabilityCases = <String, (bool, bool, List<BiometricType>, BiometricOutcome)>{
    'face enrolled': (true, true, [BiometricType.face], BiometricOutcome.success),
    'hardware, nothing enrolled': (true, true, [], BiometricOutcome.notEnrolled),
    'no hardware': (true, false, [], BiometricOutcome.notAvailable),
    'not supported': (false, true, [BiometricType.face], BiometricOutcome.notAvailable),
  };
  for (final MapEntry(key: name, value: (supported, hardware, enrolled, outcome))
      in availabilityCases.entries) {
    test('availability: $name -> ${outcome.name}', () async {
      when(() => plugin.isDeviceSupported()).thenAnswer((_) async => supported);
      when(() => plugin.canCheckBiometrics).thenAnswer((_) async => hardware);
      when(() => plugin.getAvailableBiometrics()).thenAnswer((_) async => enrolled);

      expect(await auth.availability(), outcome);
    });
  }

  test('availability: a local_auth error is mapped, not thrown', () async {
    when(() => plugin.isDeviceSupported()).thenAnswer((_) async => true);
    when(() => plugin.canCheckBiometrics).thenAnswer((_) async => true);
    when(() => plugin.getAvailableBiometrics())
        .thenThrow(const LocalAuthException(code: LocalAuthExceptionCode.biometricLockout));

    expect(await auth.availability(), BiometricOutcome.permanentlyLockedOut);
  });

  group('enrolment channel (TC-LOG-012)', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('app/biometric_enrollment');
    final calls = <String>[];

    /// [reply] answers every call; a [PlatformException] is thrown back to Dart.
    void nativeAnswers(Object? reply) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          calls.add(call.method);
          if (reply is PlatformException) throw reply;
          return reply;
        },
      );
    }

    setUp(calls.clear);
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    // native reply -> (rememberEnrollment, enrollmentChanged)
    final replies = <String, (Object?, bool, bool)>{
      'true': (true, true, true),
      'false': (false, false, false),
      'nothing': (null, false, true),
      'an error': (PlatformException(code: 'failed'), false, true),
    };
    for (final MapEntry(key: name, value: (reply, remembered, changed)) in replies.entries) {
      test('native replies $name -> remembered $remembered, changed $changed', () async {
        nativeAnswers(reply);

        expect(await auth.rememberEnrollment(), remembered);
        expect(await auth.enrollmentChanged(), changed);
        expect(calls, ['remember', 'changed']);
      });
    }

    test('with no native side: not remembered, and treated as changed', () async {
      expect(await auth.rememberEnrollment(), isFalse);
      expect(await auth.enrollmentChanged(), isTrue);
      await auth.forgetEnrollment(); // does not throw
    });

    test('forgetEnrollment calls native and ignores errors', () async {
      nativeAnswers(PlatformException(code: 'failed'));

      await auth.forgetEnrollment();

      expect(calls, ['forget']);
    });
  });
}
