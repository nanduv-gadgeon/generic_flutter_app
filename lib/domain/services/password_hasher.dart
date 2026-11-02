import 'dart:typed_data';

/// A stored password hash with the salt and settings used to make it.
final class PasswordHash {
  const PasswordHash({required this.hash, required this.salt, required this.params});

  final Uint8List hash;
  final Uint8List salt;

  /// Algorithm and cost, e.g. `argon2id;v=19;m=19456;t=2;p=1`.
  final String params;
}

/// Hashes and checks passwords. Implementations must never log or keep the password.
abstract interface class PasswordHasher {
  /// Hashes [password] with a new random salt and the current settings.
  Future<PasswordHash> hash(String password);

  /// Checks [password] against [stored], using the settings stored with it.
  Future<bool> verify(String password, PasswordHash stored);

  /// True when [stored] was made with older settings and should be re-hashed after login.
  bool needsRehash(PasswordHash stored);
}
