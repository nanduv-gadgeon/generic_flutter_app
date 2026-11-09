import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/test_db.dart';

void main() {
  test('notifications are on for a user without a settings row', () async {
    final db = memoryDatabase();
    final id = await db.usersDao.insertUser(fakeUser());

    expect(await db.settingsDao.watchNotifications(id).first, isTrue);
  });

  test('setNotifications turns them off and on again', () async {
    final db = memoryDatabase();
    final id = await db.usersDao.insertUser(fakeUser());

    await db.settingsDao.setNotifications(id, enabled: false);
    expect(await db.settingsDao.watchNotifications(id).first, isFalse);

    await db.settingsDao.setNotifications(id, enabled: true);
    expect(await db.settingsDao.watchNotifications(id).first, isTrue);
    expect(await db.select(db.appSettings).get(), hasLength(1));
  });

  test('each user has their own setting', () async {
    final db = memoryDatabase();
    final first = await db.usersDao.insertUser(fakeUser());
    final second = await db.usersDao.insertUser(fakeUser(email: 'second@example.com'));

    await db.settingsDao.setNotifications(first, enabled: false);

    expect(await db.settingsDao.watchNotifications(first).first, isFalse);
    expect(await db.settingsDao.watchNotifications(second).first, isTrue);
  });

  test('watchNotifications emits each change', () async {
    final db = memoryDatabase();
    final id = await db.usersDao.insertUser(fakeUser());

    expectLater(db.settingsDao.watchNotifications(id), emitsInOrder([true, false]));

    await pumpEventQueue();
    await db.settingsDao.setNotifications(id, enabled: false);
  });

  test('the settings row is deleted with the user', () async {
    final db = memoryDatabase();
    final id = await db.usersDao.insertUser(fakeUser());
    await db.settingsDao.setNotifications(id, enabled: false);

    await db.usersDao.deleteUser(id);

    expect(await db.select(db.appSettings).get(), isEmpty);
  });
}
