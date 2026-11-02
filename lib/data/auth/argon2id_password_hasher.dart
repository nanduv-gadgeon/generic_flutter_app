import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import '../../domain/services/password_hasher.dart';

/// Argon2id cost settings, stored with every hash as `argon2id;v=19;m=<KiB>;t=<n>;p=<n>`.
final class Argon2idSettings {
  const Argon2idSettings({required this.memoryKiB, required this.iterations, this.parallelism = 1});

  /// OWASP minimum, also the `cryptography` package's recommendation.
  static const recommended = Argon2idSettings(memoryKiB: 19456, iterations: 2);

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  String encode() => 'argon2id;v=19;m=$memoryKiB;t=$iterations;p=$parallelism';

  /// Reads settings written by [encode]; throws [FormatException] for anything else.
  static Argon2idSettings decode(String params) {
    final parts = params.split(';');
    if (parts.first != 'argon2id') throw FormatException('Not an Argon2id hash', params);
    final values = {
      for (final part in parts.skip(1))
        if (part.split('=') case [final key, final value]) key: int.parse(value),
    };
    final (m, t, p) = (values['m'], values['t'], values['p']);
    if (m == null || t == null || p == null) throw FormatException('Missing settings', params);
    return Argon2idSettings(memoryKiB: m, iterations: t, parallelism: p);
  }
}

/// Hashes passwords with Argon2id on a background isolate, so the UI keeps running.
///
/// Slow in debug builds; release builds are much faster.
class Argon2idPasswordHasher implements PasswordHasher {
  const Argon2idPasswordHasher({this.settings = Argon2idSettings.recommended});

  final Argon2idSettings settings;

  static const _saltBytes = 16;
  static const _hashBytes = 32;

  @override
  Future<PasswordHash> hash(String password) async {
    final random = Random.secure();
    final salt = Uint8List.fromList([for (var i = 0; i < _saltBytes; i++) random.nextInt(256)]);
    return PasswordHash(
      hash: await _derive(password, salt, settings),
      salt: salt,
      params: settings.encode(),
    );
  }

  @override
  Future<bool> verify(String password, PasswordHash stored) async {
    final Argon2idSettings storedSettings;
    try {
      storedSettings = Argon2idSettings.decode(stored.params);
    } on FormatException {
      return false;
    }
    final candidate = await _derive(password, stored.salt, storedSettings);
    return _constantTimeEquals(candidate, stored.hash);
  }

  @override
  bool needsRehash(PasswordHash stored) => stored.params != settings.encode();

  static Future<Uint8List> _derive(String password, Uint8List salt, Argon2idSettings s) {
    final passwordBytes = utf8.encode(password);
    return Isolate.run(() async {
      final algorithm = DartArgon2id(
        parallelism: s.parallelism,
        memory: s.memoryKiB,
        iterations: s.iterations,
        hashLength: _hashBytes,
      );
      final key = await algorithm.deriveKey(secretKey: SecretKey(passwordBytes), nonce: salt);
      return Uint8List.fromList(await key.extractBytes());
    });
  }

  /// Compares every byte, so the time taken does not reveal where the first difference is.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
