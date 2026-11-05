import 'dart:convert';
import 'dart:typed_data';

import 'package:generic_flutter_app/data/auth/biometric_user_store.dart';
import 'package:generic_flutter_app/data/profile/profile_photo_store.dart';
import 'package:generic_flutter_app/domain/services/auth_service.dart';
import 'package:generic_flutter_app/domain/services/biometric_auth.dart';
import 'package:generic_flutter_app/domain/services/password_hasher.dart';
import 'package:mocktail/mocktail.dart';

/// Instant, NOT secure: "hash" = reversed password bytes. For tests only.
class FakePasswordHasher implements PasswordHasher {
  FakePasswordHasher({this.params = 'fake;v1'});

  String params;
  final verified = <String>[];

  @override
  Future<PasswordHash> hash(String password) async => PasswordHash(
    hash: Uint8List.fromList(utf8.encode(password).reversed.toList()),
    salt: Uint8List.fromList([7]),
    params: params,
  );

  @override
  Future<bool> verify(String password, PasswordHash stored) async {
    verified.add(password);
    return utf8.decode(stored.hash.reversed.toList()) == password;
  }

  @override
  bool needsRehash(PasswordHash stored) => stored.params != params;
}

class MockBiometricAuth extends Mock implements BiometricAuth {}

/// [BiometricUserStore] backed by a plain variable instead of Keychain / Keystore.
class FakeBiometricUserStore implements BiometricUserStore {
  int? userId;

  @override
  Future<int?> read() async => userId;

  @override
  Future<void> write(int id) async => userId = id;

  @override
  Future<void> clear() async => userId = null;
}

class MockAuthService extends Mock implements AuthService {}

/// No real files: tests check which paths are saved and deleted.
class MockProfilePhotoStore extends Mock implements ProfilePhotoStore {}

const fakeUser = AuthUser(
  id: 1,
  name: 'Test User',
  email: 'test@example.com',
  mobile: '+91 0000000000',
  biometricEnabled: false,
);
