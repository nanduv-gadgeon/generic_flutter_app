import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/test_db.dart';

void main() {
  test('start creates the session and a second start replaces it', () async {
    final db = memoryDatabase();
    final first = await db.usersDao.insertUser(fakeUser());
    final second = await db.usersDao.insertUser(fakeUser(email: 'second@example.com'));

    await db.sessionDao.start(first);
    expect((await db.sessionDao.current())?.userId, first);

    await db.sessionDao.start(second);
    final rows = await db.select(db.sessions).get();
    expect(rows, hasLength(1));
    expect(rows.single.userId, second);
  });

  test('end clears the session', () async {
    final db = memoryDatabase();
    await db.sessionDao.start(await db.usersDao.insertUser(fakeUser()));

    await db.sessionDao.end();

    expect(await db.sessionDao.current(), isNull);
  });

  test('watchCurrent emits on log in and log out', () async {
    final db = memoryDatabase();
    final id = await db.usersDao.insertUser(fakeUser());

    final emitted = db.sessionDao.watchCurrent().map((s) => s?.userId);
    expectLater(emitted, emitsInOrder([null, id, null]));

    await pumpEventQueue();
    await db.sessionDao.start(id);
    await pumpEventQueue();
    await db.sessionDao.end();
  });

  test('a session for an unknown user is rejected', () async {
    final db = memoryDatabase();

    await expectLater(db.sessionDao.start(999), throwsA(isA<Exception>()));
  });
}
