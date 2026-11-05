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

  test('authenticate returns the plugin result', () async {
    when(
      () => plugin.authenticate(
        localizedReason: any(named: 'localizedReason'),
        persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
      ),
    ).thenAnswer((_) async => true);

    expect(await auth.authenticate('reason'), isTrue);
  });

  test('authenticate returns false instead of throwing', () async {
    when(
      () => plugin.authenticate(
        localizedReason: any(named: 'localizedReason'),
        persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
      ),
    ).thenThrow(const LocalAuthException(code: LocalAuthExceptionCode.userCanceled));

    expect(await auth.authenticate('reason'), isFalse);
  });
}
