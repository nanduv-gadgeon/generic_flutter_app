import 'package:drift/drift.dart';

import '../app_database.dart';

part 'users_dao.g.dart';

@DriftAccessor(tables: [Users])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.attachedDatabase);

  /// Adds an account and returns its id. Throws if the email is already used.
  Future<int> insertUser(UsersCompanion user) =>
      into(users).insert(user.copyWith(email: Value(_normalise(user.email.value))));

  Future<User?> findByEmail(String email) =>
      (select(users)..where((u) => u.email.equals(_normalise(email)))).getSingleOrNull();

  Future<User?> findById(int id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<void> recordFailedLogin(int id, {required int count, DateTime? lockedUntil}) =>
      _update(id, UsersCompanion(failedLoginCount: Value(count), lockedUntil: Value(lockedUntil)));

  Future<void> resetFailedLogins(int id) =>
      _update(id, const UsersCompanion(failedLoginCount: Value(0), lockedUntil: Value(null)));

  Future<void> updatePassword(
    int id, {
    required Uint8List hash,
    required Uint8List salt,
    required String params,
  }) => _update(
    id,
    UsersCompanion(passwordHash: Value(hash), passwordSalt: Value(salt), hashParams: Value(params)),
  );

  Future<void> updateProfile(
    int id, {
    String? name,
    String? email,
    String? mobile,
    String? photoPath,

    /// Sets the photo back to none (initials); [photoPath] is then ignored.
    bool clearPhoto = false,
  }) => _update(
    id,
    UsersCompanion(
      name: Value.absentIfNull(name),
      email: Value.absentIfNull(email == null ? null : _normalise(email)),
      mobile: Value.absentIfNull(mobile),
      photoPath: clearPhoto ? const Value(null) : Value.absentIfNull(photoPath),
    ),
  );

  Future<void> setBiometric(int id, {required bool enabled}) =>
      _update(id, UsersCompanion(biometricEnabled: Value(enabled)));

  /// Deletes the account; its session and devices are removed with it.
  Future<void> deleteUser(int id) => (delete(users)..where((u) => u.id.equals(id))).go();

  Future<void> _update(int id, UsersCompanion changes) => (update(
    users,
  )..where((u) => u.id.equals(id))).write(changes.copyWith(updatedAt: Value(DateTime.now())));

  static String _normalise(String email) => email.trim().toLowerCase();
}
