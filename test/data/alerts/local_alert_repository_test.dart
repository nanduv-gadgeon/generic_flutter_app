import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/alerts/local_alert_repository.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/domain/services/alert_repository.dart';

import '../../fixtures/test_db.dart';

/// Raised alerts in a real (in-memory) database, with made-up values.
void main() {
  late AppDatabase db;
  late LocalAlertRepository repo;
  late int userId;
  late int otherUserId;
  late int band;
  late int othersBand;
  final t0 = DateTime.utc(2026, 10, 20, 9);

  setUp(() async {
    db = memoryDatabase();
    repo = LocalAlertRepository(db);
    userId = await db.usersDao.insertUser(fakeUser());
    otherUserId = await db.usersDao.insertUser(fakeUser(email: 'other@example.com'));
    band = await db.devicesDao.addDevice(fakeDevice(userId));
    othersBand = await db.devicesDao.addDevice(
      fakeDevice(otherUserId, address: 'AA:BB:CC:00:00:02'),
    );
  });

  RaisedAlert hr(int device, int minutes) => RaisedAlert(
    deviceId: device,
    kind: AlertKind.above,
    key: 'hr',
    value: 115,
    limit: 110,
    at: t0.add(Duration(minutes: minutes)),
  );

  test('stores every field and lists the user\'s alerts newest first', () async {
    final first = await repo.add(hr(band, 0));
    final offline = RaisedAlert(
      deviceId: band,
      kind: AlertKind.offline,
      at: t0.add(const Duration(minutes: 5)),
    );
    await repo.add(offline);
    await repo.add(hr(othersBand, 9));

    final alerts = await repo.watchAll(userId).first;

    expect(alerts, [offline.copyWith(id: first + 1), hr(band, 0).copyWith(id: first)]);
  });

  test('unread count, then mark all read for one user only', () async {
    await repo.add(hr(band, 0));
    await repo.add(hr(band, 1));
    await repo.add(hr(othersBand, 2));
    expect(await repo.watchUnreadCount(userId).first, 2);

    await repo.markAllRead(userId);

    expect(await repo.watchUnreadCount(userId).first, 0);
    expect(await repo.watchUnreadCount(otherUserId).first, 1);
    expect((await repo.watchAll(userId).first).every((a) => a.read), isTrue);
  });

  test('deletes alerts older than a time', () async {
    await repo.add(hr(band, 0));
    await repo.add(hr(band, 10));

    expect(await repo.deleteOlderThan(t0.add(const Duration(minutes: 5))), 1);
    expect((await repo.watchAll(userId).first).single.at, t0.add(const Duration(minutes: 10)));
  });

  test('a removed device takes its alerts with it', () async {
    await repo.add(hr(band, 0));

    await db.devicesDao.deleteDevice(band);

    expect(await repo.watchAll(userId).first, isEmpty);
  });
}
