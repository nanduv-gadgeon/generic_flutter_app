import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// No key is stored, but the database file exists: the data can no longer be decrypted.
class DatabaseKeyLostException implements Exception {
  const DatabaseKeyLostException();

  @override
  String toString() => 'DatabaseKeyLostException: database key missing for an existing database';
}

/// Creates the database encryption key once and keeps it in Keychain / Keystore.
///
/// The key is never logged and never leaves this class except to open the database.
class DatabaseKeyStore {
  DatabaseKeyStore(this._storage);

  final FlutterSecureStorage _storage;

  static const storageKey = 'db_key_v1';
  static const _keyBytes = 32;

  // first_unlock_this_device: background jobs can open the DB after the first unlock, and the
  // key never syncs to another device.
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  static const _androidOptions = AndroidOptions();

  /// Returns the stored key as 64 hex characters, creating it on first use.
  Future<String> getOrCreateKey({required bool databaseExists}) async {
    final existing = await _storage.read(
      key: storageKey,
      iOptions: _iosOptions,
      aOptions: _androidOptions,
    );
    if (existing != null) return existing;
    if (databaseExists) throw const DatabaseKeyLostException();

    final random = Random.secure();
    final key = [
      for (var i = 0; i < _keyBytes; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await _storage.write(
      key: storageKey,
      value: key,
      iOptions: _iosOptions,
      aOptions: _androidOptions,
    );
    return key;
  }
}
