import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/db/app_database.dart';
import '../../data/db/database_key_store.dart';
import '../../data/db/open_encrypted_database.dart';

part 'database.g.dart';

/// Opens the encrypted local database once, during the splash screen. Same in both phases.
@Riverpod(keepAlive: true)
Future<AppDatabase> appDatabase(Ref ref) async {
  // Application support, not Documents, so the file is not visible in the iOS Files app.
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'app.db'));
  final key = await DatabaseKeyStore(const FlutterSecureStorage())
      .getOrCreateKey(databaseExists: file.existsSync());

  final db = AppDatabase(openEncryptedDatabase(file, key));
  ref.onDispose(db.close);
  return db;
}
