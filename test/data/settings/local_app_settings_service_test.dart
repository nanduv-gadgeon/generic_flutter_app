import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/settings/local_app_settings_service.dart';

import '../../fixtures/test_db.dart';

void main() {
  test('reads and writes the notifications switch in the local database', () async {
    final db = memoryDatabase();
    final id = await db.usersDao.insertUser(fakeUser());
    final settings = LocalAppSettingsService(db);

    expect(await settings.watchNotificationsEnabled(id).first, isTrue);
    await settings.setNotificationsEnabled(id, enabled: false);
    expect(await settings.watchNotificationsEnabled(id).first, isFalse);
  });
}
