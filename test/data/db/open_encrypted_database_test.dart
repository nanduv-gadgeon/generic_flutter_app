import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/db/open_encrypted_database.dart';

const _key = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _wrongKey = 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('db_test');
    file = File('${dir.path}/app.db');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> writeOneUser() async {
    final db = AppDatabase(openEncryptedDatabase(file, _key));
    await db.usersDao.insertUser(
      UsersCompanion.insert(
        name: 'Test User',
        email: 'test@example.com',
        mobile: '+10000000000',
        passwordHash: Uint8List.fromList([1, 2, 3]),
        passwordSalt: Uint8List.fromList([4, 5, 6]),
        hashParams: 'test',
        termsAcceptedAt: DateTime(2026),
      ),
    );
    await db.close();
  }

  test('data written with the key reads back after reopening', () async {
    await writeOneUser();

    final db = AppDatabase(openEncryptedDatabase(file, _key));
    addTearDown(db.close);
    expect((await db.usersDao.findByEmail('test@example.com'))?.name, 'Test User');
  });

  test('the file on disk is encrypted', () async {
    await writeOneUser();

    final header = String.fromCharCodes(file.readAsBytesSync().take(15));
    expect(header, isNot('SQLite format 3'));
  });

  test('a wrong key cannot open the database', () async {
    await writeOneUser();

    final db = AppDatabase(openEncryptedDatabase(file, _wrongKey));
    addTearDown(db.close);
    await expectLater(db.usersDao.findByEmail('test@example.com'), throwsA(anything));
  });

  test('rejects a key that is not 64 hex characters', () {
    expect(() => openEncryptedDatabase(file, 'secret'), throwsArgumentError);
  });
}
