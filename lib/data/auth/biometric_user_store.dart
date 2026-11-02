import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers which local user turned on biometric login (one per phone).
class BiometricUserStore {
  BiometricUserStore(this._storage);

  final FlutterSecureStorage _storage;

  static const storageKey = 'biometric_user_id';
  static const _ios = IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device);

  Future<int?> read() async =>
      int.tryParse(await _storage.read(key: storageKey, iOptions: _ios) ?? '');

  Future<void> write(int userId) =>
      _storage.write(key: storageKey, value: '$userId', iOptions: _ios);

  Future<void> clear() => _storage.delete(key: storageKey, iOptions: _ios);
}
