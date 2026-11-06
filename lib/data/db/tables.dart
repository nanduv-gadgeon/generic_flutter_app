import 'package:drift/drift.dart';

/// How the phone talks to a device.
enum DeviceTransport { ble, wifi }

/// Phase 1 local accounts. Passwords are stored only as a salted hash (made in task 1.1.6).
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Stored lowercased by [UsersDao], so uniqueness ignores letter case.
  TextColumn get email => text().unique()();
  TextColumn get mobile => text()();
  BlobColumn get passwordHash => blob()();
  BlobColumn get passwordSalt => blob()();

  /// Algorithm and cost settings used for this hash, e.g. `argon2id;m=19456;t=2;p=1`.
  TextColumn get hashParams => text()();
  IntColumn get failedLoginCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lockedUntil => dateTime().nullable()();
  BoolColumn get biometricEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get termsAcceptedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Who is logged in. Always at most one row, with id 1.
class Sessions extends Table {
  // ignore: recursive_getters
  IntColumn get id => integer().check(id.equals(1))();
  IntColumn get userId => integer().references(Users, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get lastActiveAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Devices a user has added. Readings and heartbeats get their own tables in later tasks.
@TableIndex(name: 'devices_user_order', columns: {#userId, #sortOrder})
class Devices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  /// A device type id from the config file's `deviceTypes`.
  TextColumn get profileId => text()();
  TextColumn get transport => textEnum<DeviceTransport>()();

  /// BLE: MAC address or remote id. Wi‑Fi: the device id it announces by mDNS, which stays the
  /// same when its IP changes.
  TextColumn get address => text()();

  /// Wi‑Fi: the last IP address, used when mDNS does not find the device (added in schema v3).
  TextColumn get ipAddress => text().nullable()();
  TextColumn get firmware => text().nullable()();
  IntColumn get batteryPercent =>
      // ignore: recursive_getters
      integer().nullable().check(batteryPercent.isBetweenValues(0, 100))();
  DateTimeColumn get lastHeartbeatAt => dateTime().nullable()();
  IntColumn get sortOrder => integer()();

  /// Phase 2: unique key returned by the cloud when the device is registered.
  TextColumn get deviceKey => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, address},
  ];
}

/// Each user's app settings (added in schema v2). No row yet means every setting is at its default.
class AppSettings extends Table {
  IntColumn get userId => integer().references(Users, #id, onDelete: KeyAction.cascade)();
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}

/// Alert limits for one reading of one device (added in schema v3). Starts as the device type's
/// defaults from the config file; Device settings changes them.
class DeviceAlerts extends Table {
  IntColumn get deviceId => integer().references(Devices, #id, onDelete: KeyAction.cascade)();

  /// A reading key of the device's profile, e.g. `heart_rate`.
  TextColumn get readingKey => text()();
  RealColumn get above => real().nullable()();
  RealColumn get below => real().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {deviceId, readingKey};
}
