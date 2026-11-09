import '../../domain/auth/lockout_policy.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/services/biometric_auth.dart';
import '../../domain/services/password_hasher.dart';
import '../db/app_database.dart';
import '../profile/profile_photo_store.dart';
import 'biometric_user_store.dart';

/// Phase 1 accounts, kept in the encrypted local database.
///
/// Repeated wrong passwords lock the account for a short time (see `lockout_policy.dart`).
class LocalAuthService implements AuthService {
  LocalAuthService({
    required this._db,
    required this._hasher,
    required this._biometrics,
    required this._biometricUser,
    required this._photos,
    this._clock = DateTime.now,
  });

  final AppDatabase _db;
  final PasswordHasher _hasher;
  final BiometricAuth _biometrics;
  final BiometricUserStore _biometricUser;
  final ProfilePhotoStore _photos;
  final DateTime Function() _clock;

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

    final now = _clock();
    // Checked before the password, so the right password does not get past the lock.
    if (isLocked(user.lockedUntil, now)) return AccountLocked(user.lockedUntil!.difference(now));

    final stored = _storedHash(user);
    if (!await _hasher.verify(password, stored)) {
      final next = afterFailedLogin((
        failedCount: user.failedLoginCount,
        lockedUntil: user.lockedUntil,
      ), now);
      await _db.usersDao.recordFailedLogin(
        user.id,
        count: next.failedCount,
        lockedUntil: next.lockedUntil,
      );
      return switch (next.lockedUntil) {
        final until? => AccountLocked(until.difference(now)),
        null => const InvalidCredentials(),
      };
    }
    if (user.failedLoginCount != 0 || user.lockedUntil != null) {
      await _db.usersDao.resetFailedLogins(user.id);
    }

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
    // Biometrics turned off by a changed enrolment (TC-LOG-012) are offered again here.
    final biometricOn = user.biometricEnabled && await _keepBiometricLogin(user.id);
    final offer = !biometricOn && await _biometrics.isAvailable();
    final current = (await _db.usersDao.findById(user.id))!;
    return LoginSuccess(_toAuthUser(current), offerBiometrics: offer);
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
  Future<bool> setBiometricLogin({required bool enabled}) async {
    final session = await _db.sessionDao.current();
    if (session == null) throw StateError('No user is logged in');
    final previous = await _biometricUser.read();

    if (enabled) {
      // Without a saved enrolment a new fingerprint could not be noticed, so stay off.
      if (!await _biometrics.rememberEnrollment()) return false;
      if (previous != null && previous != session.userId) {
        await _db.usersDao.setBiometric(previous, enabled: false);
      }
      await _db.usersDao.setBiometric(session.userId, enabled: true);
      await _biometricUser.write(session.userId);
      return true;
    }
    await _db.usersDao.setBiometric(session.userId, enabled: false);
    if (previous == session.userId) {
      await _biometricUser.clear();
      await _biometrics.forgetEnrollment();
    }
    return false;
  }

  /// False, after turning biometric login off for [userId], when the phone's faces / fingerprints
  /// changed since it was turned on: a newly added fingerprint must not log in (TC-LOG-012).
  Future<bool> _keepBiometricLogin(int userId) async {
    if (!await _biometrics.enrollmentChanged()) return true;
    await _db.usersDao.setBiometric(userId, enabled: false);
    if (await _biometricUser.read() == userId) await _biometricUser.clear();
    await _biometrics.forgetEnrollment();
    return false;
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
    // The phone's owner was verified, so a lock from wrong passwords is lifted too.
    await _db.usersDao.resetFailedLogins(user.id);
    return const ResetSuccess();
  }

  @override
  Future<AuthUser> updateProfile(ProfileChanges changes) async {
    final session = await _db.sessionDao.current();
    if (session == null) throw StateError('No user is logged in');
    final id = session.userId;
    final oldPhoto = (await _db.usersDao.findById(id))!.photoPath;
    final newPhoto = switch (changes.photo) {
      NewPhoto(:final pickedPath) => await _photos.save(pickedPath, userId: id),
      KeepPhoto() || RemovePhoto() => null,
    };
    await _db.usersDao.updateProfile(
      id,
      name: changes.name.trim(),
      mobile: changes.mobile.trim(),
      photoPath: newPhoto,
      clearPhoto: changes.photo is RemovePhoto,
    );
    // The old file goes only once the new path is saved.
    if (changes.photo is! KeepPhoto) await _photos.delete(oldPhoto);
    return _toAuthUser((await _db.usersDao.findById(id))!);
  }

  @override
  Future<void> logout() => _db.sessionDao.end();

  /// The user who turned on biometric login, if they still exist and still have it on.
  Future<User?> _biometricLoginUser() async {
    final id = await _biometricUser.read();
    if (id == null) return null;
    final user = await _db.usersDao.findById(id);
    if (user == null || !user.biometricEnabled) return null;
    return await _keepBiometricLogin(user.id) ? user : null;
  }

  static PasswordHash _storedHash(User user) =>
      PasswordHash(hash: user.passwordHash, salt: user.passwordSalt, params: user.hashParams);

  static AuthUser _toAuthUser(User user) => AuthUser(
    id: user.id,
    name: user.name,
    email: user.email,
    mobile: user.mobile,
    biometricEnabled: user.biometricEnabled,
    photoPath: user.photoPath,
  );
}
