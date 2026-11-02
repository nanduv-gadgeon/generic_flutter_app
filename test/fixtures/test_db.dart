import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';

/// A fresh in-memory database, closed after the test.
AppDatabase memoryDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// A fake account. Hash and salt are dummy bytes, not real password hashes.
UsersCompanion fakeUser({String email = 'test@example.com', String name = 'Test User'}) =>
    UsersCompanion.insert(
      name: name,
      email: email,
      mobile: '+10000000000',
      passwordHash: Uint8List.fromList([1, 2, 3]),
      passwordSalt: Uint8List.fromList([4, 5, 6]),
      hashParams: 'test;m=1;t=1;p=1',
      termsAcceptedAt: DateTime(2026, 1, 1),
    );

/// A fake BLE device for [userId]. `sortOrder` is set by `DevicesDao.addDevice`.
DevicesCompanion fakeDevice(int userId, {String address = 'AA:BB:CC:00:00:01'}) =>
    DevicesCompanion.insert(
      userId: userId,
      name: 'Test band',
      profileId: 'test_device_v1',
      transport: DeviceTransport.ble,
      address: address,
      sortOrder: 0,
    );
