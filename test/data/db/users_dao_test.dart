import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/test_db.dart';

void main() {
  test('inserts a user and finds them by email, ignoring case', () async {
    final db = memoryDatabase();
    final id = await db.usersDao.insertUser(fakeUser(email: ' Test@Example.COM '));

    final user = await db.usersDao.findByEmail('TEST@example.com');
    expect(user?.id, id);
    expect(user?.email, 'test@example.com');
    expect(user?.failedLoginCount, 0);
    expect(user?.biometricEnabled, isFalse);
  });

  test('rejects a second account with the same email in another case', () async {
    final db = memoryDatabase();
    await db.usersDao.insertUser(fakeUser());

    await expectLater(
      db.usersDao.insertUser(fakeUser(email: 'TEST@example.com')),
      throwsA(isA<Exception>()),
    );
  });

  test('records and resets failed logins', () async {
    final db = memoryDatabase();
    final id = await db.usersDao.insertUser(fakeUser());
    final until = DateTime(2026, 1, 1, 12);

    await db.usersDao.recordFailedLogin(id, count: 5, lockedUntil: until);
    var user = (await db.usersDao.findById(id))!;
    expect(user.failedLoginCount, 5);
    expect(user.lockedUntil, until);

    await db.usersDao.resetFailedLogins(id);
    user = (await db.usersDao.findById(id))!;
    expect(user.failedLoginCount, 0);
    expect(user.lockedUntil, isNull);
  });

  test('updates the password hash, salt and params', () async {
    final db = memoryDatabase();
    final id = await db.usersDao.insertUser(fakeUser());

    await db.usersDao.updatePassword(
      id,
      hash: Uint8List.fromList([9, 9]),
      salt: Uint8List.fromList([8, 8]),
      params: 'test;v2',
    );

    final user = (await db.usersDao.findById(id))!;
    expect(user.passwordHash, [9, 9]);
    expect(user.passwordSalt, [8, 8]);
    expect(user.hashParams, 'test;v2');
  });

  test('updates only the profile fields given, and biometrics', () async {
    final db = memoryDatabase();
    final id = await db.usersDao.insertUser(fakeUser());

    await db.usersDao.updateProfile(id, name: 'New Name', email: 'NEW@example.com');
    await db.usersDao.setBiometric(id, enabled: true);

    final user = (await db.usersDao.findById(id))!;
    expect(user.name, 'New Name');
    expect(user.email, 'new@example.com');
    expect(user.mobile, '+10000000000');
    expect(user.biometricEnabled, isTrue);
  });

  test('sets and clears the photo path', () async {
    final db = memoryDatabase();
    final id = await db.usersDao.insertUser(fakeUser());

    await db.usersDao.updateProfile(id, photoPath: '/fake/photo.jpg');
    expect((await db.usersDao.findById(id))!.photoPath, '/fake/photo.jpg');

    await db.usersDao.updateProfile(id, name: 'Test User');
    expect((await db.usersDao.findById(id))!.photoPath, '/fake/photo.jpg');

    await db.usersDao.updateProfile(id, clearPhoto: true);
    expect((await db.usersDao.findById(id))!.photoPath, isNull);
  });

  test('deleting a user also deletes their session and devices', () async {
    final db = memoryDatabase();
    final id = await db.usersDao.insertUser(fakeUser());
    await db.sessionDao.start(id);
    await db.devicesDao.addDevice(fakeDevice(id));

    await db.usersDao.deleteUser(id);

    expect(await db.usersDao.findById(id), isNull);
    expect(await db.sessionDao.current(), isNull);
    expect(await db.devicesDao.watchForUser(id).first, isEmpty);
  });
}
