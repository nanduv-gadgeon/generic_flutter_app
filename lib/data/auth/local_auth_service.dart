import '../../domain/services/auth_service.dart';
import '../../domain/services/biometric_auth.dart';
import '../../domain/services/password_hasher.dart';
import '../db/app_database.dart';
import 'biometric_user_store.dart';

/// Phase 1 accounts, kept in the encrypted local database.
///
/// Wrong passwords do not lock the account (see docs/decisions.md).
class LocalAuthService implements AuthService {
  LocalAuthService({
    required this._db,
    required this._hasher,
    required this._biometrics,
    required this._biometricUser,
  });

  final AppDatabase _db;
  final PasswordHasher _hasher;
  final BiometricAuth _biometrics;
  final BiometricUserStore _biometricUser;

  /// Checked when the email is unknown, so a reply takes as long as for a real account.
  PasswordHash? _dummyHash;

  @override
  Future<AuthUser?> currentUser() async {
    final session = await _db.sessionDao.current();
    if (session == null) return null;
    final user = await _db.usersDao.findById(session.userId);
    return user == null ? null : _toAuthUser(user);
  }

  @override
  Future<LoginResult> login(String email, String password) async {
    final user = await _db.usersDao.findByEmail(email);
    if (user == null) {
      _dummyHash ??= await _hasher.hash('not-a-real-password');
      await _hasher.verify(password, _dummyHash!);
      return const InvalidCredentials();
    }

    final stored = _storedHash(user);
    if (!await _hasher.verify(password, stored)) return const InvalidCredentials();

    if (_hasher.needsRehash(stored)) {
      final fresh = await _hasher.hash(password);
      await _db.usersDao.updatePassword(
        user.id,
        hash: fresh.hash,
        salt: fresh.salt,
        params: fresh.params,
      );
    }
    await _db.sessionDao.start(user.id);
    final offer = !user.biometricEnabled && await _biometrics.isAvailable();
    return LoginSuccess(_toAuthUser(user), offerBiometrics: offer);
  }

  @override
  Future<LoginResult> loginWithBiometrics({required String reason}) async {
    final user = await _biometricLoginUser();
    if (user == null || !await _biometrics.authenticate(reason)) {
      return const BiometricFailed();
    }
    await _db.sessionDao.start(user.id);
    return LoginSuccess(_toAuthUser(user));
  }

  @override
  Future<bool> canLoginWithBiometrics() async =>
      await _biometricLoginUser() != null && await _biometrics.isAvailable();

  @override
  Future<void> setBiometricLogin({required bool enabled}) async {
    final session = await _db.sessionDao.current();
    if (session == null) throw StateError('No user is logged in');
    final previous = await _biometricUser.read();

    if (enabled) {
      if (previous != null && previous != session.userId) {
        await _db.usersDao.setBiometric(previous, enabled: false);
      }
      await _db.usersDao.setBiometric(session.userId, enabled: true);
      await _biometricUser.write(session.userId);
    } else {
      await _db.usersDao.setBiometric(session.userId, enabled: false);
      if (previous == session.userId) await _biometricUser.clear();
    }
  }

  @override
  Future<AuthUser> register(RegistrationData data) async {
    if (await _db.usersDao.findByEmail(data.email) != null) {
      throw const EmailAlreadyUsedException();
    }
    final hashed = await _hasher.hash(data.password);
    final id = await _db.usersDao.insertUser(
      UsersCompanion.insert(
        name: data.name.trim(),
        email: data.email,
        mobile: data.mobile.trim(),
        passwordHash: hashed.hash,
        passwordSalt: hashed.salt,
        hashParams: hashed.params,
        termsAcceptedAt: DateTime.now(),
      ),
    );
    return _toAuthUser((await _db.usersDao.findById(id))!);
  }

  @override
  Future<ResetResult> resetPassword({
    required String email,
    required String newPassword,
    required String reason,
  }) async {
    if (!await _biometrics.canVerifyOwner()) return const NoScreenLock();
    if (!await _biometrics.authenticate(reason)) return const OwnerNotVerified();
    // Looked up only after the owner is verified, so emails cannot be probed without unlocking.
    final user = await _db.usersDao.findByEmail(email);
    if (user == null) return const NoAccountForEmail();

    final hashed = await _hasher.hash(newPassword);
    await _db.usersDao.updatePassword(
      user.id,
      hash: hashed.hash,
      salt: hashed.salt,
      params: hashed.params,
    );
    return const ResetSuccess();
  }

  @override
  Future<void> logout() => _db.sessionDao.end();

  /// The user who turned on biometric login, if they still exist and still have it on.
  Future<User?> _biometricLoginUser() async {
    final id = await _biometricUser.read();
    if (id == null) return null;
    final user = await _db.usersDao.findById(id);
    return (user != null && user.biometricEnabled) ? user : null;
  }

  static PasswordHash _storedHash(User user) =>
      PasswordHash(hash: user.passwordHash, salt: user.passwordSalt, params: user.hashParams);

  static AuthUser _toAuthUser(User user) => AuthUser(
    id: user.id,
    name: user.name,
    email: user.email,
    biometricEnabled: user.biometricEnabled,
  );
}
