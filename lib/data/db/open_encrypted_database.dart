import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

final _hexKey = RegExp(r'^[0-9a-f]{64}$');

/// Opens [file] with SQLCipher on a background isolate, using a raw 256-bit [hexKey].
///
/// Fails instead of opening unencrypted if the SQLite build has no SQLCipher, and fails on the
/// first query if the key is wrong.
QueryExecutor openEncryptedDatabase(File file, String hexKey) {
  if (!_hexKey.hasMatch(hexKey)) throw ArgumentError('Expected a 64-character hex key');

  return NativeDatabase.createInBackground(
    file,
    setup: (db) {
      // A raw key (x'...') skips SQLCipher's slow key derivation on every open.
      db.execute("PRAGMA key = \"x'$hexKey'\"");
      if (db.select('PRAGMA cipher_version').isEmpty) {
        throw StateError('SQLCipher is not available; refusing to open an unencrypted database');
      }
      db.select('SELECT count(*) FROM sqlite_master'); // throws if the key is wrong
    },
  );
}
