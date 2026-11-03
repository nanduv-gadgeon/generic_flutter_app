import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/auth/argon2id_password_hasher.dart';
import 'package:generic_flutter_app/domain/services/password_hasher.dart';

// Low cost so tests stay fast; one test below uses the real settings.
const _cheap = Argon2idSettings(memoryKiB: 64, iterations: 1);
const _hasher = Argon2idPasswordHasher(settings: _cheap);

void main() {
  test('verifies the right password and rejects a wrong one', () async {
    final stored = await _hasher.hash('correct horse');

    expect(await _hasher.verify('correct horse', stored), isTrue);
    expect(await _hasher.verify('correct horsE', stored), isFalse);
    expect(await _hasher.verify('', stored), isFalse);
  });

  test('stores a 32-byte hash, a 16-byte salt and the settings used', () async {
    final stored = await _hasher.hash('pw');

    expect(stored.hash, hasLength(32));
    expect(stored.salt, hasLength(16));
    expect(stored.params, 'argon2id;v=19;m=64;t=1;p=1');
  });

  test('the same password gets a different salt and hash each time', () async {
    final a = await _hasher.hash('same');
    final b = await _hasher.hash('same');

    expect(a.salt, isNot(b.salt));
    expect(a.hash, isNot(b.hash));
  });

  test('verifies with the settings stored in the hash, not the current ones', () async {
    final old = await _hasher.hash('pw');
    const newer = Argon2idPasswordHasher(settings: Argon2idSettings(memoryKiB: 128, iterations: 2));

    expect(await newer.verify('pw', old), isTrue);
    expect(newer.needsRehash(old), isTrue);
    expect(_hasher.needsRehash(old), isFalse);
  });

  final badParams = ['bcrypt;cost=10', 'argon2id;v=19;m=64', 'argon2id;m=x;t=1;p=1', ''];
  for (final params in badParams) {
    test('rejects unknown settings "$params" instead of throwing', () async {
      final stored = await _hasher.hash('pw');
      final tampered = PasswordHash(hash: stored.hash, salt: stored.salt, params: params);

      expect(await _hasher.verify('pw', tampered), isFalse);
    });
  }

  test('recommended settings are the OWASP minimum', () {
    expect(Argon2idSettings.recommended.encode(), 'argon2id;v=19;m=19456;t=2;p=1');
  });

  test('works with the recommended settings', () async {
    const real = Argon2idPasswordHasher();
    final stored = await real.hash('pw');

    expect(await real.verify('pw', stored), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
